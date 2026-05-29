"""Sync Music Assistant artists + albums into a HA custom_sentences YAML.

Pulls the full library over MA's websocket API, writes a hassil slot-list
YAML next to the language pack, and pings HA's ``conversation.reload``.
The closest_intent custom component (and HA core conversation) picks up
the file at reload time.

Token files default to systemd's ``$CREDENTIALS_DIRECTORY/{mass,hass}-token``.
"""

import argparse
import asyncio
import logging
import os
import sys
import tempfile
from pathlib import Path

import aiohttp
import yaml
from music_assistant_client import MusicAssistantClient
from music_assistant_client.exceptions import CannotConnect

LOGGER = logging.getLogger("mass-slot-lists")

PAGE = 500


def _read_token(path: Path) -> str:
    return path.read_text().strip()


def parse_args() -> argparse.Namespace:
    creds = os.environ.get("CREDENTIALS_DIRECTORY", "")
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--mass-url", default="http://127.0.0.1:8095")
    p.add_argument("--hass-url", default="http://127.0.0.1:8123")
    p.add_argument(
        "--mass-token-file",
        type=Path,
        default=Path(creds) / "mass-token" if creds else None,
        required=not creds,
    )
    p.add_argument(
        "--hass-token-file",
        type=Path,
        default=Path(creds) / "hass-token" if creds else None,
        required=not creds,
    )
    p.add_argument("--output", type=Path, required=True,
                   help="Destination YAML path, e.g. <hass>/custom_sentences/de/mass_lists.yaml")
    p.add_argument("--language", required=True,
                   help="Language code written into the YAML's `language:` field; HA ignores files without it")
    p.add_argument("--connect-timeout", type=float, default=120.0,
                   help="Total seconds to keep retrying MA connect on startup")
    p.add_argument("--connect-retry-delay", type=float, default=5.0)
    return p.parse_args()


async def _connect_with_retry(
    url: str, token: str, session: aiohttp.ClientSession,
    timeout: float, delay: float,
) -> MusicAssistantClient:
    """MA may still be coming up when we're invoked via wantedBy; retry until it accepts."""
    deadline = asyncio.get_event_loop().time() + timeout
    while True:
        client = MusicAssistantClient(url, session, token)
        try:
            await client.connect()
            return client
        except CannotConnect as err:
            if asyncio.get_event_loop().time() >= deadline:
                raise
            LOGGER.info("MA not ready (%s), retrying in %.1fs", err, delay)
            await asyncio.sleep(delay)


async def _fetch_all(getter):
    out = []
    offset = 0
    while True:
        chunk = await getter(limit=PAGE, offset=offset)
        out.extend(chunk)
        if len(chunk) < PAGE:
            return out
        offset += len(chunk)


def _write_atomic(path: Path, doc: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=path.name + ".", suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            yaml.safe_dump(doc, f, allow_unicode=True, sort_keys=False,
                           default_flow_style=False)
        os.replace(tmp, path)
    except Exception:
        try:
            os.unlink(tmp)
        except FileNotFoundError:
            pass
        raise


async def _reload_ha_conversation(hass_url: str, hass_token: str,
                                  session: aiohttp.ClientSession) -> None:
    headers = {"Authorization": f"Bearer {hass_token}"}
    async with session.post(
        f"{hass_url.rstrip('/')}/api/services/conversation/reload",
        headers=headers,
        json={},
    ) as resp:
        if resp.status >= 300:
            body = await resp.text()
            raise RuntimeError(f"conversation.reload HTTP {resp.status}: {body}")


async def main_async(args: argparse.Namespace) -> int:
    mass_token = _read_token(args.mass_token_file)
    hass_token = _read_token(args.hass_token_file)

    async with aiohttp.ClientSession() as session:
        client = await _connect_with_retry(
            args.mass_url, mass_token, session,
            args.connect_timeout, args.connect_retry_delay,
        )
        try:
            # No start_listening() here: send_command falls back to a direct
            # read when the listener loop isn't running, which is all we need
            # for a one-shot library snapshot. Racing the listener against
            # our own send_command calls eats responses ("Connection was closed").
            artists = await _fetch_all(client.music.get_library_artists)
            albums = await _fetch_all(client.music.get_library_albums)
            playlists = await _fetch_all(client.music.get_library_playlists)
        finally:
            await client.disconnect()

        artist_names = sorted({a.name for a in artists if a.name})
        album_names = sorted({a.name for a in albums if a.name})
        playlist_names = sorted({p.name for p in playlists if p.name})
        LOGGER.info("Fetched %d artists, %d albums, %d playlists",
                    len(artist_names), len(album_names), len(playlist_names))

        doc = {
            "language": args.language,
            "lists": {
                "mass_artist": {"values": artist_names},
                "mass_album": {"values": album_names},
                "mass_playlist": {"values": playlist_names},
            },
        }
        _write_atomic(args.output, doc)
        LOGGER.info("Wrote %s", args.output)

        try:
            await _reload_ha_conversation(args.hass_url, hass_token, session)
            LOGGER.info("Triggered conversation.reload")
        except Exception as err:
            # Don't fail the unit just because HA wasn't reachable; the next
            # full HA restart will pick the file up anyway.
            LOGGER.warning("conversation.reload failed: %s", err)

    return 0


def main() -> int:
    logging.basicConfig(level=logging.INFO,
                        format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    args = parse_args()
    return asyncio.run(main_async(args))


if __name__ == "__main__":
    sys.exit(main())
