"""Wyoming event service + HTTP notification endpoint for the ReSpeaker LED ring.

Translates wyoming-satellite events into pixel_ring calls so the ring only
lights up after the wake word fires (not on every noise). The on-chip XMOS
firmware drives the DoA visualization during the listening window; we just
flash a solid colour as a wake-word confirmation cue, then hand control over.
Also exposes a small HTTP endpoint so Home Assistant can drive the ring as
a notification light.
"""

import argparse
import asyncio
import logging
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


_LOGGER = logging.getLogger("respeaker-led-bridge")

NUM_LEDS = 12

# Wake-word confirmation flash: alternating pure blue and cyan around the ring.
COLOR_DETECT_FLASH_A = (0, 0, 200)
COLOR_DETECT_FLASH_B = (0, 200, 200)

# Seconds to keep the confirmation flash visible before handing the ring
# back to the firmware. Long enough to be perceptible, short enough that
# DoA tracking still feels responsive.
DETECT_FLASH_DURATION = 0.4


def _paint_solid_sync(pixel_ring, rgb):
    data = []
    for _ in range(NUM_LEDS):
        data.extend([rgb[0], rgb[1], rgb[2], 0])
    pixel_ring.show(data)


def _paint_alternating_sync(pixel_ring, rgb_a, rgb_b):
    data = []
    for i in range(NUM_LEDS):
        r, g, b = rgb_a if i % 2 == 0 else rgb_b
        data.extend([r, g, b, 0])
    pixel_ring.show(data)


class State:
    def __init__(self, pixel_ring, lock):
        self.pixel_ring = pixel_ring
        self.lock = lock
        self.handover_task: asyncio.Task | None = None

    async def _under_lock(self, fn, *args):
        async with self.lock:
            await asyncio.to_thread(fn, *args)

    async def _cancel_handover(self):
        if self.handover_task is not None:
            self.handover_task.cancel()
            try:
                await self.handover_task
            except asyncio.CancelledError:
                pass
            self.handover_task = None

    def _firmware_listen_on_sync(self):
        # Hand the ring to the firmware: blue ring with green DoA segment.
        # We intentionally do NOT call set_vad_led(1): that command also
        # lights the on-board red status LED, and the trace pattern works
        # on its own as long as the ring was last given a manual show().
        self.pixel_ring.trace()

    def _firmware_listen_off_sync(self):
        self.pixel_ring.off()

    async def _handover_after_flash(self):
        try:
            await asyncio.sleep(DETECT_FLASH_DURATION)
            await self._under_lock(self._firmware_listen_on_sync)
        except asyncio.CancelledError:
            pass

    async def start_listening(self):
        # Cancel any pending handover from a previous detection.
        await self._cancel_handover()
        # Immediate visual confirmation that the wake word was recognised.
        await self._under_lock(
            _paint_alternating_sync,
            self.pixel_ring,
            COLOR_DETECT_FLASH_A,
            COLOR_DETECT_FLASH_B,
        )
        # Then let the firmware do its DoA thing.
        self.handover_task = asyncio.create_task(self._handover_after_flash())

    async def stop_listening(self):
        await self._cancel_handover()
        await self._under_lock(self._firmware_listen_off_sync)

    async def speak(self):
        await self._cancel_handover()
        await self._under_lock(self._firmware_listen_off_sync)
        await self._under_lock(self.pixel_ring.speak)

    async def error(self):
        await self._cancel_handover()
        await self._under_lock(self._firmware_listen_off_sync)
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
            pass
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
        await state._cancel_handover()
        async with state.lock:
            # Notifications take priority over firmware-listen mode.
            await asyncio.to_thread(pixel_ring.set_vad_led, 0)
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
    logging.basicConfig(
        level=logging.DEBUG if args.debug else logging.INFO,
        format="%(asctime)s %(name)s %(message)s",
    )

    pixel_ring = _pixel_ring
    # Start clean: firmware-VAD off, ring dark.
    pixel_ring.set_vad_led(0)
    pixel_ring.off()
    if args.brightness is not None:
        pixel_ring.set_brightness(args.brightness)

    state = State(pixel_ring, asyncio.Lock())

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
    parser.add_argument("--debug", action="store_true")
    args = parser.parse_args()
    asyncio.run(_run(args))


if __name__ == "__main__":
    main()
