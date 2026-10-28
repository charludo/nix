"""Reminders and alarms through the public API, against a real Radicale."""

import asyncio
from datetime import datetime, timedelta

from conftest import setup
from homeassistant.helpers import area_registry as ar
from homeassistant.helpers import entity_registry as er
from homeassistant.util import dt as dt_util

FAST = {
    "ring": {
        "reminder": {"interval": 1, "limit": 0},
        "alarm": {"interval": 1, "limit": 2},
    }
}


async def call(hass, service, **data):
    return await hass.services.async_call(
        "remembrance", service, data, blocking=True, return_response=True
    )


def events(hass, name):
    seen = []
    hass.bus.async_listen(f"remembrance_{name}", lambda e: seen.append(e.data))
    return seen


async def start(hass, radicale, **extra):
    await setup(hass, {**FAST, **extra, "calendar": radicale.config()})
    engine = hass.data["remembrance"]
    # The first sync runs in the background; wait for it.
    for _ in range(100):
        if engine.calendar.online:
            break
        await asyncio.sleep(0.05)
    assert engine.calendar.online
    return engine


def ical_time(t: datetime) -> str:
    return t.astimezone(dt_util.UTC).strftime("%Y%m%dT%H%M%SZ")


def external_event(uid, summary, start, *, alarms=(), rooms=(), location=None, tagged=True) -> str:
    lines = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "PRODID:-//Mozilla.org/NONSGML Mozilla Calendar V1.1//EN",
        "BEGIN:VEVENT",
        f"UID:{uid}",
        f"SUMMARY:{summary}",
        f"DTSTART:{ical_time(start)}",
        f"DTEND:{ical_time(start + timedelta(hours=1))}",
    ]
    if tagged:
        lines.append(",".join(["CATEGORIES:HomeAssistant Reminder", *rooms]))
    if location:
        lines.append(f"LOCATION:{location}")
    for trigger in alarms:
        lines += [
            "BEGIN:VALARM",
            "ACTION:DISPLAY",
            f"TRIGGER:{trigger}",
            "DESCRIPTION:x",
            "END:VALARM",
        ]
    lines += ["END:VEVENT", "END:VCALENDAR"]
    return "\r\n".join(lines) + "\r\n"


async def test_reminder_create_written_and_rings(hass, radicale):
    ar.async_get(hass).async_create("Küche")
    await start(hass, radicale)
    ringing = events(hass, "ringing")
    dismissed = events(hass, "dismissed")

    made = await call(hass, "reminder_create", summary="Tee", **{"in": 2}, area="kuche")
    assert made["status"] == "ok"
    item = made["items"][0]
    assert (item["kind"], item["label"], item["areas"], item["location"]) == (
        "reminder",
        "Tee",
        ["kuche"],
        None,
    )
    [stored] = radicale.events()
    assert "CATEGORIES:HomeAssistant Reminder,Küche" in stored
    assert "LOCATION" not in stored
    assert "TRIGGER:PT0S" in stored

    await asyncio.sleep(2.6)
    await hass.async_block_till_done()
    assert [(e["label"], e["offset"], e["next_offset"], e["round"]) for e in ringing] == [
        ("Tee", 0, None, 1)
    ]
    assert [e["reason"] for e in dismissed] == ["timeout"]


async def test_external_event_rings_at_each_reminder(hass, radicale):
    ar.async_get(hass).async_create("Küche")
    engine = await start(hass, radicale)
    ringing = events(hass, "ringing")
    begins = dt_util.now().replace(microsecond=0) + timedelta(seconds=6)
    radicale.put(
        external_event("dentist", "Zahnarzt", begins, alarms=["-PT4S", "PT0S"], rooms=["kueche"])
    )
    await engine.calendar.async_sync()

    [item] = (await call(hass, "query", kind="reminder"))["items"]
    assert (item["label"], item["areas"], item["alerts"]) == ("Zahnarzt", ["kuche"], [4.0, 0.0])

    await asyncio.sleep(6.6)
    await hass.async_block_till_done()
    assert [(e["offset"], e["next_offset"]) for e in ringing] == [(4.0, 0.0), (0.0, None)]


async def test_rooms_from_categories_ring_each(hass, radicale):
    from homeassistant.setup import async_setup_component

    areas = ar.async_get(hass)
    areas.async_create("Küche")
    areas.async_create("Bad", aliases={"Badezimmer"})
    assert await async_setup_component(
        hass,
        "script",
        {
            "script": {
                "ring": {
                    "mode": "parallel",
                    "sequence": [{"event": "rang", "event_data": {"areas": "{{ areas }}"}}],
                }
            }
        },
    )
    rang = []
    hass.bus.async_listen("rang", lambda e: rang.append(e.data["areas"]))
    engine = await start(hass, radicale, ring_script="script.ring")
    begins = dt_util.now().replace(microsecond=0) + timedelta(seconds=3)
    radicale.put(
        external_event(
            "dentist",
            "Zahnarzt",
            begins,
            alarms=["PT0S"],
            # Exact names or aliases only; other categories are left alone.
            rooms=["küche", "Badezimmer", "Arbeit", "Kueche"],
            location="Hauptstraße 5",
        )
    )
    await engine.calendar.async_sync()
    [item] = (await call(hass, "query", kind="reminder"))["items"]
    assert (item["areas"], item["location"]) == (["kuche", "bad"], "Hauptstraße 5")

    await asyncio.sleep(3.6)
    await hass.async_block_till_done()
    # One call per round, with all its rooms.
    assert rang == [["kuche", "bad"]]


