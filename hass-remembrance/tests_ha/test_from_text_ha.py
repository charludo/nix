"""Timers, reminders and alarms from sentences, through a real Duckling (and
Radicale for the calendar)."""

import asyncio
from datetime import timedelta

import pytest
from conftest import setup
from homeassistant.util import dt as dt_util
from test_calendar_ha import call, start


@pytest.fixture(autouse=True)
def german(hass):
    # Sentences are in Home Assistant's language unless `language` is given.
    hass.config.language = "de"


async def test_timer_from_sentence(hass, duckling):
    await setup(hass, {"duckling_url": duckling.url})
    res = await call(
        hass, "create_from_text", text="Stelle einen Nudeltimer auf anderthalb Minuten"
    )
    assert res["status"] == "ok"
    item = res["items"][0]
    assert (item["label"], item["duration"]) == ("Nudel", 90)
    assert res["parsed"] == {"kind": "timer", "duration": 90.0, "label": "Nudel"}


async def test_alarm_repeating_with_music(hass, radicale, duckling):
    await start(hass, radicale, duckling_url=duckling.url)
    res = await call(
        hass,
        "create_from_text",
        text="Weck mich werktags um halb sieben",
        area="bad",
        description="Sanft\nMusik",
    )
    assert res["status"] == "ok", res
    item = res["items"][0]
    assert item["recurring"]
    start_at = dt_util.as_local(dt_util.parse_datetime(item["start"]))
    assert (start_at.hour, start_at.minute) == (6, 30)
    assert start_at.weekday() < 5
    assert item["description"] == "Sanft\nMusik"
    assert res["parsed"]["days"] == ["werktags"]
    [ics] = radicale.events()
    assert "RRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR" in ics


async def test_reminder_in_minutes(hass, radicale, duckling):
    await start(hass, radicale, duckling_url=duckling.url)
    before = dt_util.now()
    res = await call(hass, "create_from_text", text="Erinnere mich in 10 Minuten an die Wäsche")
    assert res["status"] == "ok", res
    item = res["items"][0]
    assert item["label"] == "die Wäsche"
    begins = dt_util.parse_datetime(item["start"])
    assert timedelta(minutes=9) < begins - before < timedelta(minutes=11)


async def test_kind_given_and_parse_only(hass, duckling):
    await setup(hass, {"duckling_url": duckling.url})
    res = await call(hass, "parse", text="auf 5 Minuten", kind="timer")
    assert res == {"status": "ok", "items": [], "parsed": {"kind": "timer", "duration": 300.0}}
    assert not (await call(hass, "query"))["items"]


async def test_not_understood(hass, duckling):
    await setup(hass, {"duckling_url": duckling.url})
    vague = await call(hass, "create_from_text", text="Weck mich morgen früh")
    assert (vague["status"], vague["reason"]) == ("invalid", "vague time")
    unknown = await call(hass, "create_from_text", text="Wie spät ist es")
    assert (unknown["status"], unknown["reason"]) == ("invalid", "unknown kind")


async def test_without_duckling_or_parser(hass):
    await setup(hass, {})
    res = await call(hass, "create_from_text", text="Timer auf 5 Minuten")
    assert (res["status"], res["reason"]) == ("invalid", "no duckling configured")
    res = await call(hass, "parse", text="Timer for 5 minutes", language="en")
    assert (res["status"], res["reason"]) == ("invalid", "no parser for en")


async def test_timer_named_by_text(hass, duckling):
    """A timer named as said: by its set duration in any words Duckling reads,
    or its label; extending it doesn't rename it."""
    await setup(hass, {"duckling_url": duckling.url})
    for text in ("Timer auf 10 Minuten", "Timer auf 60 Minuten", "Nudel Timer auf 5 Minuten"):
        assert (await call(hass, "create_from_text", text=text))["status"] == "ok"
    ten = await call(hass, "timer_adjust", text="10 Minuten Timer", delta=600)
    assert ten["status"] == "ok", ten
    # Now 20 minutes long, but still "the 10-minute timer".
    renamed = await call(hass, "query", kind="timer", text="20 Minuten Timer")
    assert renamed["items"] == []
    res = await call(hass, "query", kind="timer", text="10 Minuten Timer")
    assert [t["duration"] for t in res["items"]] == [600]
    res = await call(hass, "timer_cancel", text="Eine Stunde Timer")
    assert (res["status"], res["items"][0]["duration"]) == ("ok", 3600)
    res = await call(hass, "timer_cancel", text="Nudeltimer Timer")
    assert (res["status"], res["items"][0]["label"]) == ("ok", "Nudel")
    # Said nothing: the only one left.
    res = await call(hass, "timer_cancel", text="Timer")
    assert (res["status"], res["items"][0]["duration"]) == ("ok", 600)


