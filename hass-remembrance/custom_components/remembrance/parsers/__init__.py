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
    # A stretch of time ("morgen", "nächste Woche"): from `at` until this.
    until: datetime | None = None
    # Alarms: the time of day, and either a day or repeats (as
    # `alarm_create`'s `days` takes them).
    time: time | None = None
    date: date | None = None
    days: list[str] = field(default_factory=list)
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


# (what a request says about a timer, Duckling) -> its duration and label.
TimerDescriber = Callable[[str, Ask], Awaitable[Parsed]]


def timer_describer_for(language: str) -> TimerDescriber | None:
    """How a language names existing timers ("den Nudel Timer", "den
    60 Minuten Timer"), if there is a parser for it."""
    from . import de

    describers: dict[str, TimerDescriber] = {"de": de.describe_timer}
    return describers.get(language.replace("_", "-").split("-")[0].lower())


# (what a request says about alarms, Duckling) -> their time, day or repeats.
AlarmDescriber = Callable[[str, Ask], Awaitable[Parsed]]


def alarm_describer_for(language: str) -> AlarmDescriber | None:
    """How a language names existing alarms ("morgen um 7", "werktags um
    6"), if there is a parser for it."""
    from . import de

    describers: dict[str, AlarmDescriber] = {"de": de.describe_alarm}
    return describers.get(language.replace("_", "-").split("-")[0].lower())


# (when something should ring again, Duckling) -> a duration or a time.
WhenDescriber = Callable[[str, Ask], Awaitable[Parsed]]


def when_describer_for(language: str) -> WhenDescriber | None:
    """How a language says when to ring again ("in 10 Minuten", "morgen um
    17 Uhr"), if there is a parser for it."""
    from . import de

    describers: dict[str, WhenDescriber] = {"de": de.describe_when}
    return describers.get(language.replace("_", "-").split("-")[0].lower())


# (a stretch of time / reminders as said, Duckling) -> what it says.
SpanDescriber = Callable[[str, Ask], Awaitable[Parsed]]


def span_describer_for(language: str) -> SpanDescriber | None:
    """How a language says a stretch of time ("morgen", "nächsten Samstag")."""
    from . import de

    describers: dict[str, SpanDescriber] = {"de": de.describe_span}
    return describers.get(language.replace("_", "-").split("-")[0].lower())


def reminder_describer_for(language: str) -> SpanDescriber | None:
    """How a language names existing reminders ("den Zahnarzt morgen")."""
    from . import de

    describers: dict[str, SpanDescriber] = {"de": de.describe_reminder}
    return describers.get(language.replace("_", "-").split("-")[0].lower())
