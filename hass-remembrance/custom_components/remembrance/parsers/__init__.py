"""From a sentence to a timer, reminder or alarm: one parser per language.

A parser takes the whole sentence ("Weck mich werktags um halb sieben mit
Musik"), finds out which kind it is about (unless told), and what it says:
Duckling reads the times and durations, the parser adds what is particular
to its language (repeats, labels, wake-up music). It never acts itself; the
engine creates what it returns.
"""

from __future__ import annotations

from collections.abc import Awaitable, Callable
from dataclasses import dataclass, field
from datetime import date, datetime, time
from typing import Any

# Duckling, asked (text, locale, dims) -> its entities for the text.
Ask = Callable[[str, str, list[str]], Awaitable[list[dict]]]


@dataclass
class Parsed:
    """What a sentence says. `reason` set: not enough (or not understood)."""

    kind: str | None = None
    # Timers: how long.
    duration: float | None = None
    # Timers and alarms.
    label: str | None = None
    # Reminders: what about, and when it starts.
    summary: str | None = None
    at: datetime | None = None
    # Alarms: the time of day, and either a day or repeats (as
    # `alarm_create`'s `days` takes them).
    time: time | None = None
    date: date | None = None
    days: list[str] = field(default_factory=list)
    gentle: bool = False
    # Wake up to music: a playlist, "" for the default one.
    playlist: str | None = None
    # Alarms: the description lines the ring script reads ("Sanft", "Musik").
    description: str | None = None
    reason: str | None = None

    def as_dict(self) -> dict[str, Any]:
        def plain(value: Any) -> Any:
            return value.isoformat() if isinstance(value, date | time) else value

        return {k: plain(v) for k, v in self.__dict__.items() if v not in (None, [], False)}


# (sentence, kind if known, Duckling) -> what it says.
Parser = Callable[[str, str | None, Ask], Awaitable[Parsed]]


def parser_for(language: str) -> Parser | None:
    """The parser for a language ("de", "de-DE", "de_CH"), if there is one."""
    from . import de

    parsers: dict[str, Parser] = {"de": de.parse}
    return parsers.get(language.replace("_", "-").split("-")[0].lower())
