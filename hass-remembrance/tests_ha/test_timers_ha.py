"""Timers through the public API only: services, entities, events."""

import asyncio

import pytest
from conftest import setup, start_hass
from homeassistant.exceptions import ServiceValidationError

FAST_RING = {"ring": {"timer": {"interval": 1, "limit": 2}}}


async def call(hass, service, **data):
    return await hass.services.async_call(
        "remembrance", service, data, blocking=True, return_response=True
    )


def events(hass, name):
    seen = []
    hass.bus.async_listen(f"remembrance_{name}", lambda e: seen.append(e.data))
    return seen


async def test_start_query_and_entity(hass):
    await setup(hass, {})
    started = await call(hass, "timer_start", duration={"minutes": 5}, label="Nudel-Timer")
    assert started["status"] == "ok"
    item = started["items"][0]
    assert (item["label"], item["duration"], item["state"]) == ("Nudel", 300, "running")

    await hass.async_block_till_done()
    state = hass.states.get(f"sensor.remembrance_timer_{item['id']}")
    assert state is not None
    assert state.attributes["label"] == "Nudel"
    assert state.state.startswith(item["ends_at"][:16])

    listed = await call(hass, "query")
    assert [i["id"] for i in listed["items"]] == [item["id"]]


async def test_adjust_by_set_duration_and_ambiguity(hass):
    await setup(hass, {})
    five = (await call(hass, "timer_start", duration=300, area="kueche"))["items"][0]
    await call(hass, "timer_start", duration=600)

    done = await call(hass, "timer_adjust", duration={"minutes": 5}, delta=60)
    assert done["status"] == "ok"
    assert done["items"][0]["id"] == five["id"]
    assert done["items"][0]["remaining"] > 300

    # Two 5-minute timers: ambiguous, nothing changes.
    await call(hass, "timer_start", duration=300, area="wohnzimmer")
    before = (await call(hass, "query", duration=300))["items"]
    ambiguous = await call(hass, "timer_adjust", duration=300, delta=60)
    assert ambiguous["status"] == "ambiguous"
    assert len(ambiguous["candidates"]) == 2
    after = (await call(hass, "query", duration=300))["items"]
    assert [i["extended"] for i in after] == [i["extended"] for i in before]

    # The caller's area breaks the tie.
    by_area = await call(hass, "timer_adjust", duration=300, area="kueche", delta="-00:00:30")
    assert by_area["status"] == "ok"
    assert by_area["items"][0]["id"] == five["id"]
    assert by_area["items"][0]["extended"] == 30


async def test_pause_resume_cancel(hass):
    await setup(hass, {})
    t = (await call(hass, "timer_start", duration=120))["items"][0]
    paused = await call(hass, "timer_pause")
    assert paused["items"][0]["state"] == "paused"
    assert paused["items"][0]["ends_at"] is None
    resumed = await call(hass, "timer_resume")
    assert resumed["items"][0]["state"] == "running"

    await call(hass, "timer_cancel", entity_id=f"sensor.remembrance_timer_{t['id']}")
    await hass.async_block_till_done()
    assert hass.states.get(f"sensor.remembrance_timer_{t['id']}") is None
    assert (await call(hass, "query"))["items"] == []


async def test_empty_target_fields_mean_not_given(hass):
    await setup(hass, {})
    t = (await call(hass, "timer_start", duration=60, area=""))["items"][0]
    assert t["areas"] == []
    done = await call(hass, "timer_pause", label="", duration=0, remaining=0, area="")
    assert done["status"] == "ok"
    assert done["items"][0]["id"] == t["id"]


async def test_unknown_target(hass):
    await setup(hass, {})
    assert (await call(hass, "timer_pause", label="Pizza"))["status"] == "no_match"
    # Without a response, a failed call is an error.
    with pytest.raises(ServiceValidationError):
        await hass.services.async_call("remembrance", "timer_pause", {"label": "x"}, blocking=True)


