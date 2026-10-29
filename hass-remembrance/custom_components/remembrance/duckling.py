"""A client for Duckling's HTTP server (`duckling-example-exe`), which reads
times, durations and numbers in text, in many languages."""

from __future__ import annotations

import json
from datetime import datetime

import aiohttp

from .parsers import Ask


class DucklingError(Exception):
    pass


def client(session: aiohttp.ClientSession, url: str, tz: str, now: datetime) -> Ask:
    """Asks the server at `url`, with times relative to `now` in `tz`."""

    async def ask(text: str, locale: str, dims: list[str]) -> list[dict]:
        data = {
            "text": text,
            "locale": locale,
            "tz": tz,
            "reftime": str(int(now.timestamp() * 1000)),
            "dims": json.dumps(dims),
        }
        try:
            async with session.post(
                url.rstrip("/") + "/parse", data=data, timeout=aiohttp.ClientTimeout(total=5)
            ) as resp:
                resp.raise_for_status()
                return await resp.json(content_type=None)
        except (aiohttp.ClientError, TimeoutError, ValueError) as err:
            raise DucklingError(str(err) or type(err).__name__) from err

    return ask
