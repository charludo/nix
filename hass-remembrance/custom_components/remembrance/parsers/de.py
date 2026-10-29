"""German sentences about timers, reminders and alarms.

Duckling reads the times and durations. Added here: which kind a sentence
is about, repeats ("werktags", "montags", "jeden Tag"), gentle alarms and
wake-up music, a timer's label and a reminder's text.

Before Duckling sees the sentence, what it would misread is masked: replaced
by spaces, so its positions stay those of the sentence ("am Wochenende um 9"
would be Friday 21:00, "werktags um 6" today at 18:00).

Times and days must be said exactly: a time of day ("morgen früh", "heute
Abend") is too vague for a timer or an alarm, and Duckling's spans for it
are dropped. Reminders on a day without a time start at 9.
"""

from __future__ import annotations

import re
from datetime import datetime

from ..const import KIND_ALARM, KIND_REMINDER, KIND_TIMER
from . import Ask, Parsed

LOCALE = "de_DE"

# A day without a time, for reminders.
DEFAULT_HOUR = 9

_WEEKDAYS = ["montag", "dienstag", "mittwoch", "donnerstag", "freitag", "samstag", "sonntag"]
_WD = "(?:" + "|".join(_WEEKDAYS) + ")"
_AND = r"\s*(?:,|und)\s*"

# The earliest of these in a sentence says what it is about.
_KINDS = [
    (KIND_ALARM, re.compile(r"\bweck", re.I)),
    (KIND_REMINDER, re.compile(r"\berinner", re.I)),
    (KIND_TIMER, re.compile(r"timer\b|\bab jetzt\b", re.I)),
]

# Repeats, as `alarm_create`'s `days` takes them.
_REPEATS = [
    (
        re.compile(
            r"\b(?:werktags|wochentags|an (?:werk|wochen)tagen|(?:von )?montags? bis freitags?)\b",
            re.I,
        ),
        ["werktags"],
    ),
    (re.compile(r"\b(?:täglich|jeden tag|alle tage)\b", re.I), ["täglich"]),
    (re.compile(r"\b(?:am wochenende|an wochenenden|wochenends)\b", re.I), ["wochenende"]),
]
# "montags", "montags und mittwochs", "jeden Montag (und Mittwoch)".
_DAY_LISTS = re.compile(
    rf"\b(?:(?:jeden|immer)\s+{_WD}(?:{_AND}{_WD})*|{_WD}s(?:{_AND}{_WD}s)*)\b", re.I
)
_DAY = re.compile(_WD, re.I)

_GENTLE = re.compile(r"\bsanft\w*", re.I)
# "Weck mich …": asleep, so gently.
_WAKE_ME = re.compile(r"\bweck\w*\s+mich\b", re.I)
_PLAYLIST = re.compile(
    r"\bmit\s+(?:der\s+)?(?:playlist|wiedergabeliste)\s+(?P<name>.+?)[\s.!?]*$", re.I
)
_MUSIC = re.compile(r"\bmit\s+musik\b", re.I)

# Timers: "Nudeltimer", "Nudel-Timer", "Nudel Timer", "Timer für die Nudeln".
_LABEL_COMPOUND = re.compile(r"\b(?P<label>\w+?)-?timer\b", re.I)
_LABEL_BEFORE = re.compile(r"(?P<label>\w+)\s+timer\b", re.I)
_LABEL_FOR = re.compile(r"\btimer\s+für\s+(?:(?:die|den|das)\s+)?(?P<label>\w+)", re.I)
_NOT_LABELS = {
    "ein",
    "einen",
    "eine",
    "der",
    "den",
    "die",
    "das",
    "neuen",
    "neue",
    "stelle",
    "stell",
    "starte",
    "start",
    "setze",
    "setz",
    "mach",
    "mache",
    "bitte",
    "sekunden",
    "minuten",
    "stunden",
    "sekunde",
    "minute",
    "stunde",
}

# Reminders: what is said before the text, and what introduces it.
_REMIND_ME = re.compile(r"^\W*(?:bitte\s+)?erinnere?\s+(?:mich|uns)\b(?:\s+bitte\b)?", re.I)
_ABOUT = re.compile(r"\b(?:daran,?\s+dass|daran,?|an|dass)\b", re.I)


# Voice pipelines may turn punctuation into spaces (closest_intent does):
# "3,5 Minuten" arrives as "3 5 Minuten", "am 3.11." as "am 3 11". Clock
# times ("6 30") Duckling reads as they are.
_SPLIT_DECIMAL = re.compile(r"\b(\d+) (\d) (sekunden?|minuten?|stunden?)\b", re.I)
_SPLIT_DATE = re.compile(r"\bam (\d{1,2}) (\d{1,2})\b", re.I)


def repair(text: str) -> str:
    text = _SPLIT_DECIMAL.sub(r"\1,\2 \3", text)
    return _SPLIT_DATE.sub(r"am \1.\2.", text)


def kind_of(text: str) -> str | None:
    found = [(m.start(), kind) for kind, rx in _KINDS if (m := rx.search(text))]
    return min(found)[1] if found else None


