"""Timers, reminders and alarms from sentences, through a real Duckling (and
Radicale for the calendar)."""

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
        hass, "create_from_text", text="Weck mich werktags um halb sieben mit Musik", area="bad"
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
