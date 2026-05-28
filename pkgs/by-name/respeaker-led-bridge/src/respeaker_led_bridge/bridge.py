"""Wyoming event service + HTTP notification endpoint for the ReSpeaker LED ring.

Translates wyoming-satellite events into pixel_ring calls so the ring lights up
only when the wake word fires (not on every noise). Also exposes a small HTTP
endpoint so Home Assistant can drive the ring as a notification light.
"""

import argparse
import asyncio
import json
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


def _read_doa(tuning_dev):
    """Best-effort read of DOAANGLE; returns degrees or None."""
    if tuning_dev is None:
        return None
    try:
        # DOAANGLE is parameter id 21, offset 0, int
        data = tuning_dev.dev.ctrl_transfer(
            0x80 | 0x40,  # vendor IN
            0,
            0x80 | 0,  # cmd: read offset 0
            21,
            8,
            tuning.TIMEOUT,
        )
        (value,) = struct.unpack(b"i", bytes(data[:4]))
        return value
    except Exception:
        return None


class LedHandler(AsyncEventHandler):
    def __init__(self, pixel_ring, tuning_dev, lock, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.pixel_ring = pixel_ring
        self.tuning_dev = tuning_dev
        self.lock = lock

    async def _do(self, fn):
        async with self.lock:
            await asyncio.to_thread(fn)

    def _listen_on(self):
        self.pixel_ring.set_vad_led(1)
        self.pixel_ring.trace()

    def _listen_off(self):
        self.pixel_ring.set_vad_led(0)
        self.pixel_ring.off()

    async def handle_event(self, event: Event) -> bool:
        if Describe.is_type(event.type):
            await self.write_event(Info().event())
            return True

        if Detection.is_type(event.type):
            _LOGGER.info("wake detected")
            # Hand the ring back to the on-chip firmware so it can render its
            # real-time DoA visualization (blue ring + green segment pointing
            # at the speaker). trace() picks the tracking pattern; the VAD-LED
            # toggle is what actually lets the firmware drive the ring.
            await self._do(self._listen_on)
        elif StreamingStarted.is_type(event.type):
            # Keep DoA visible while we stream to HA.
            pass
        elif Synthesize.is_type(event.type):
            await self._do(self._listen_off)
            await self._do(self.pixel_ring.speak)
        elif StreamingStopped.is_type(event.type) or Played.is_type(event.type):
            await self._do(self._listen_off)
        elif RunSatellite.is_type(event.type) or SatelliteConnected.is_type(event.type):
            await self._do(self._listen_off)
        elif SatelliteDisconnected.is_type(event.type) or WyError.is_type(event.type):
            await self._do(self._listen_off)
            await self._do(lambda: self.pixel_ring.mono(0xFF0000))

        return True


def _make_http_app(pixel_ring, lock):
    """HTTP API: POST /notify with one of
       {"action": "off"}
       {"action": "color", "r": 0..255, "g": 0..255, "b": 0..255}
       {"action": "pattern", "name": "think|speak|spin|listen"}
       {"action": "brightness", "value": 0..31}
    """

    async def notify(request):
        body = await request.json()
        action = body.get("action")
        async with lock:
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

    # Disable the firmware's auto-VAD LED behavior so the ring only lights up
    # under our control. set_vad_led(0) turns off the on-chip ring driver.
    pixel_ring.set_vad_led(0)
    pixel_ring.off()
    if args.brightness is not None:
        pixel_ring.set_brightness(args.brightness)

    lock = asyncio.Lock()

    if args.http_port:
        app = _make_http_app(pixel_ring, lock)
        runner = web.AppRunner(app)
        await runner.setup()
        site = web.TCPSite(runner, args.http_host, args.http_port)
        await site.start()
        _LOGGER.info("notification HTTP server on %s:%d", args.http_host, args.http_port)

    server = AsyncServer.from_uri(args.uri)
    _LOGGER.info("wyoming event server on %s", args.uri)
    await server.run(partial(LedHandler, pixel_ring, tuning_dev, lock))


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
