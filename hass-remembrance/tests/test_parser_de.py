"""The German parser, against Duckling's answers recorded in
`duckling_de.json` (at Wednesday, 2026-10-28 14:00 in Berlin).

With DUCKLING_URL set, Duckling is asked instead and the recording updated:
  DUCKLING_URL=http://127.0.0.1:8000 python -m pytest tests/test_parser_de.py
"""

import asyncio
import json
import os
import urllib.parse
import urllib.request
from datetime import date, datetime, time
from pathlib import Path
from zoneinfo import ZoneInfo

import pytest

from remembrance.parsers import de, parser_for

TZ = "Europe/Berlin"
NOW = datetime(2026, 10, 28, 14, 0, tzinfo=ZoneInfo(TZ))
RECORDING = Path(__file__).with_name("duckling_de.json")
LIVE = os.environ.get("DUCKLING_URL")


class Duckling:
    def __init__(self) -> None:
        self.answers = json.loads(RECORDING.read_text()) if RECORDING.exists() else {}
        self.changed = False

    async def __call__(self, text: str, locale: str, dims: list[str]) -> list[dict]:
        key = f"{locale} {','.join(dims)} {text}"
        if LIVE:
            data = urllib.parse.urlencode(
                {
                    "text": text,
                    "locale": locale,
                    "tz": TZ,
                    "reftime": str(int(NOW.timestamp() * 1000)),
                    "dims": json.dumps(dims),
                }
            ).encode()
            with urllib.request.urlopen(LIVE.rstrip("/") + "/parse", data) as resp:
                answer = json.load(resp)
            if self.answers.get(key) != answer:
                self.answers[key] = answer
                self.changed = True
        assert key in self.answers, f"not recorded: {key!r} (run with DUCKLING_URL)"
        return self.answers[key]


@pytest.fixture(scope="module")
def duckling():
    d = Duckling()
    yield d
    if d.changed:
        RECORDING.write_text(json.dumps(d.answers, indent=1, sort_keys=True, ensure_ascii=False))


def parse(duckling, text, kind=None):
    return asyncio.run(de.parse(text, kind, duckling))


def at(day, hour, minute=0):
    return datetime(2026, 10, day, hour, minute, tzinfo=ZoneInfo(TZ))


@pytest.mark.parametrize(
    ("text", "duration", "label"),
    [
        ("Stelle einen Timer auf 5 Minuten", 300, None),
        ("5 Minuten Timer ab jetzt", 300, None),
        ("Timer auf eine Minute und dreißig Sekunden", 90, None),
        ("Timer auf 3,5 Minuten", 210, None),
        # As closest_intent hands it on.
        ("Timer auf 3 5 Minuten", 210, None),
        ("Stelle einen Timer auf eine Viertelstunde", 900, None),
        ("Stelle einen Timer auf eine halbe Stunde", 1800, None),
        ("Stelle einen Nudeltimer auf 8 Minuten", 480, "Nudel"),
        ("Stelle einen Nudel Timer auf anderthalb Stunden", 5400, "Nudel"),
        ("Timer für die Nudeln auf zweieinhalb Minuten", 150, "Nudeln"),
        ("Starte den Eier-Timer mit zwei Stunden und eine halbe", 9000, "Eier"),
    ],
)
def test_timer(duckling, text, duration, label):
    p = parse(duckling, text)
    assert (p.kind, p.reason, p.duration, p.label) == ("timer", None, duration, label)


def test_timer_without_duration(duckling):
    assert parse(duckling, "Stelle einen Timer").reason == "no duration"


# An existing timer as a request names it (what an intent hands on as
# "<what was said> Timer").
@pytest.mark.parametrize(
    ("text", "duration", "label"),
    [
        ("60 Minuten Timer", 3600, None),
        ("Eine Stunde Timer", 3600, None),
        ("eineinhalb Stunden Timer", 5400, None),
        ("3 5 Minuten Timer", 210, None),
        ("Nudel Timer", None, "Nudel"),
        ("Nudeltimer Timer", None, "Nudel"),
        ("Nudel-Timer", None, "Nudel"),
        ("Timer", None, None),
    ],
)
def test_describe_timer(duckling, text, duration, label):
    p = asyncio.run(de.describe_timer(text, duckling))
    assert (p.kind, p.reason, p.duration, p.label) == ("timer", None, duration, label)


