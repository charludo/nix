from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

import pytest

from remembrance.calendar_items import (
    new_event,
    next_occurrence,
    parse,
    plan,
    weekday_codes,
    with_exdate,
    with_status,
)

TZ = ZoneInfo("Europe/Berlin")
CATS = {"reminder": "HomeAssistant Reminder", "alarm": "HomeAssistant Alarm"}
NOW = datetime(2026, 10, 27, 12, 0, tzinfo=TZ)


def ics(body: str) -> str:
    return "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:test\r\n" + body + "END:VCALENDAR\r\n"


THUNDERBIRD = ics(
    "BEGIN:VEVENT\r\nUID:dentist\r\nSUMMARY:Zahnarzt\r\nLOCATION:Kueche\r\n"
    "CATEGORIES:HomeAssistant Reminder\r\n"
    "DTSTART;TZID=Europe/Berlin:20261031T130000\r\nDTEND;TZID=Europe/Berlin:20261031T140000\r\n"
    "BEGIN:VALARM\r\nACTION:DISPLAY\r\nTRIGGER:-PT30M\r\nDESCRIPTION:x\r\nEND:VALARM\r\n"
    "BEGIN:VALARM\r\nACTION:DISPLAY\r\nTRIGGER:-PT5M\r\nDESCRIPTION:x\r\nEND:VALARM\r\n"
    "END:VEVENT\r\n"
    "BEGIN:VEVENT\r\nUID:untagged\r\nSUMMARY:Party\r\n"
    "DTSTART;TZID=Europe/Berlin:20261031T200000\r\n"
    "BEGIN:VALARM\r\nACTION:DISPLAY\r\nTRIGGER:-PT1H\r\nDESCRIPTION:x\r\nEND:VALARM\r\n"
    "END:VEVENT\r\n"
)


def test_parse_only_tagged():
    [entry] = parse(THUNDERBIRD, CATS, TZ, href="/cal/a.ics")
    assert (entry.uid, entry.kind, entry.summary, entry.location) == (
        "dentist",
        "reminder",
        "Zahnarzt",
        "Kueche",
    )
    assert entry.alerts == [1800, 300]
    assert not entry.recurring and not entry.cancelled
    assert entry.href == "/cal/a.ics"


def test_category_among_others_and_case():
    body = THUNDERBIRD.replace(
        "CATEGORIES:HomeAssistant Reminder", "CATEGORIES:Arbeit,homeassistant reminder"
    )
    assert [e.kind for e in parse(body, CATS, TZ)] == ["reminder"]


def test_plan_rings_at_each_reminder_only():
    [entry] = parse(THUNDERBIRD, CATS, TZ)
    rings = plan(entry, NOW, NOW + timedelta(days=7), TZ)
    assert [(r.at.strftime("%d. %H:%M"), r.offset) for r in rings] == [
        ("31. 12:30", 1800),
        ("31. 12:55", 300),
    ]
    assert len({r.key for r in rings}) == 2


def test_no_valarm_no_ring():
    body = THUNDERBIRD.replace(
        "BEGIN:VALARM\r\nACTION:DISPLAY\r\nTRIGGER:-PT30M\r\nDESCRIPTION:x\r\nEND:VALARM\r\n", ""
    ).replace(
        "BEGIN:VALARM\r\nACTION:DISPLAY\r\nTRIGGER:-PT5M\r\nDESCRIPTION:x\r\nEND:VALARM\r\n", ""
    )
    [entry] = parse(body, CATS, TZ)
    assert entry.alerts == []
    assert plan(entry, NOW, NOW + timedelta(days=7), TZ) == []


WEEKLY_ALARM = ics(
    "BEGIN:VEVENT\r\nUID:wake\r\nSUMMARY:Wecker\r\nCATEGORIES:HomeAssistant Alarm\r\n"
    "DTSTART;TZID=Europe/Berlin:20261026T070000\r\nDTEND;TZID=Europe/Berlin:20261026T070500\r\n"
    "RRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR\r\n"
    "EXDATE;TZID=Europe/Berlin:20261029T070000\r\n"
    "BEGIN:VALARM\r\nACTION:DISPLAY\r\nTRIGGER:PT0S\r\nDESCRIPTION:x\r\nEND:VALARM\r\n"
    "END:VEVENT\r\n"
    "BEGIN:VEVENT\r\nUID:wake\r\nRECURRENCE-ID;TZID=Europe/Berlin:20261030T070000\r\n"
    "SUMMARY:Wecker\r\nDTSTART;TZID=Europe/Berlin:20261030T083000\r\n"
    "DTEND;TZID=Europe/Berlin:20261030T083500\r\n"
    "BEGIN:VALARM\r\nACTION:DISPLAY\r\nTRIGGER:PT0S\r\nDESCRIPTION:x\r\nEND:VALARM\r\n"
    "END:VEVENT\r\n"
)


def test_recurring_with_exdate_and_moved_occurrence():
    [entry] = parse(WEEKLY_ALARM, CATS, TZ)
    assert entry.kind == "alarm" and entry.recurring
    rings = plan(entry, NOW, NOW + timedelta(days=7), TZ)
    # Tue 27 is past (12:00 now); Wed 28; Thu 29 excluded; Fri 30 moved to
    # 8:30; weekend none; Mon 2 and Tue 3 (last day of the window).
    assert [r.at.strftime("%a %d. %H:%M") for r in rings] == [
        "Wed 28. 07:00",
        "Fri 30. 08:30",
        "Mon 02. 07:00",
        "Tue 03. 07:00",
    ]
    assert all(r.offset == 0 for r in rings)


