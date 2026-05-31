"""Sync Music Assistant library into a HA custom_sentences slot-list YAML.

Pulls artists, albums, playlists and tracks over MA's websocket API,
applies a category-specific cleanup so STT-style spoken forms map back
to the exact library names MA needs, writes the hassil slot lists, and
pings HA's ``conversation.reload``. closest_intent (and HA core
conversation) picks the file up at reload time.

Token files default to systemd's ``$CREDENTIALS_DIRECTORY/{mass,hass}-token``.
"""

import argparse
import asyncio
import logging
import os
import re
import sys
import tempfile
from pathlib import Path

import aiohttp
import yaml
from music_assistant_client import MusicAssistantClient
from music_assistant_client.exceptions import CannotConnect

LOGGER = logging.getLogger("mass-slot-lists")

PAGE = 500

PLAYLIST_SUFFIX = " (from library)"

# Anything bracket-like; iterate so nested wrappers fully collapse.
_BRACKETS_RE = re.compile(r"[\(\[\{][^\(\[\{\)\]\}]*[\)\]\}]")

# Marker used to coalesce a regex of disparate separators into a
# single splittable boundary. Picked to never appear in library data.
_SEP = "\x00"

# Characters with syntactic meaning to hassil when parsing a slot-list
# `in:` value as a sentence template. Stray (e.g. unbalanced ")") or
# functional (e.g. "|") occurrences make hassil's parser bail and the
# whole conversation lang fails to load. Stripped from every `in:` we
# emit; canonical `out:` keeps the original so MA still gets the exact
# library title for lookup.
_HASSIL_SPECIALS_RE = re.compile(r"[\(\)\[\]\{\}\<\>\|]")


def _sanitise_for_hassil(s: str) -> str:
    return re.sub(r"\s+", " ", _HASSIL_SPECIALS_RE.sub(" ", s)).strip()


# Common boilerplate ripped out of album / track titles before splitting.
# "Original Soundtrack" appears in both bracketed ("(Original Soundtrack)")
# and bare (" - Original Soundtrack") forms; bracket-stripping handles the
# former, this handles the latter.
_OST_RE = re.compile(r"(?i)\boriginal soundtrack\b")


def _strip_phrases(s: str) -> str:
    return re.sub(r"\s+", " ", _OST_RE.sub("", s)).strip()


def _strip_brackets(s: str) -> str:
    """Iteratively strip (...) [...] {...} contents (no nesting depth)."""
    while True:
        new = _BRACKETS_RE.sub("", s)
        if new == s:
            return re.sub(r"\s+", " ", new).strip()
        s = new


def _normalise_track_chars(s: str) -> str:
    """Replace ; and non-ASCII non-letter chars (symbols, em-dashes,
    emoji, hearts, stars) with a space; preserve umlauts and other
    non-ASCII *letters*. Squash repeated whitespace."""
    out_chars = []
    for c in s:
        if c == ";":
            out_chars.append(" ")
        elif ord(c) > 127 and not c.isalpha():
            out_chars.append(" ")
        else:
            out_chars.append(c)
    return re.sub(r"\s+", " ", "".join(out_chars)).strip()


# --------------------------------------------------------------------------
# Artists
# --------------------------------------------------------------------------

def _split_artist(name: str) -> list[str]:
    """Split a "collaboration" artist string into its members.

    Drops bracketed annotations first ("(Live in 1972)" etc.), then
    splits on the symbol-style separators ( |, /, ;, ,, & ) and the
    word-style ones (feat./featuring/and/with/und/mit). Result excludes
    the original (the original is emitted separately as the canonical).
    """
    cleaned = _strip_brackets(name)
    # Word-form splitters need to be substituted first so we don't tear
    # words like "Land" via "and".
    cleaned = re.sub(
        r"(?i)\bfeat\.?(?=\s|$)|\b(?:featuring|with|and|und|mit)\b",
        _SEP,
        cleaned,
    )
    # Symbol-form splitters.
    cleaned = re.sub(r"[|/;,&]", _SEP, cleaned)
    parts = [p.strip() for p in cleaned.split(_SEP) if p.strip()]
    # Dedup, preserve order, drop the full-name echo.
    seen = {name.lower()}
    out: list[str] = []
    for p in parts:
        key = p.lower()
        if key in seen:
            continue
        seen.add(key)
        out.append(p)
    return out


# --------------------------------------------------------------------------
# Albums
# --------------------------------------------------------------------------

_ALBUM_PREFIX_RE = re.compile(r"^(\w[\w']*):\s*(.+)$")