async def parse(text: str, kind: str | None, duckling: Ask) -> Parsed:
    text = repair(text)
    kind = kind or kind_of(text)
    if kind == KIND_TIMER:
        return await _timer(text, duckling)
    if kind == KIND_REMINDER:
        return await _reminder(text, duckling)
    if kind == KIND_ALARM:
        return await _alarm(text, duckling)
    return Parsed(reason="unknown kind")


def _mask(text: str, spans: list[tuple[int, int]]) -> str:
    chars = list(text)
    for start, end in spans:
        chars[start:end] = " " * (end - start)
    return "".join(chars)


def _clean(text: str) -> str:
    return " ".join(text.split()).strip(" ,.!?")


def _overlaps(span: tuple[int, int], entities: list[dict]) -> bool:
    return any(span[0] < e["end"] and e["start"] < span[1] for e in entities)


def _times(entities: list[dict]) -> list[dict]:
    """The (non-latent) time entities, longest first."""
    found = [e for e in entities if e["dim"] == "time" and not e.get("latent")]
    return sorted(found, key=lambda e: e["start"] - e["end"])


def _instants(entity: dict) -> list[datetime]:
    """An entity's readings ("um 7": 19:00 today, 7:00 tomorrow, …); none
    for spans ("morgen früh")."""
    value = entity["value"]
    if value.get("type") != "value":
        return []
    return [datetime.fromisoformat(v["value"]) for v in value.get("values") or [value]]


async def _timer(text: str, duckling: Ask) -> Parsed:
    durations = [e for e in await duckling(text, LOCALE, ["duration"]) if e["dim"] == "duration"]
    if not durations:
        return Parsed(KIND_TIMER, reason="no duration")
    longest = max(durations, key=lambda e: e["end"] - e["start"])
    return Parsed(
        KIND_TIMER,
        duration=float(longest["value"]["normalized"]["value"]),
        label=_label(text, durations),
    )


def _label(text: str, durations: list[dict]) -> str | None:
    for rx in (_LABEL_FOR, _LABEL_COMPOUND, _LABEL_BEFORE):
        for m in rx.finditer(text):
            label = m.group("label")
            if (
                label.lower() not in _NOT_LABELS
                and not label.isdigit()
                and not _overlaps(m.span("label"), durations)
            ):
                return label[:1].upper() + label[1:]
    return None


async def _reminder(text: str, duckling: Ask) -> Parsed:
    entities = _times(await duckling(text, LOCALE, ["time"]))
    if not entities:
        return Parsed(KIND_REMINDER, reason="no time")
    entity = entities[0]
    instants = _instants(entity)
    if not instants:
        return Parsed(KIND_REMINDER, reason="vague time")
    grain = entity["value"].get("grain")
    at = instants[0]
    if grain == "day":
        at = at.replace(hour=DEFAULT_HOUR)
    elif grain not in ("hour", "minute", "second"):
        return Parsed(KIND_REMINDER, reason="vague time")

    rest = _mask(text, [(entity["start"], entity["end"])])
    rest = _mask(rest, [m.span() for m in _REMIND_ME.finditer(rest)])
    about = _ABOUT.search(rest)
    summary = _clean(rest[about.end() :] if about else rest)
    if not summary:
        return Parsed(KIND_REMINDER, at=at, reason="no summary")
    return Parsed(KIND_REMINDER, summary=summary, at=at)


async def _alarm(text: str, duckling: Ask) -> Parsed:
    masked: list[tuple[int, int]] = []

    days: list[str] = []
    for rx, repeat in _REPEATS:
        for m in rx.finditer(text):
            days += [d for d in repeat if d not in days]
            masked.append(m.span())
    for m in _DAY_LISTS.finditer(_mask(text, masked)):
        days += [d.lower() for d in _DAY.findall(m.group()) if d.lower() not in days]
        masked.append(m.span())

    playlist = None
    if m := _PLAYLIST.search(text):
        playlist = _clean(m.group("name"))
        masked.append(m.span())
    elif m := _MUSIC.search(text):
        playlist = ""
    gentle = bool(_GENTLE.search(text) or _WAKE_ME.search(text))
    description = (
        "\n".join(
            (["Sanft"] if gentle else [])
            + ([f"Musik: {playlist}" if playlist else "Musik"] if playlist is not None else [])
        )
        or None
    )

    entities = _times(await duckling(_mask(text, masked), LOCALE, ["time"]))
    if not entities:
        return Parsed(KIND_ALARM, days=days, reason="no time")
    entity = entities[0]
    instants = _instants(entity)
    if not instants or entity["value"].get("grain") not in ("hour", "minute"):
        return Parsed(KIND_ALARM, days=days, reason="vague time")
    # A clock time as said: "um 7" is 7:00, not 19:00 (and "um 12" noon);
    # Duckling's readings already say on which day it comes next.
    at = min(instants, key=lambda i: (i.hour == 0, i.hour, i))
    return Parsed(
        KIND_ALARM,
        time=at.time().replace(second=0, microsecond=0),
        date=None if days else at.date(),
        days=days,
        gentle=gentle,
        playlist=playlist,
        description=description,
    )