@pytest.mark.parametrize(
    ("text", "start", "summary"),
    [
        ("Erinnere mich in 10 Minuten an die Nudeln", at(28, 14, 10), "die Nudeln"),
        ("Erinnere mich morgen um 9 an den Zahnarzt", at(29, 9), "den Zahnarzt"),
        ("Erinnere mich an den Zahnarzt morgen um 9", at(29, 9), "den Zahnarzt"),
        ("Erinnere mich übermorgen um 13:30 an die Wäsche", at(30, 13, 30), "die Wäsche"),
        # A day alone: at 9.
        ("Erinnere mich am Samstag an den Müll", at(31, 9), "den Müll"),
        # 12-hour clock: the next time it comes.
        ("Erinnere mich um 7 an das Essen", at(28, 19), "das Essen"),
        (
            "Erinnere mich daran, dass ich den Müll rausbringe, morgen um 7 Uhr 15",
            at(29, 7, 15),
            "ich den Müll rausbringe",
        ),
    ],
)
def test_reminder(duckling, text, start, summary):
    p = parse(duckling, text)
    assert (p.kind, p.reason, p.at, p.summary) == ("reminder", None, start, summary)


@pytest.mark.parametrize(
    ("text", "reason"),
    [
        ("Erinnere mich heute Abend an die Wäsche", "vague time"),
        ("Erinnere mich morgen um 9", "no summary"),
        ("Erinnere mich an die Wäsche", "no time"),
    ],
)
def test_reminder_not_enough(duckling, text, reason):
    assert parse(duckling, text).reason == reason


@pytest.mark.parametrize(
    ("text", "clock", "day", "days"),
    [
        ("Weck mich morgen um 6:30", time(6, 30), date(2026, 10, 29), []),
        ("Stelle einen Wecker auf 7 Uhr", time(7), date(2026, 10, 29), []),
        ("Wecker um 18 Uhr", time(18), date(2026, 10, 28), []),
        ("Weck mich um 12", time(12), date(2026, 10, 29), []),
        ("Stelle einen Wecker am 3. November um 7", time(7), date(2026, 11, 3), []),
        ("Stelle einen Wecker am 3 11 um 7", time(7), date(2026, 11, 3), []),
        ("Weck mich morgen um 6 30", time(6, 30), date(2026, 10, 29), []),
        ("Weck mich am Samstag um 9 Uhr", time(9), date(2026, 10, 31), []),
        ("Weck mich werktags um halb sieben", time(6, 30), None, ["werktags"]),
        ("6 Uhr morgens Wecker wochentags", time(6), None, ["werktags"]),
        ("Stelle einen Wecker für Montag bis Freitag um 6", time(6), None, ["werktags"]),
        ("Weck mich jeden Tag um 8", time(8), None, ["täglich"]),
        ("Weck mich jeden Montag um 7", time(7), None, ["montag"]),
        (
            "Weck mich montags und mittwochs um Viertel nach sieben",
            time(7, 15),
            None,
            ["montag", "mittwoch"],
        ),
        ("Stelle einen Wecker am Wochenende um 9", time(9), None, ["wochenende"]),
    ],
)
def test_alarm(duckling, text, clock, day, days):
    p = parse(duckling, text)
    assert (p.kind, p.reason, p.time, p.date, p.days) == ("alarm", None, clock, day, days)


# Existing alarms as a request names them.
@pytest.mark.parametrize(
    ("text", "clock", "day", "days"),
    [
        ("morgen um 5 Uhr früh", time(5), date(2026, 10, 29), []),
        ("um 7", time(7), date(2026, 10, 29), []),
        ("werktags um 12 Uhr mittags", time(12), None, ["werktags"]),
        ("für morgen", None, date(2026, 10, 29), []),
        ("am Samstag", None, date(2026, 10, 31), []),
        ("werktags", None, None, ["werktags"]),
    ],
)
def test_describe_alarm(duckling, text, clock, day, days):
    p = asyncio.run(de.describe_alarm(text, duckling))
    assert (p.kind, p.reason, p.time, p.date, p.days) == ("alarm", None, clock, day, days)


@pytest.mark.parametrize(
    ("text", "reason"),
    [
        ("Weck mich morgen früh", "vague time"),
        ("Weck mich morgen", "vague time"),
        ("Stelle einen Wecker", "no time"),
    ],
)
def test_alarm_not_enough(duckling, text, reason):
    assert parse(duckling, text).reason == reason