def test_next_occurrence():
    [entry] = parse(WEEKLY_ALARM, CATS, TZ)
    assert next_occurrence(entry, NOW, TZ) == datetime(2026, 10, 28, 7, 0, tzinfo=TZ)


def test_all_day_reminder_rings_relative_to_local_midnight():
    body = ics(
        "BEGIN:VEVENT\r\nUID:bin\r\nSUMMARY:Müll\r\nCATEGORIES:HomeAssistant Reminder\r\n"
        "DTSTART;VALUE=DATE:20261029\r\nDTEND;VALUE=DATE:20261030\r\n"
        "BEGIN:VALARM\r\nACTION:DISPLAY\r\nTRIGGER:-PT3H\r\nDESCRIPTION:x\r\nEND:VALARM\r\n"
        "END:VEVENT\r\n"
    )
    [entry] = parse(body, CATS, TZ)
    [ring] = plan(entry, NOW, NOW + timedelta(days=7), TZ)
    assert ring.at == datetime(2026, 10, 28, 21, 0, tzinfo=TZ)


def test_absolute_and_end_related_triggers():
    body = ics(
        "BEGIN:VEVENT\r\nUID:x\r\nSUMMARY:Film\r\nCATEGORIES:HomeAssistant Reminder\r\n"
        "DTSTART;TZID=Europe/Berlin:20261031T200000\r\nDTEND;TZID=Europe/Berlin:20261031T220000\r\n"
        "BEGIN:VALARM\r\nACTION:DISPLAY\r\nTRIGGER;VALUE=DATE-TIME:20261031T180000Z\r\n"
        "DESCRIPTION:x\r\nEND:VALARM\r\n"
        "BEGIN:VALARM\r\nACTION:DISPLAY\r\nTRIGGER;RELATED=END:-PT10M\r\nDESCRIPTION:x\r\n"
        "END:VALARM\r\n"
        "END:VEVENT\r\n"
    )
    [entry] = parse(body, CATS, TZ)
    # 18:00Z is 19:00 local, an hour before; end-related: 21:50, after the start.
    assert entry.alerts == [3600, -6600]
    rings = plan(entry, NOW, NOW + timedelta(days=7), TZ)
    assert [r.at.strftime("%H:%M") for r in rings] == ["19:00", "21:50"]


def test_new_reminder_roundtrip():
    start = datetime(2026, 10, 31, 13, 0, tzinfo=TZ)
    uid, text = new_event(
        category="HomeAssistant Reminder",
        summary="Blumen gießen",
        start=start,
        duration=timedelta(minutes=15),
        alerts=[0, 600],
        location="Wohnzimmer",
        description="Musik: Morgenrunde",
        now=NOW,
    )
    [entry] = parse(text, CATS, TZ)
    assert (entry.uid, entry.summary, entry.location) == (uid, "Blumen gießen", "Wohnzimmer")
    assert entry.description == "Musik: Morgenrunde"
    assert entry.start == start
    assert entry.alerts == [600, 0]
    assert "BEGIN:VTIMEZONE" in text


def test_new_alarm_weekdays_and_daily():
    start = datetime(2026, 10, 28, 6, 30, tzinfo=TZ)
    _, text = new_event(
        category="HomeAssistant Alarm",
        summary="Wecker",
        start=start,
        duration=timedelta(minutes=5),
        alerts=[0],
        byday=["FR", "MO"],
        now=NOW,
    )
    assert "RRULE:FREQ=WEEKLY;BYDAY=MO,FR" in text
    [entry] = parse(text, CATS, TZ)
    assert [r.at.strftime("%a %H:%M") for r in plan(entry, NOW, NOW + timedelta(days=7), TZ)] == [
        "Fri 06:30",
        "Mon 06:30",
    ]
    _, daily = new_event(
        category="HomeAssistant Alarm",
        summary="Wecker",
        start=start,
        duration=timedelta(minutes=5),
        alerts=[0],
        byday=weekday_codes(["daily"]),
        now=NOW,
    )
    assert "RRULE:FREQ=DAILY" in daily


def test_skip_occurrence_and_disable():
    [entry] = parse(WEEKLY_ALARM, CATS, TZ)
    skipped = with_exdate(entry, datetime(2026, 10, 28, 7, 0, tzinfo=TZ))
    [entry2] = parse(skipped, CATS, TZ)
    assert next_occurrence(entry2, NOW, TZ) == datetime(2026, 10, 30, 8, 30, tzinfo=TZ)

    disabled = with_status(entry2, cancelled=True)
    [off] = parse(disabled, CATS, TZ)
    assert off.cancelled
    assert plan(off, NOW, NOW + timedelta(days=7), TZ) == []
    assert next_occurrence(off, NOW, TZ) is None
    [on] = parse(with_status(off, cancelled=False), CATS, TZ)
    assert not on.cancelled and plan(on, NOW, NOW + timedelta(days=7), TZ)


@pytest.mark.parametrize(
    ("days", "codes"),
    [
        (["werktags"], ["MO", "TU", "WE", "TH", "FR"]),
        (["Montag", "freitags"], ["MO", "FR"]),
        (["sat", "SU"], ["SA", "SU"]),
        (["daily"], ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]),
    ],
)
def test_weekday_codes(days, codes):
    assert weekday_codes(days) == codes


def test_weekday_codes_unknown():
    with pytest.raises(ValueError):
        weekday_codes(["Feiertag"])
