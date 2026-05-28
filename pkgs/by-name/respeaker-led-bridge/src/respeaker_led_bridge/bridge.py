"""Wyoming event service + HTTP notification endpoint for the ReSpeaker LED ring.

Translates wyoming-satellite events into pixel_ring calls so the ring lights up
only when the wake word fires (not on every noise). Also exposes a small HTTP
endpoint so Home Assistant can drive the ring as a notification light.
"""

import argparse
import asyncio
import logging
import struct
from functools import partial

from aiohttp import web
from pixel_ring import pixel_ring as _pixel_ring
from wyoming.error import Error as WyError
from wyoming.event import Event
from wyoming.info import Describe, Info
from wyoming.satellite import (
    RunSatellite,
    SatelliteConnected,
    SatelliteDisconnected,
    StreamingStarted,
    StreamingStopped,
)
from wyoming.server import AsyncEventHandler, AsyncServer
from wyoming.snd import Played
from wyoming.tts import Synthesize
from wyoming.wake import Detection

from . import tuning


_LOGGER = logging.getLogger("respeaker-led-bridge")

NUM_LEDS = 12

# Colors used by the listening pattern.
COLOR_RING = (0, 0, 80)         # dim blue across the ring
COLOR_DOA = (0, 120, 0)         # bright green at the source direction
COLOR_DOA_NEIGHBOR = (0, 40, 20) # soft green on the adjacent LEDs
COLOR_DETECT_FLASH = (0, 0, 160) # bright blue confirmation cue


def _read_doa_sync(tuning_dev):
    """Best-effort read of DOAANGLE; returns degrees 0..359 or None."""
    if tuning_dev is None:
        return None
    try:
        data = tuning_dev.dev.ctrl_transfer(
            0x80 | 0x40,  # vendor IN
            0,
            0x80 | 0,
            21,  # DOAANGLE parameter id
            8,
            tuning.TIMEOUT,
        )
        (value,) = struct.unpack(b"i", bytes(data[:4]))
        return value % 360
    except Exception:
        return None