@pytest.mark.parametrize(
    ("text", "kind"),
    [
        ("Weck mich um 7", "alarm"),
        ("6 Uhr morgens Wecker", "alarm"),
        ("Erinnere mich an den Wecker", "reminder"),
        ("Nudeltimer auf 5 Minuten", "timer"),
        ("5 Minuten ab jetzt", "timer"),
        ("Wie spät ist es", None),
    ],
)
def test_kind(text, kind):
    assert de.kind_of(text) == kind


def test_kind_given_wins(duckling):
    p = parse(duckling, "Erinnere mich an den Wecker in 5 Minuten", "timer")
    assert (p.kind, p.duration) == ("timer", 300)


@pytest.mark.parametrize(
    ("said", "repaired"),
    [
        ("Timer auf 3 5 Minuten", "Timer auf 3,5 Minuten"),
        ("Wecker am 3 11 um 7", "Wecker am 3.11. um 7"),
        ("Weck mich um 6 30", "Weck mich um 6 30"),
        ("Timer auf 15 Minuten", "Timer auf 15 Minuten"),
    ],
)
def test_repair(said, repaired):
    assert de.repair(said) == repaired


def test_parser_for():
    assert parser_for("de") is parser_for("de-CH") is parser_for("de_DE") is de.parse
    assert parser_for("en") is None


@pytest.mark.parametrize(
    ("text", "duration", "at"),
    [
        ("10 Minuten", 600, None),
        ("in 10 Minuten", None, at(28, 14, 10)),
        ("morgen um 17 Uhr", None, at(29, 17)),
        ("eine halbe Stunde", 1800, None),
    ],
)
def test_describe_when(duckling, text, duration, at):
    p = asyncio.run(de.describe_when(text, duckling))
    assert (p.reason, p.duration, p.at) == (None, duration, at)


# Both orders, as the intents hand them on ("Erinnerung an … " arrives as
# "Erinnere mich an …").
@pytest.mark.parametrize(
    ("text", "start", "summary"),
    [
        (
            "Erinnere mich morgen um 10 Uhr vormittags an den Zahnarzt",
            at(29, 10),
            "den Zahnarzt",
        ),
        (
            "Erinnere mich an Blumen gießen am 17. April um 5 Uhr nachmittags",
            datetime(2027, 4, 17, 17, 0, tzinfo=ZoneInfo(TZ)),
            "Blumen gießen",
        ),
        ("Erinnere mich für den Zahnarzt morgen um 9", at(29, 9), "den Zahnarzt"),
    ],
)
def test_reminder_both_orders(duckling, text, start, summary):
    p = parse(duckling, text, "reminder")
    assert (p.reason, p.at, p.summary) == (None, start, summary)


@pytest.mark.parametrize(
    ("text", "start", "end"),
    [
        ("heute", at(28, 0), at(29, 0)),
        ("morgen", at(29, 0), at(30, 0)),
        (
            "Dienstag",
            datetime(2026, 11, 3, tzinfo=ZoneInfo(TZ)),
            datetime(2026, 11, 4, tzinfo=ZoneInfo(TZ)),
        ),
        # Duckling: the coming Saturday (said on a Wednesday).
        ("nächsten Samstag", at(31, 0), datetime(2026, 11, 1, tzinfo=ZoneInfo(TZ))),
        (
            "am 17. April",
            datetime(2027, 4, 17, tzinfo=ZoneInfo(TZ)),
            datetime(2027, 4, 18, tzinfo=ZoneInfo(TZ)),
        ),
        (
            "nächste Woche",
            datetime(2026, 11, 2, tzinfo=ZoneInfo(TZ)),
            datetime(2026, 11, 9, tzinfo=ZoneInfo(TZ)),
        ),
    ],
)
def test_describe_span(duckling, text, start, end):
    p = asyncio.run(de.describe_span(text, duckling))
    assert (p.reason, p.at, p.until) == (None, start, end)


@pytest.mark.parametrize(
    ("text", "summary", "start", "end"),
    [
        ("den Zahnarzt", "den Zahnarzt", None, None),
        ("morgen um 9", None, at(29, 9), None),
        ("den Zahnarzt morgen", "den Zahnarzt", at(29, 0), at(30, 0)),
    ],
)
def test_describe_reminder(duckling, text, summary, start, end):
    p = asyncio.run(de.describe_reminder(text, duckling))
    assert (p.reason, p.summary, p.at, p.until) == (None, summary, start, end)