async def test_untagged_ignored_tagged_without_reminder_silent(hass, radicale):
    engine = await start(hass, radicale)
    soon = dt_util.now() + timedelta(hours=1)
    radicale.put(external_event("party", "Party", soon, alarms=["-PT10M"], tagged=False))
    radicale.put(external_event("quiet", "Still", soon))
    await engine.calendar.async_sync()
    [item] = (await call(hass, "query"))["items"]
    assert item["label"] == "Still"
    assert item["next_ring"] is None


async def test_alarm_recurring_skip_disable_enable(hass, radicale):
    await start(hass, radicale)
    made = await call(
        hass, "alarm_create", time="07:00", days=["werktags"], description="Musik: Morgenrunde"
    )
    assert made["status"] == "ok"
    alarm = made["items"][0]
    assert alarm["description"] == "Musik: Morgenrunde"
    assert alarm["recurring"] and alarm["enabled"]
    [stored] = radicale.events()
    assert "RRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR" in stored
    assert "DESCRIPTION:Musik: Morgenrunde" in stored
    await hass.async_block_till_done()

    switch_id = er.async_get(hass).async_get_entity_id(
        "switch", "remembrance", f"alarm_{alarm['id']}"
    )
    assert hass.states.get(switch_id).state == "on"
    first = datetime.fromisoformat(hass.states.get("sensor.remembrance_next_alarm").state)
    assert first.astimezone(dt_util.get_default_time_zone()).strftime("%H:%M") == "07:00"
    assert first.astimezone(dt_util.get_default_time_zone()).weekday() < 5

    skipped = await call(hass, "alarm_skip")
    assert skipped["status"] == "ok"
    assert "EXDATE" in radicale.events()[0]
    await hass.async_block_till_done()
    second = datetime.fromisoformat(hass.states.get("sensor.remembrance_next_alarm").state)
    assert second > first

    await hass.services.async_call("switch", "turn_off", {"entity_id": switch_id}, blocking=True)
    await hass.async_block_till_done()
    assert "STATUS:CANCELLED" in radicale.events()[0]
    assert hass.states.get(switch_id).state == "off"
    assert hass.states.get("sensor.remembrance_next_alarm").state == "unknown"

    enabled = await call(hass, "alarm_enable")
    assert enabled["status"] == "ok"
    await hass.async_block_till_done()
    assert "STATUS:CANCELLED" not in radicale.events()[0]
    assert hass.states.get(switch_id).state == "on"


async def test_one_off_alarm_and_query_window(hass, radicale):
    await start(hass, radicale)
    tomorrow = (dt_util.now() + timedelta(days=1)).date()
    made = await call(hass, "alarm_create", time="06:30", date=tomorrow.isoformat())
    assert not made["items"][0]["recurring"]
    day = f"{tomorrow.isoformat()}T00:00:00"
    found = (await call(hass, "query", kind="alarm", **{"from": day}))["items"]
    assert [i["start"][11:16] for i in found] == ["06:30"]
    # Skipping a one-off alarm deletes it.
    assert (await call(hass, "alarm_skip"))["status"] == "ok"
    assert radicale.events() == []


async def test_query_kind_without_target(hass, radicale):
    await start(hass, radicale)
    await call(hass, "alarm_create", time="06:30", days=["daily"])
    await call(hass, "reminder_create", summary="Tee", **{"in": 3600})
    assert [i["kind"] for i in (await call(hass, "query", kind="alarm"))["items"]] == ["alarm"]
    assert len((await call(hass, "query"))["items"]) == 2


