"""German sentences about timers, reminders and alarms.

Duckling reads the times and durations. Added here: which kind a sentence
is about, repeats ("werktags", "montags", "jeden Tag"), a timer's label and
a reminder's text. How an alarm rings (gently, with music) is not read from
the sentence: the caller passes it as the description.

Before Duckling sees the sentence, what it would misread is masked: replaced
by spaces, so its positions stay those of the sentence ("am Wochenende um 9"
would be Friday 21:00, "werktags um 6" today at 18:00).

Times and days must be said exactly: a time of day ("morgen früh", "heute
Abend") is too vague for a timer or an alarm, and Duckling's spans for it
are dropped. Reminders on a day without a time start at 9.
"""

from __future__ import annotations

import re
from datetime import datetime, timedelta

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
_ABOUT = re.compile(r"\b(?:daran,?\s+dass|daran,?|an|für|dass)\b", re.I)


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


async def describe_timer(text: str, duckling: Ask) -> Parsed:
    """An existing timer as a request names it, by its name as set: the
    duration it was set to ("60 Minuten Timer", "Eine Stunde Timer") or its
    label ("Nudel Timer", "Nudeltimer"). Either may be missing."""
    text = repair(text)
    durations = [e for e in await duckling(text, LOCALE, ["duration"]) if e["dim"] == "duration"]
    longest = max(durations, key=lambda e: e["end"] - e["start"]) if durations else None
    return Parsed(
        KIND_TIMER,
        duration=float(longest["value"]["normalized"]["value"]) if longest else None,
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


async def describe_when(text: str, duckling: Ask) -> Parsed:
    """When something should ring again, as said: after a duration ("10
    Minuten", `duration`) or at a time ("in 10 Minuten", "morgen um 17
    Uhr", `at`)."""
    text = repair(text)
    entities = await duckling(text, LOCALE, ["time", "duration"])
    found = [e for e in entities if e["dim"] == "duration"] + _times(entities)
    if not found:
        return Parsed(reason="no time")
    best = max(found, key=lambda e: e["end"] - e["start"])
    if best["dim"] == "duration":
        return Parsed(duration=float(best["value"]["normalized"]["value"]))
    instants = _instants(best)
    if not instants or best["value"].get("grain") not in ("hour", "minute", "second"):
        return Parsed(reason="vague time")
    return Parsed(at=instants[0])


def _span_end(start: datetime, grain: str) -> datetime:
    """The end of the `grain` ("day", "week", …) that begins at `start`."""
    if grain == "month":
        return start.replace(year=start.year + start.month // 12, month=start.month % 12 + 1)
    if grain == "year":
        return start.replace(year=start.year + 1)
    steps = {"second": 1, "minute": 60, "hour": 3600, "day": 86400, "week": 7 * 86400}
    return start + timedelta(seconds=steps.get(grain, 86400))


async def describe_span(text: str, duckling: Ask) -> Parsed:
    """A stretch of time as said ("heute", "nächsten Samstag", "am 17.
    April", "nächste Woche"): from `at` until `until`."""
    text = repair(text)
    entities = _times(await duckling(text, LOCALE, ["time"]))
    if not entities:
        return Parsed(reason="no time")
    value = entities[0]["value"]
    if value.get("type") == "interval":
        start, end = value.get("from"), value.get("to")
        if not start or not end:
            return Parsed(reason="vague time")
        return Parsed(
            at=datetime.fromisoformat(start["value"]), until=datetime.fromisoformat(end["value"])
        )
    instants = _instants(entities[0])
    if not instants:
        return Parsed(reason="vague time")
    return Parsed(at=instants[0], until=_span_end(instants[0], value.get("grain", "day")))


async def describe_reminder(text: str, duckling: Ask) -> Parsed:
    """Existing reminders as a request names them: what about ("den
    Zahnarzt", `summary`), when ("morgen um 9": `at`; "morgen": `at` and
    `until` span the day), or both."""
    text = repair(text)
    entities = _times(await duckling(text, LOCALE, ["time"]))
    entity = entities[0] if entities else None
    summary = _clean(_mask(text, [(entity["start"], entity["end"])]) if entity else text)
    summary = re.sub(r"^(?:an|für)\s+", "", summary, flags=re.I) or None
    if entity is None:
        return Parsed(KIND_REMINDER, summary=summary, reason=None if summary else "no time")
    instants = _instants(entity)
    grain = entity["value"].get("grain")
    if not instants:
        return Parsed(KIND_REMINDER, summary=summary, reason="vague time")
    if grain in ("hour", "minute", "second"):
        return Parsed(KIND_REMINDER, summary=summary, at=instants[0])
    return Parsed(
        KIND_REMINDER, summary=summary, at=instants[0], until=_span_end(instants[0], grain or "day")
    )


def _repeats(text: str) -> tuple[list[str], list[tuple[int, int]]]:
    """The repeats a sentence says ("werktags", "montags und mittwochs"), as
    `alarm_create`'s `days` takes them, and where they are."""
    masked: list[tuple[int, int]] = []
    days: list[str] = []
    for rx, repeat in _REPEATS:
        for m in rx.finditer(text):
            days += [d for d in repeat if d not in days]
            masked.append(m.span())
    for m in _DAY_LISTS.finditer(_mask(text, masked)):
        days += [d.lower() for d in _DAY.findall(m.group()) if d.lower() not in days]
        masked.append(m.span())
    return days, masked


def _clock(instants: list[datetime]) -> datetime:
    """A clock time as said: "um 7" is 7:00, not 19:00 (and "um 12" noon);
    Duckling's readings already say on which day it comes next."""
    return min(instants, key=lambda i: (i.hour == 0, i.hour, i))


async def describe_alarm(text: str, duckling: Ask) -> Parsed:
    """Existing alarms as a request names them: a repeat ("werktags um 6",
    `days`), one occurrence ("morgen um 7", "um 7": `date` and `time`) or a
    whole day ("morgen": `date` alone)."""
    text = repair(text)
    days, masked = _repeats(text)
    entities = _times(await duckling(_mask(text, masked), LOCALE, ["time"]))
    if not entities:
        return Parsed(KIND_ALARM, days=days, reason=None if days else "no time")
    entity = entities[0]
    instants = _instants(entity)
    grain = entity["value"].get("grain")
    if instants and grain in ("hour", "minute"):
        at = _clock(instants)
        return Parsed(
            KIND_ALARM,
            time=at.time().replace(second=0, microsecond=0),
            date=None if days else at.date(),
            days=days,
        )
    if instants and grain == "day" and not days:
        return Parsed(KIND_ALARM, date=instants[0].date())
    return Parsed(KIND_ALARM, days=days, reason="vague time")


async def _alarm(text: str, duckling: Ask) -> Parsed:
    days, masked = _repeats(text)
    entities = _times(await duckling(_mask(text, masked), LOCALE, ["time"]))
    if not entities:
        return Parsed(KIND_ALARM, days=days, reason="no time")
    entity = entities[0]
    instants = _instants(entity)
    if not instants or entity["value"].get("grain") not in ("hour", "minute"):
        return Parsed(KIND_ALARM, days=days, reason="vague time")
    at = _clock(instants)
    return Parsed(
        KIND_ALARM,
        time=at.time().replace(second=0, microsecond=0),
        date=None if days else at.date(),
        days=days,
    )