def _paint_doa_sync(pixel_ring, doa):
    """Paint the ring with COLOR_RING everywhere and COLOR_DOA at `doa`."""
    pixels = [COLOR_RING] * NUM_LEDS
    led = int(((doa + (360 / NUM_LEDS / 2)) % 360) // (360 / NUM_LEDS)) % NUM_LEDS
    pixels[(led - 1) % NUM_LEDS] = COLOR_DOA_NEIGHBOR
    pixels[(led + 1) % NUM_LEDS] = COLOR_DOA_NEIGHBOR
    pixels[led] = COLOR_DOA

    data = []
    for r, g, b in pixels:
        data.extend([r, g, b, 0])
    pixel_ring.show(data)


def _paint_solid_sync(pixel_ring, rgb):
    pixels = [rgb] * NUM_LEDS
    data = []
    for r, g, b in pixels:
        data.extend([r, g, b, 0])
    pixel_ring.show(data)


class State:
    """Shared mutable state across the wyoming handler, HTTP API, and painter."""

    def __init__(self, pixel_ring, tuning_dev, lock):
        self.pixel_ring = pixel_ring
        self.tuning_dev = tuning_dev
        self.lock = lock
        self.doa_task: asyncio.Task | None = None

    async def _under_lock(self, fn, *args):
        async with self.lock:
            await asyncio.to_thread(fn, *args)

    async def _doa_loop(self):
        try:
            while True:
                async with self.lock:
                    doa = await asyncio.to_thread(_read_doa_sync, self.tuning_dev)
                    if doa is not None:
                        await asyncio.to_thread(_paint_doa_sync, self.pixel_ring, doa)
                await asyncio.sleep(0.1)
        except asyncio.CancelledError:
            pass

    async def start_listening(self):
        # Solid blue confirmation cue, then start DoA polling overlay.
        await self._under_lock(_paint_solid_sync, self.pixel_ring, COLOR_DETECT_FLASH)
        await self.stop_doa_loop()
        self.doa_task = asyncio.create_task(self._doa_loop())

    async def stop_doa_loop(self):
        if self.doa_task is not None:
            self.doa_task.cancel()
            try:
                await self.doa_task
            except asyncio.CancelledError:
                pass
            self.doa_task = None

    async def stop_listening(self):
        await self.stop_doa_loop()
        await self._under_lock(self.pixel_ring.off)

    async def speak(self):
        await self.stop_doa_loop()
        await self._under_lock(self.pixel_ring.speak)

    async def error(self):
        await self.stop_doa_loop()
        await self._under_lock(self.pixel_ring.mono, 0xFF0000)


class LedHandler(AsyncEventHandler):
    def __init__(self, state: State, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.state = state

    async def handle_event(self, event: Event) -> bool:
        if Describe.is_type(event.type):
            await self.write_event(Info().event())
            return True

        if Detection.is_type(event.type):
            _LOGGER.info("wake detected")
            await self.state.start_listening()
        elif StreamingStarted.is_type(event.type):
            pass  # DoA loop already running
        elif Synthesize.is_type(event.type):
            await self.state.speak()
        elif StreamingStopped.is_type(event.type) or Played.is_type(event.type):
            await self.state.stop_listening()
        elif RunSatellite.is_type(event.type) or SatelliteConnected.is_type(event.type):
            await self.state.stop_listening()
        elif SatelliteDisconnected.is_type(event.type) or WyError.is_type(event.type):
            await self.state.error()

        return True


def _make_http_app(state: State):
    """HTTP API: POST /notify with one of
       {"action": "off"}
       {"action": "color", "r": 0..255, "g": 0..255, "b": 0..255}
       {"action": "pattern", "name": "think|speak|spin|listen"}
       {"action": "brightness", "value": 0..31}
    """
    pixel_ring = state.pixel_ring

    async def notify(request):
        body = await request.json()
        action = body.get("action")
        # Notifications interrupt any active wake-word painting.
        await state.stop_doa_loop()
        async with state.lock:
            if action == "off":
                await asyncio.to_thread(pixel_ring.off)
            elif action == "color":
                rgb = (body["r"] << 16) | (body["g"] << 8) | body["b"]
                await asyncio.to_thread(pixel_ring.mono, rgb)
            elif action == "pattern":
                fn = {
                    "think": pixel_ring.think,
                    "speak": pixel_ring.speak,
                    "spin": pixel_ring.spin,
                    "listen": pixel_ring.listen,
                }.get(body.get("name"))
                if fn is None:
                    return web.json_response({"error": "unknown pattern"}, status=400)
                await asyncio.to_thread(fn)
            elif action == "brightness":
                await asyncio.to_thread(pixel_ring.set_brightness, int(body["value"]))
            else:
                return web.json_response({"error": "unknown action"}, status=400)
        return web.json_response({"ok": True})

    app = web.Application()
    app.router.add_post("/notify", notify)
    return app


async def _run(args):
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(name)s %(message)s")

    pixel_ring = _pixel_ring
    tuning_dev = tuning.find()

    # Disable firmware-driven LED behavior; we paint manually via show().
    pixel_ring.set_vad_led(0)
    pixel_ring.off()
    if args.brightness is not None:
        pixel_ring.set_brightness(args.brightness)

    state = State(pixel_ring, tuning_dev, asyncio.Lock())

    if args.http_port:
        app = _make_http_app(state)
        runner = web.AppRunner(app)
        await runner.setup()
        site = web.TCPSite(runner, args.http_host, args.http_port)
        await site.start()
        _LOGGER.info("notification HTTP server on %s:%d", args.http_host, args.http_port)

    server = AsyncServer.from_uri(args.uri)
    _LOGGER.info("wyoming event server on %s", args.uri)
    await server.run(partial(LedHandler, state))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--uri", required=True, help="wyoming event server URI")
    parser.add_argument("--http-host", default="0.0.0.0")
    parser.add_argument("--http-port", type=int, default=0, help="0 disables HTTP API")
    parser.add_argument("--brightness", type=int, default=None, help="0..31")
    args = parser.parse_args()
    asyncio.run(_run(args))


if __name__ == "__main__":
    main()