async def test_ring_alarm_and_snooze(hass, radicale):
    engine = await start(hass, radicale)
    ringing = events(hass, "ringing")
    snoozed = events(hass, "snoozed")
    # alarm_create works in whole minutes, too slow for a test: put the
    # event in directly, two seconds out.
    soon = dt_util.now().replace(microsecond=0) + timedelta(seconds=2)
    radicale.put(
        external_event("wake", "Wecker", soon, alarms=["PT0S"])
        .replace("HomeAssistant Reminder", "HomeAssistant Alarm")
        .replace("SUMMARY:Wecker", "SUMMARY:Wecker\r\nDESCRIPTION:Musik: Jazz")
    )
    await engine.calendar.async_sync()
    await asyncio.sleep(2.5)
    await hass.async_block_till_done()
    assert ringing and ringing[0]["kind"] == "alarm"
    assert ringing[0]["description"] == "Musik: Jazz"
    assert hass.states.get("binary_sensor.remembrance_ringing").state == "on"

    done = await call(hass, "snooze", delay=1)
    assert done["status"] == "ok"
    await hass.async_block_till_done()
    assert snoozed and snoozed[0]["id"] == "wake"
    assert hass.states.get("binary_sensor.remembrance_ringing").state == "off"
    before = len(ringing)
    await asyncio.sleep(1.5)
    await hass.async_block_till_done()
    assert len(ringing) > before
    assert ringing[before]["kind"] == "alarm" and ringing[before]["round"] == 1

    assert (await call(hass, "dismiss"))["status"] == "ok"
    assert hass.states.get("binary_sensor.remembrance_ringing").state == "off"


async def test_works_offline_from_cache(hass, radicale):
    engine = await start(hass, radicale)
    ringing = events(hass, "ringing")
    await call(hass, "reminder_create", summary="Ofen aus", **{"in": 3})
    radicale.stop()
    assert await engine.calendar.async_sync() is False
    await asyncio.sleep(3.5)
    await hass.async_block_till_done()
    assert [e["label"] for e in ringing] == ["Ofen aus"]


async def test_ambiguous_delete_asks_back(hass, radicale):
    await start(hass, radicale)
    await call(hass, "reminder_create", summary="Müll rausbringen", **{"in": 3600})
    await call(hass, "reminder_create", summary="Müll reinholen", **{"in": 7200})
    # Both are equally close to "Müll": nothing is deleted.
    response = await call(hass, "reminder_delete", label="Müll")
    assert response["status"] in ("ambiguous", "no_match")
    assert len(radicale.events()) == 2
    done = await call(hass, "reminder_delete", label="Müll reinholen")
    assert done["status"] == "ok"
    assert len(radicale.events()) == 1


async def test_without_calendar_services_say_so(hass):
    await setup(hass, {})
    response = await call(hass, "reminder_create", summary="x", **{"in": 60})
    assert (response["status"], response["reason"]) == ("invalid", "no calendar configured")


async def test_calendar_entity_lists_tagged_occurrences(hass, radicale):
    engine = await start(hass, radicale)
    soon = dt_util.now() + timedelta(hours=2)
    radicale.put(external_event("a", "Zahnarzt", soon, alarms=["-PT10M"]))
    radicale.put(external_event("b", "Party", soon, alarms=["-PT10M"], tagged=False))
    await engine.calendar.async_sync()
    await hass.async_block_till_done()
    state = hass.states.get("calendar.remembrance")
    assert state is not None
    assert state.attributes["message"] == "Zahnarzt"
    found = await hass.services.async_call(
        "calendar",
        "get_events",
        {"entity_id": "calendar.remembrance", "duration": {"hours": 24}},
        blocking=True,
        return_response=True,
    )
    [event] = found["calendar.remembrance"]["events"]
    assert event["summary"] == "Zahnarzt"
    # As long as in the calendar (an hour), not a fixed minute.
    length = datetime.fromisoformat(event["end"]) - datetime.fromisoformat(event["start"])
    assert length == timedelta(hours=1)


async def test_skip_a_day_for_all_alarms(hass, radicale):
    await start(hass, radicale)
    today = dt_util.now().date()
    tomorrow = today + timedelta(days=1)
    day_after = today + timedelta(days=2)
    await call(hass, "alarm_create", time="07:00", days=["daily"])
    await call(hass, "alarm_create", time="06:00", date=tomorrow.isoformat())
    await call(hass, "alarm_create", time="08:00", date=day_after.isoformat())

    done = await call(hass, "alarm_skip", all=True, date=tomorrow.isoformat())
    assert done["status"] == "ok"
    # The daily one skips tomorrow, tomorrow's one-off is gone, the one-off
    # on the day after is left alone.
    assert len(done["items"]) == 2
    stored = radicale.events()
    assert len(stored) == 2
    assert any("EXDATE" in s and "RRULE" in s for s in stored)
    assert any(day_after.strftime("%Y%m%d") in s for s in stored)

    nothing = await call(hass, "alarm_skip", all=True, date=tomorrow.isoformat())
    assert nothing["status"] == "no_match"


async def test_alarm_create_empty_days_is_one_off(hass, radicale):
    # As the voice intents call it: empty `days` and `date` mean "not given".
    await start(hass, radicale)
    made = await call(hass, "alarm_create", time="06:30", days=[], date="")
    assert made["status"] == "ok"
    assert not made["items"][0]["recurring"]
    repeating = await call(hass, "alarm_create", time="07:00", days=["werktags"], date="")
    assert repeating["items"][0]["recurring"]