def _split_album(name: str) -> list[str]:
    """Split a multi-piece album title into addressable subtitles.

    Bracketed annotations and "Original Soundtrack" boilerplate are
    stripped first. If the title starts with "<Word>: ..." (common
    for classical compilations like "Dvorak: Symphony No.9 & Slavonic
    Dances"), strip the prefix off the splittable portion and prepend
    "<Word> " to every resulting segment — so "Dvorak Slavonic Dances"
    still resolves to the original album.
    """
    cleaned_name = _strip_phrases(_strip_brackets(name))
    if not cleaned_name:
        return []

    prefix_match = _ALBUM_PREFIX_RE.match(cleaned_name)
    if prefix_match:
        prefix, rest = prefix_match.groups()
    else:
        prefix, rest = None, cleaned_name

    cleaned = re.sub(r"[|/;&]", _SEP, rest)
    cleaned = re.sub(r"\s+-\s+", _SEP, cleaned)
    parts = [p.strip() for p in cleaned.split(_SEP) if p.strip()]
    if prefix:
        parts = [f"{prefix} {p}" for p in parts]

    # Also include the bracket/OST-stripped form as a direct alias if
    # it differs from the original — useful for spoken matches against
    # albums like "Dark Side of the Moon (Remastered)".
    if cleaned_name.lower() != name.lower():
        parts.insert(0, cleaned_name)

    seen = {name.lower()}
    out: list[str] = []
    for p in parts:
        key = p.lower()
        if key in seen:
            continue
        seen.add(key)
        out.append(p)
    return out


# --------------------------------------------------------------------------
# Tracks
# --------------------------------------------------------------------------

# (term, case_sensitive). A segment is dropped when it contains the term
# AND its length is below `len(term) + 6`. The +6 buffer is a safety
# valve against shadowing useful titles ("Soundtrack" survives "Track").
_TRACK_FILTER_TERMS: list[tuple[str, bool]] = [
    ("creditless", False),
    ("fps", False),
    ("4k", False),
    ("Subtitles", False),
    ("UHD", False),
    ("Opening", False),
    ("Moderation", False),
    ("Track", False),
    ("Spur", False),
    ("CC", True),
]


def _track_segment_filtered(segment: str) -> bool:
    for term, case_sensitive in _TRACK_FILTER_TERMS:
        haystack = segment if case_sensitive else segment.lower()
        needle = term if case_sensitive else term.lower()
        if needle in haystack and len(segment) < len(term) + 6:
            return True
    return False


def _track_title_is_junk(name: str) -> bool:
    """Drop the entire track when its title contains two or more filter
    terms — catches credit-less / OP / UHD / FPS combos that the
    per-segment length check can't help with because they all live in
    one long segment ("Creditless SPY x FAMILY OP Opening 4 UHD 60FPS").
    Single matches are still left to the segment-level filter so titles
    like "Soundtrack to Spider-Man" survive."""
    count = 0
    name_lower = name.lower()
    for term, case_sensitive in _TRACK_FILTER_TERMS:
        haystack = name if case_sensitive else name_lower
        needle = term if case_sensitive else term.lower()
        if needle in haystack:
            count += 1
            if count >= 2:
                return True
    return False


def _artist_name_set(artist_str: str | None) -> set[str]:
    """Lowercased atom set for "is-this-segment-just-the-artist" check.

    MA joins artist names with `/`; split that plus common collab
    separators so we can identify "Beatles" as the artist regardless
    of whether the track's artist_str is "The Beatles" or
    "Beatles/Lennon".
    """
    if not artist_str:
        return set()
    parts = re.split(r"\s*[/&,;|]\s*", artist_str)
    return {p.strip().lower() for p in parts if p.strip()}


def _track_segments(name: str, artist_str: str | None) -> list[str]:
    """Build the alias-segments list for a track title.

    Pipeline: char-normalise → bracket-strip → split on |, /, " - " →
    drop segments matching filter terms (within length threshold),
    too-short (<5), numeric-only, or identical to the artist name.
    Final dedup. Empty list ⇒ caller should drop the track entirely.
    """
    cleaned = _normalise_track_chars(name)
    cleaned = _strip_brackets(cleaned)
    cleaned = _strip_phrases(cleaned)
    cleaned = re.sub(r"[|/]", _SEP, cleaned)
    cleaned = re.sub(r"\s+-\s+", _SEP, cleaned)
    raw_parts = [p.strip() for p in cleaned.split(_SEP) if p.strip()]

    artist_names = _artist_name_set(artist_str)
    seen: set[str] = set()
    out: list[str] = []
    for p in raw_parts:
        if _track_segment_filtered(p):
            continue
        if len(p) < 5:
            continue
        if p.isdigit():
            continue
        key = p.lower()
        if key in artist_names:
            continue
        if key in seen:
            continue
        seen.add(key)
        out.append(p)
    return out


# --------------------------------------------------------------------------
# Playlists
# --------------------------------------------------------------------------