async def test_adjust_by_text(hass, duckling):
    await setup(hass, {"duckling_url": duckling.url})
    await call(hass, "create_from_text", text="Nudel Timer auf 10 Minuten")
    res = await call(hass, "timer_adjust", text="Nudel Timer", delta_text="eine halbe Stunde")
    assert (res["status"], res["parsed"]) == ("ok", {"delta": 1800})
    res = await call(hass, "timer_adjust", text="Timer", delta_text="5 Minuten", shorten=True)
    assert (res["status"], res["parsed"]) == ("ok", {"delta": -300})
    [t] = (await call(hass, "query", kind="timer"))["items"]
    assert (t["duration"], t["extended"]) == (600, 1500)
    res = await call(hass, "timer_adjust", text="Timer", delta_text="ein bisschen")
    assert (res["status"], res["reason"]) == ("invalid", "no duration")


async def test_alarm_delete_from_text(hass, radicale, duckling):
    await start(hass, radicale, duckling_url=duckling.url)
    tomorrow = (dt_util.now() + timedelta(days=1)).date()
    await call(hass, "alarm_create", time="07:00", days=["daily"])
    await call(hass, "alarm_create", time="06:00", date=tomorrow.isoformat())
    await call(hass, "alarm_create", time="08:00", date=tomorrow.isoformat())

    # One occurrence of a one-off alarm: gone.
    res = await call(hass, "alarm_delete_from_text", text="morgen um 6 Uhr")
    assert (res["status"], len(radicale.events())) == ("ok", 2), res
    # One occurrence of a repeating alarm: just that day left out.
    res = await call(hass, "alarm_delete_from_text", text="morgen um 7")
    assert res["status"] == "ok", res
    assert any("EXDATE" in s and "RRULE" in s for s in radicale.events())
    # A whole day only with "alle": tomorrow's 8:00 (the daily one already
    # skips it).
    res = await call(hass, "alarm_delete_from_text", text="für morgen")
    assert (res["status"], res["reason"], len(radicale.events())) == ("invalid", "no time", 2)
    res = await call(hass, "alarm_delete_from_text", text="für morgen", all=True)
    assert res["status"] == "ok", res
    assert len(radicale.events()) == 1
    # A repeat said: the repeating alarm itself.
    res = await call(hass, "alarm_delete_from_text", text="jeden Tag um 7 Uhr")
    assert (res["status"], radicale.events()) == ("ok", []), res


async def test_alarm_delete_repeat_matches_its_days(hass, radicale, duckling):
    await start(hass, radicale, duckling_url=duckling.url)
    await call(hass, "alarm_create", time="07:00", days=["werktags"])
    await call(hass, "alarm_create", time="07:00", days=["wochenende"])
    await call(hass, "alarm_create", time="07:00", days=["werktags"], label="Zweiter")
    res = await call(hass, "alarm_delete_from_text", text="werktags um 7")
    # Both weekday alarms at 7, the weekend one stays.
    assert (res["status"], len(res["items"])) == ("ok", 2), res
    [left] = radicale.events()
    assert "BYDAY=SA,SU" in left
    res = await call(hass, "alarm_delete_from_text", text="werktags um 7")
    assert res["status"] == "no_match"


async def test_snooze_by_kind_and_text(hass, duckling):
    await setup(
        hass, {"duckling_url": duckling.url, "ring": {"timer": {"interval": 1, "limit": 2}}}
    )
    await call(hass, "timer_start", duration=1)
    await asyncio.sleep(1.4)
    await hass.async_block_till_done()
    # A ringing timer is not an alarm or reminder: nothing to snooze.
    res = await call(hass, "snooze", kind="alarm", delay_text="10 Minuten")
    assert res["status"] == "no_match"
    before = dt_util.now()
    res = await call(hass, "snooze", kind="timer", delay_text="in 10 Minuten")
    assert res["status"] == "ok", res
    again = dt_util.parse_datetime(res["parsed"]["at"])
    assert timedelta(minutes=9) < again - before < timedelta(minutes=11)
    res = await call(hass, "snooze", delay_text="gestern um 7")
    assert res["status"] in ("invalid", "no_match")


async def test_reminders_by_text(hass, radicale, duckling):
    await start(hass, radicale, duckling_url=duckling.url)
    for text in (
        "Erinnere mich morgen um 9 an den Zahnarzt",
        "Erinnere mich an den Müll morgen um 10",
        "Erinnere mich übermorgen um 9 an den Zahnarzt",
    ):
        assert (await call(hass, "create_from_text", text=text))["status"] == "ok"

    res = await call(hass, "query", kind="reminder", when_text="morgen")
    assert sorted(i["label"] for i in res["items"]) == ["den Müll", "den Zahnarzt"], res

    res = await call(hass, "reminder_delete_from_text", text="den Zahnarzt")
    assert (res["status"], len(res["candidates"])) == ("ambiguous", 2)
    res = await call(hass, "reminder_delete_from_text", text="den Zahnarzt morgen")
    assert res["status"] == "ok", res
    res = await call(hass, "reminder_delete_from_text", text="übermorgen um 9")
    assert res["status"] == "ok", res
    res = await call(hass, "reminder_delete_from_text", text="Müll")
    assert res["status"] == "ok", res
    assert radicale.events() == []
