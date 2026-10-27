"""Record and log every Linux-Voice-Assistant activation.

Follows LVA's peripheral WebSocket API for the pipeline events and keeps a
rolling buffer of the microphone, so each activation is saved from a few
seconds before the wake word until the pipeline is idle again:

    <dir>/<YYYY-MM-DD>/<HHMMSS>_<wake word id>.wav
    <dir>/activations.jsonl    one JSON object per activation

Day folders older than the retention are deleted; audio is skipped (the log
line is still written) when the disk runs low.
"""

import argparse
import asyncio
import collections
import datetime as dt
import json
import logging
import shutil
import time
import wave
from pathlib import Path

import websockets

RATE = 16000
CHUNK = RATE // 10 * 2  # 100 ms of 16-bit mono
MIN_FREE_BYTES = 1 << 30

log = logging.getLogger("lva-activation-log")


class Recorder:
    """Microphone via pw-record, with a pre-roll buffer and an optional capture."""

    def __init__(self, target: str, pre_roll: float, max_audio: float):
        self.target = target
        self.pre = collections.deque(maxlen=int(pre_roll * 10))
        self.max_chunks = int(max_audio * 10)
        self.capture: list[bytes] | None = None

    async def run(self) -> None:
        while True:
            proc = await asyncio.create_subprocess_exec(
                "pw-record", "--target", self.target, "--rate", str(RATE),
                "--channels", "1", "--format", "s16", "--raw", "-",
                stdout=asyncio.subprocess.PIPE,
            )
            assert proc.stdout
            try:
                while True:
                    chunk = await proc.stdout.readexactly(CHUNK)
                    self.pre.append(chunk)
                    if self.capture is not None and len(self.capture) < self.max_chunks:
                        self.capture.append(chunk)
            except asyncio.IncompleteReadError:
                pass
            code = await proc.wait()
            log.warning("pw-record exited with %s, restarting in 5 s", code)
            self.pre.clear()
            await asyncio.sleep(5)

    def start(self) -> None:
        self.capture = list(self.pre)

    def stop(self) -> bytes:
        data = b"".join(self.capture or [])
        self.capture = None
        return data


class Activation:
    def __init__(self, data: dict):
        self.at = dt.datetime.now().astimezone()
        self.t0 = time.monotonic()
        self.wake_word_id = data.get("id") or "unknown"
        self.wake_word = data.get("wake_word")
        self.events: list[tuple[str, float]] = [("wake_word_detected", 0.0)]
        self.stt: str | None = None
        self.reply: str | None = None
        self.error: str | None = None

    def offset(self) -> float:
        return round(time.monotonic() - self.t0, 2)


class Log:
    def __init__(self, args: argparse.Namespace, recorder: Recorder):
        self.dir = Path(args.dir)
        self.post_roll = args.post_roll
        self.max_activation = args.max_activation
        self.retention = dt.timedelta(days=args.retention_days)
        self.recorder = recorder
        self.current: Activation | None = None

    def on_event(self, event: str, data: dict) -> None:
        loop = asyncio.get_running_loop()
        if event == "wake_word_detected":
            if self.current:
                self.finish(self.current)
            self.current = Activation(data)
            self.recorder.start()
            act = self.current
            loop.call_later(self.max_activation, self.finish, act)
            return
        act = self.current
        if act is None or event == "snapshot":
            return
        act.events.append((event, act.offset()))
        if event == "stt_text":
            act.stt = data.get("text")
        elif event == "tts_text":
            act.reply = data.get("text")
        elif event == "pipeline_error":
            act.error = data.get("reason")
        elif event in ("idle", "disconnected"):
            if event == "disconnected":
                act.error = act.error or "disconnected"
            loop.call_later(self.post_roll, self.finish, act)

    def finish(self, act: Activation) -> None:
        if act is not self.current:
            return  # already written
        self.current = None
        pcm = self.recorder.stop()
        day = self.dir / act.at.strftime("%Y-%m-%d")
        audio = None
        if pcm and shutil.disk_usage(self.dir).free > MIN_FREE_BYTES:
            day.mkdir(parents=True, exist_ok=True)
            path = day / f"{act.at.strftime('%H%M%S')}_{act.wake_word_id}.wav"
            with wave.open(str(path), "wb") as w:
                w.setnchannels(1)
                w.setsampwidth(2)
                w.setframerate(RATE)
                w.writeframes(pcm)
            audio = str(path.relative_to(self.dir))
        entry = {
            "time": act.at.isoformat(timespec="seconds"),
            "wake_word_id": act.wake_word_id,
            "wake_word": act.wake_word,
            "stt": act.stt,
            "reply": act.reply,
            "error": act.error,
            "duration_s": act.offset(),
            "events": act.events,
            "audio": audio,
        }
        with open(self.dir / "activations.jsonl", "a", encoding="utf-8") as f:
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")
        log.info("%s %s: %r", entry["time"], act.wake_word_id, act.stt)
        self.prune()

    def prune(self) -> None:
        cutoff = (dt.date.today() - self.retention).isoformat()
        for day in self.dir.iterdir():
            if day.is_dir() and day.name < cutoff:
                shutil.rmtree(day)


async def follow(url: str, on_event) -> None:
    while True:
        try:
            async with websockets.connect(url) as ws:
                log.info("connected to %s", url)
                async for raw in ws:
                    msg = json.loads(raw)
                    on_event(msg.get("event"), msg.get("data") or {})
        except (OSError, websockets.ConnectionClosed) as e:
            log.warning("peripheral API: %s, reconnecting in 5 s", e)
        await asyncio.sleep(5)


async def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--url", default="ws://127.0.0.1:6055")
    p.add_argument("--target", required=True, help="PipeWire node of the microphone")
    p.add_argument("--dir", required=True)
    p.add_argument("--pre-roll", type=float, default=4.0, help="seconds kept before the wake word")
    p.add_argument("--post-roll", type=float, default=1.5, help="seconds kept after the pipeline is idle")
    p.add_argument("--max-audio", type=float, default=30.0, help="longest recording per activation")
    p.add_argument("--max-activation", type=float, default=120.0, help="give up waiting for idle after this")
    p.add_argument("--retention-days", type=int, default=30)
    args = p.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    Path(args.dir).mkdir(parents=True, exist_ok=True)

    recorder = Recorder(args.target, args.pre_roll, args.max_audio)
    activations = Log(args, recorder)
    await asyncio.gather(recorder.run(), follow(args.url, activations.on_event))


if __name__ == "__main__":
    asyncio.run(main())