def _playlist_aliases(name: str) -> list[str]:
    """Strip the '(from library)' suffix MA appends to its built-in playlists."""
    if name.endswith(PLAYLIST_SUFFIX):
        stripped = name[: -len(PLAYLIST_SUFFIX)].rstrip()
        return [stripped] if stripped else []
    return []


# --------------------------------------------------------------------------
# Genres
# --------------------------------------------------------------------------

# MA's frontend ships these translations bundled inside its minified JS;
# the backend only stores the English `name` and a `translation_key` per
# default genre. We mirror the German short titles here so voice intents
# can be spoken in German while still resolving to the same library item
# MA looks up by English `name`. Extracted from music-assistant-frontend
# 2.17.x; missing keys fall back to the English name.
_GENRE_DE: dict[str, str] = {
    "afrobeats": "Afrobeats",
    "ambient": "Ambient",
    "anime_and_video_game_music": "Anime- und Videospielmusik",
    "asian_music": "Asiatische Musik",
    "bluegrass": "Bluegrass",
    "blues": "Blues",
    "brazilian_music": "Brasilianische Musik",
    "chanson": "Chanson",
    "childrens_music": "Kindermusik",
    "christmas_music": "Weihnachtsmusik",
    "church_music": "Kirchenmusik",
    "classical": "Klassische",
    "comedy": "Komödie",
    "country": "Country",
    "dance": "Dance",
    "dark_ambient": "Dark-Ambient",
    "dark_wave": "Dark-Wave",
    "disco": "Disko",
    "electronic": "Elektronische",
    "experimental": "Experimentelle",
    "field_recording": "Feldaufnahme",
    "folk": "Folk",
    "funk": "Funk",
    "gangsta_rap": "Gangsta-Rap",
    "gospel": "Gospel",
    "hip_hop": "Hip-Hop",
    "indian_classical": "Indische Klassik",
    "industrial": "Industrial",
    "jazz": "Jazz",
    "klezmer": "Klezmer",
    "latin": "Lateinische",
    "marching_band": "Marschkapelle",
    "metal": "Metal",
    "middle_eastern_music": "Nahöstliche Musik",
    "musical": "Musical",
    "new_age": "New Age",
    "poetry": "Poesie",
    "polka": "Polka",
    "pop": "Pop",
    "psychedelic": "Psychedelische",
    "punk": "Punk",
    "r_b": "R&B",
    "ragtime": "Ragtime",
    "rai": "Raï",
    "reggae": "Reggae",
    "reggaeton": "Reggaeton",
    "rock": "Rock",
    "salsa": "Salsa",
    "singer_songwriter": "Sänger-Songwriter",
    "ska": "Ska",
    "soul": "Soul",
    "sound_effects": "Soundeffekte",
    "soundtrack": "Soundtrack",
    "spoken_word": "Gesprochenes Wort",
    "swing": "Swing",
    "tango": "Tango",
    "trap": "Trap",
    "waltz": "Walzer",
    "wellness": "Wellness",
}


async def _fetch_genres(client) -> list[tuple[str, str]]:
    """Return MA's default, non-empty genres as (spoken, library_uri) pairs.

    Two-step over MA's websocket API:
      1. ``music/genres/library_items`` with no args → MA's curated "default"
         genres (rows where ``translation_key`` is set). MA itself does the
         cleanup/canonicalisation we'd otherwise have to do here.
      2. ``music/genres/media_counts`` for those IDs → drop any genre whose
         mapped-media count across all media types is zero, so we don't
         surface genres MA's UI would render as empty buckets.

    `spoken` is the German short title pulled from `_GENRE_DE` via the
    item's `translation_key`, falling back to the English `name` if MA
    ever ships a translation_key we don't have a German mapping for.
    `library_uri` is the canonical ``library://genre/<id>`` form. The MA
    integration's ``play_media`` resolves names via ``get_item_by_name``,
    which only iterates artist/album/track/playlist/radio/audiobook/podcast
    library getters — there is no ``get_library_genres`` — so a bare name
    can't ever resolve to a genre. URIs hit the direct ``"://" in s``
    branch instead, which feeds straight into ``player_queues.play_media``
    and from there into ``get_genre_tracks``.
    """
    items = await client.send_command("music/genres/library_items")
    if not items:
        return []
    ids = [str(it["item_id"]) for it in items if it.get("item_id") is not None]
    counts = await client.send_command("music/genres/media_counts", genre_ids=ids)
    out: list[tuple[str, str]] = []
    for it in items:
        gid = str(it.get("item_id", ""))
        if not gid or not any(counts.get(gid, {}).values()):
            continue
        eng = (it.get("name") or "").strip()
        if not eng:
            continue
        tkey = (it.get("translation_key") or "").strip()
        spoken = _GENRE_DE.get(tkey, eng)
        out.append((spoken, f"library://genre/{gid}"))
    return out