async def test_ring_dismiss_and_snooze(hass):
    await setup(hass, FAST_RING)
    ringing = events(hass, "ringing")
    dismissed = events(hass, "dismissed")
    t = (await call(hass, "timer_start", duration=1, area="kueche"))["items"][0]

    # Rings at 1 s, again at 2 s.
    await asyncio.sleep(2.4)
    await hass.async_block_till_done()
    assert [e["round"] for e in ringing] == [1, 2]
    assert ringing[0]["id"] == t["id"]
    assert hass.states.get("binary_sensor.remembrance_ringing").state == "on"

    done = await call(hass, "dismiss", area="kueche")
    assert [i["id"] for i in done["items"]] == [t["id"]]
    await hass.async_block_till_done()
    assert dismissed[0]["reason"] == "dismissed"
    assert hass.states.get("binary_sensor.remembrance_ringing").state == "off"
    assert hass.states.get(f"sensor.remembrance_timer_{t['id']}") is None

    # "Noch mal": snooze without a target brings back what rang last.
    again = await call(hass, "snooze", delay=1)
    assert again["status"] == "ok"
    assert again["items"][0]["id"] == t["id"]
    assert again["items"][0]["state"] == "running"
    await asyncio.sleep(1.3)
    await hass.async_block_till_done()
    assert ringing[-1]["id"] == t["id"] and ringing[-1]["round"] == 1


async def test_ringing_times_out(hass):
    await setup(hass, {"ring": {"timer": {"interval": 1, "limit": 1}}})
    dismissed = events(hass, "dismissed")
    await call(hass, "timer_start", duration=1)
    await asyncio.sleep(2.6)
    await hass.async_block_till_done()
    assert [e["reason"] for e in dismissed] == ["timeout"]


async def test_ring_script_gets_item(hass):
    from homeassistant.setup import async_setup_component

    assert await async_setup_component(
        hass,
        "script",
        {
            "script": {
                "ring": {
                    "sequence": [
                        {
                            "event": "rang",
                            "event_data": {"label": "{{ label }}", "round": "{{ round }}"},
                        }
                    ]
                }
            }
        },
    )
    rang = []
    hass.bus.async_listen("rang", lambda e: rang.append(e.data))
    await setup(hass, {**FAST_RING, "ring_script": "script.ring"})
    await call(hass, "timer_start", duration=1, label="Tee")
    await asyncio.sleep(1.3)
    await hass.async_block_till_done()
    assert rang[0] == {"label": "Tee", "round": 1}


async def test_survives_restart(tmp_path):
    hass = await start_hass(tmp_path)
    await setup(hass, {})
    kept = (await call(hass, "timer_start", duration=600, label="Brot"))["items"][0]
    paused = (await call(hass, "timer_start", duration=900))["items"][0]
    await call(hass, "timer_pause", id=paused["id"])
    await hass.async_stop(force=True)

    hass = await start_hass(tmp_path)
    await setup(hass, {})
    items = {i["id"]: i for i in (await call(hass, "query"))["items"]}
    assert items[kept["id"]]["state"] == "running"
    assert items[kept["id"]]["ends_at"] == kept["ends_at"]
    assert items[paused["id"]]["state"] == "paused"
    assert hass.states.get(f"sensor.remembrance_timer_{kept['id']}") is not None
    await hass.async_stop(force=True)


async def test_overdue_after_restart(tmp_path):
    hass = await start_hass(tmp_path)
    await setup(hass, {})
    await call(hass, "timer_start", duration=1)
    await call(hass, "timer_start", duration=2, label="Alt")
    # Stop before either ends; "Alt" ends long before the restart.
    await hass.async_stop(force=True)
    await asyncio.sleep(2.2)

    hass = await start_hass(tmp_path)
    ringing = events(hass, "ringing")
    missed = events(hass, "missed")
    # Grace 1 s: the 1-second timer is about 1.5 s late, the 2-second one 0.5 s.
    await setup(hass, {**FAST_RING, "missed_grace": 1})
    await hass.async_block_till_done()
    assert [e["label"] for e in missed] == [None]
    assert [e["label"] for e in ringing] == ["Alt"]
    await hass.async_stop(force=True)


async def test_without_area_rings_everywhere(hass):
    await setup(hass, FAST_RING)
    anywhere = (await call(hass, "timer_start", duration=1))["items"][0]
    kitchen = (await call(hass, "timer_start", duration=1, area="kueche"))["items"][0]
    await call(hass, "timer_start", duration=1, area="bad")
    await asyncio.sleep(1.3)
    await hass.async_block_till_done()

    # "Stopp" in the kitchen: its own, and the one without an area.
    done = await call(hass, "dismiss", area="kueche")
    assert {i["id"] for i in done["items"]} == {anywhere["id"], kitchen["id"]}
    assert anywhere["areas"] == []
