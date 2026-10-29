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
    ("text", "clock", "day", "days", "description"),
    [
        ("Weck mich morgen um 6:30", time(6, 30), date(2026, 10, 29), [], "Sanft"),
        ("Stelle einen Wecker auf 7 Uhr", time(7), date(2026, 10, 29), [], None),
        ("Wecker um 18 Uhr", time(18), date(2026, 10, 28), [], None),
        ("Weck mich um 12", time(12), date(2026, 10, 29), [], "Sanft"),
        ("Stelle einen Wecker am 3. November um 7", time(7), date(2026, 11, 3), [], None),
        ("Stelle einen Wecker am 3 11 um 7", time(7), date(2026, 11, 3), [], None),
        ("Weck mich morgen um 6 30", time(6, 30), date(2026, 10, 29), [], "Sanft"),
        ("Weck mich sanft am Samstag um 9 Uhr", time(9), date(2026, 10, 31), [], "Sanft"),
        (
            "Weck mich werktags um halb sieben mit Musik",
            time(6, 30),
            None,
            ["werktags"],
            "Sanft\nMusik",
        ),
        ("6 Uhr morgens Wecker wochentags", time(6), None, ["werktags"], None),
        ("Stelle einen Wecker für Montag bis Freitag um 6", time(6), None, ["werktags"], None),
        ("Weck mich jeden Tag um 8", time(8), None, ["täglich"], "Sanft"),
        ("Weck mich jeden Montag um 7", time(7), None, ["montag"], "Sanft"),
        (
            "Weck mich montags und mittwochs um Viertel nach sieben",
            time(7, 15),
            None,
            ["montag", "mittwoch"],
            "Sanft",
        ),
        (
            "Stelle einen Wecker am Wochenende um 9 mit der Playlist Guten Morgen",
            time(9),
            None,
            ["wochenende"],
            "Musik: Guten Morgen",
        ),
    ],
)
def test_alarm(duckling, text, clock, day, days, description):
    p = parse(duckling, text)
    assert (p.kind, p.reason, p.time, p.date, p.days, p.description) == (
        "alarm",
        None,
        clock,
        day,
        days,
        description,
    )


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