# Strip a trailing "musik" (with or without a leading separator) from a
# genre title so slot values are stems like "Asiatische" / "Kinder" /
# "Anime- und Videospiel" rather than "Asiatische Musik" / "Kindermusik" /
# "Anime- und Videospielmusik". The intent template then requires the
# trailing " Musik" explicitly, which keeps closest_intent's fuzzy
# matcher from greedily capturing "<stem> musik" as the slot region and
# then snapping to whichever slot value happens to end in "Musik" — the
# failure mode that pulled "klassische musik" to "Asiatische Musik".
_MUSIK_SUFFIX_RE = re.compile(r"[\s-]*musik$", re.IGNORECASE)


def _strip_musik_suffix(s: str) -> str:
    return _MUSIK_SUFFIX_RE.sub("", s).rstrip()


def _genre_slot_values(genres: list[tuple[str, str]]) -> list:
    """Emit ``{in: stem, out: uri}`` for each genre, dedup by stem.

    `_strip_brackets` removes parenthetical disambiguation from titles
    like "Afrobeats (westafrikanische Urban-/Popmusik)"; `_strip_musik_suffix`
    drops a trailing "musik"/" Musik"/"-Musik" so the slot value is the
    bare stem the intent template's trailing " Musik" gets appended to.
    `_sanitise_for_hassil` strips parser-meaningful chars. The `out:` is
    always a URI (never echoed in speech)."""
    out: list = []
    seen: set[str] = set()
    for spoken, uri in sorted(genres, key=lambda x: x[0].lower()):
        stem = _strip_musik_suffix(_strip_brackets(spoken))
        clean = _sanitise_for_hassil(stem)
        if not clean:
            continue
        key = clean.lower()
        if key in seen:
            continue
        seen.add(key)
        out.append({"in": clean, "out": uri})
    return out


# --------------------------------------------------------------------------
# Slot-list construction
# --------------------------------------------------------------------------

def _emit(out: list, canonical: str, aliases: list[str]) -> None:
    """Append a canonical name + its aliases to a slot-values list,
    ensuring every `in:` is hassil-safe. If the canonical itself has
    specials we emit it as `{in: cleaned, out: canonical}` so MA still
    receives the exact library string at action time. `cleaned` strips
    bracket *contents* (not just the bracket chars themselves) so the
    spoken form lines up with the rest of the alias list."""
    clean_canon = _sanitise_for_hassil(_strip_brackets(canonical))
    if not clean_canon:
        return
    if clean_canon == canonical:
        out.append(canonical)
    else:
        out.append({"in": clean_canon, "out": canonical})

    canon_key = clean_canon.lower()
    for alias in aliases:
        clean = _sanitise_for_hassil(alias)
        if not clean or clean.lower() == canon_key:
            continue
        out.append({"in": clean, "out": canonical})


def _values_with_aliases(names: list[str], alias_fn) -> list:
    """Plain canonical strings + `{in: alias, out: canonical}` entries."""
    out: list = []
    for name in names:
        _emit(out, name, alias_fn(name))
    return out


def _track_slot_values(tracks: list) -> list:
    """Tracks need cleanup that depends on the per-track artist string;
    can also drop the track entirely when nothing survives filtering."""
    out: list = []
    seen_canon: set[str] = set()
    for t in tracks:
        name = (t.name or "").strip()
        if not name:
            continue
        if _track_title_is_junk(name):
            continue
        artist_str = getattr(t, "artist_str", None) or ""
        segments = _track_segments(name, artist_str)
        if not segments:
            continue
        if name.isdigit():
            continue
        if name.lower() in seen_canon:
            continue
        seen_canon.add(name.lower())
        _emit(out, name, segments)
    return out


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
            tracks = await _fetch_all(client.music.get_library_tracks)
            genres = await _fetch_genres(client)
        finally:
            await client.disconnect()

        artist_names = sorted({a.name for a in artists if a.name})
        album_names = sorted({a.name for a in albums if a.name})
        playlist_names = sorted({p.name for p in playlists if p.name})

        artist_values = _values_with_aliases(artist_names, _split_artist)
        album_values = _values_with_aliases(album_names, _split_album)
        playlist_values = _values_with_aliases(playlist_names, _playlist_aliases)
        genre_values = _genre_slot_values(genres)
        track_values = _track_slot_values(tracks)

        LOGGER.info(
            "Fetched %d artists, %d albums, %d playlists, %d genres, %d tracks "
            "(%d kept after filtering)",
            len(artist_names), len(album_names), len(playlist_names),
            len(genres), len(tracks),
            sum(1 for v in track_values if isinstance(v, str)),
        )

        doc = {
            "language": args.language,
            "lists": {
                "mass_artist": {"values": artist_values},
                "mass_album": {"values": album_values},
                "mass_playlist": {"values": playlist_values},
                "mass_genre": {"values": genre_values},
                "mass_track": {"values": track_values},
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
