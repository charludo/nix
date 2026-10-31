"""The integration on a real core: setup, sessions, actions, entities, events."""

import asyncio

import pytest
from bluez_stub import ADAPTER, ADDRESS
from conftest import until
from homeassistant.config_entries import ConfigEntry, ConfigEntryState
from homeassistant.data_entry_flow import FlowResultType
from homeassistant.exceptions import ServiceValidationError
from homeassistant.helpers import device_registry as dr
from homeassistant.util import dt as dt_util

DOMAIN = "echo_wall_clock"


async def add_entry(hass, options=None) -> ConfigEntry:
    entry = ConfigEntry(
        version=1,
        minor_version=1,
        domain=DOMAIN,
        title="EchoWallClk0BE",
        data={"address": ADDRESS, "adapter": ADAPTER},
        options=options or {},
        source="user",
        unique_id=ADDRESS,
        discovery_keys={},
        subentries_data=None,
    )
    await hass.config_entries.async_add(entry)
    await hass.async_block_till_done()
    assert entry.state is ConfigEntryState.LOADED
    return entry


async def call(hass, service, **data):
    return await hass.services.async_call(
        DOMAIN, service, data, blocking=True, return_response=True
    )


async def connect(hass, world):
    world.link_up()
    clock = world.clock()
    await until(lambda: "Notifications/ClearIndicator" in clock.names())
    await hass.async_block_till_done()
    return clock


def events(hass, name):
    seen = []
    hass.bus.async_listen(f"{DOMAIN}_{name}", lambda e: seen.append(e.data))
    return seen


# --- config flow -------------------------------------------------------------------


async def test_flow_offers_an_already_paired_clock(hass, world):
    result = await hass.config_entries.flow.async_init(DOMAIN, context={"source": "user"})
    assert (result["type"], result["step_id"]) == (FlowResultType.FORM, "known")
    result = await hass.config_entries.flow.async_configure(result["flow_id"], {"address": ADDRESS})
    assert result["type"] is FlowResultType.CREATE_ENTRY
    assert result["data"] == {"address": ADDRESS, "adapter": ADAPTER}
    await hass.async_block_till_done()
    assert world.profile

    # Only once.
    result = await hass.config_entries.flow.async_init(DOMAIN, context={"source": "user"})
    assert result["step_id"] == "prepare"


async def test_flow_scans_and_pairs_a_new_clock(hass, world):
    from bluez_stub import WORLD

    new = WORLD.bluez.Candidate("F8:54:B8:00:00:02", "EchoWallClkNEW", ADAPTER, False, False)
    world.known = []
    result = await hass.config_entries.flow.async_init(DOMAIN, context={"source": "user"})
    assert result["step_id"] == "prepare"

    # Nothing in pairing mode yet.
    result = await advance(
        hass, await hass.config_entries.flow.async_configure(result["flow_id"], {})
    )
    assert (result["step_id"], result["errors"]) == ("prepare", {"base": "none_found"})

    world.in_pairing_mode = [new]
    result = await advance(
        hass, await hass.config_entries.flow.async_configure(result["flow_id"], {})
    )
    assert result["type"] is FlowResultType.CREATE_ENTRY
    assert result["data"]["address"] == "F8:54:B8:00:00:02"
    assert world.paired == ["F8:54:B8:00:00:02"]


async def test_flow_reports_failed_pairing(hass, world):
    from bluez_stub import WORLD

    world.known = []
    world.in_pairing_mode = [
        WORLD.bluez.Candidate("F8:54:B8:00:00:03", "EchoWallClk", ADAPTER, False, False)
    ]
    world.fail_pairing = True
    result = await hass.config_entries.flow.async_init(DOMAIN, context={"source": "user"})
    result = await advance(
        hass, await hass.config_entries.flow.async_configure(result["flow_id"], {})
    )
    assert (result["step_id"], result["errors"]) == ("prepare", {"base": "pair_failed"})


async def test_flow_aborts_without_an_adapter(hass, world):
    world.adapters = []
    result = await hass.config_entries.flow.async_init(DOMAIN, context={"source": "user"})
    assert (result["type"], result["reason"]) == (FlowResultType.ABORT, "no_adapter")


async def advance(hass, result):
    """Through progress steps, as the frontend would."""
    while result["type"] in (FlowResultType.SHOW_PROGRESS, FlowResultType.SHOW_PROGRESS_DONE):
        await hass.async_block_till_done()
        result = await hass.config_entries.flow.async_configure(result["flow_id"])
    return result


# --- sessions and entities ------------------------------------------------------------


async def test_connects_when_the_clock_comes_and_updates_the_device(hass, world):
    entry = await add_entry(hass)
    assert hass.states.get("binary_sensor.echowallclk0be_connected").state == "off"

    clock = await connect(hass, world)
    assert clock.names()[:2] == [
        "Alexa.Discovery/Discover",
        "Alexa.Gadget.StateListener/StateUpdate",
    ]
    assert hass.states.get("binary_sensor.echowallclk0be_connected").state == "on"
    device = dr.async_get(hass).async_get(entry.runtime_data.device_id)
    assert (device.serial_number, device.sw_version) == ("G0TEST", "102")

    world.link_down()
    await until(lambda: hass.states.get("binary_sensor.echowallclk0be_connected").state == "off")

    # And back: the clock is brought up to date again.
    world.clocks.clear()
    await connect(hass, world)


async def test_timer_lifecycle(hass, world):
    await add_entry(hass)
    clock = await connect(hass, world)

    started = await call(hass, "set_timer", duration={"minutes": 5}, label="Pasta")
    token = started["alert_id"]
    assert started["kind"] == "timer" and started["label"] == "Pasta"
    assert clock.alerts_sent()[-1][:2] == (token, "TIMER")

    state = hass.states.get("sensor.echowallclk0be_next_timer")
    assert state.state != "unknown"
    assert state.attributes["alerts"][0]["alert_id"] == token

    longer = await call(hass, "update_alert", alert_id=token, extend={"minutes": 2})
    assert longer["at"] > started["at"]
    assert clock.alerts_sent()[-1][0] == token

    listed = await call(hass, "list_alerts")
    assert listed["connected"] and [a["alert_id"] for a in listed["alerts"]] == [token]

    await call(hass, "cancel_alert", alert_id=token)
    assert clock.deletes_sent() == [token]
    await hass.async_block_till_done()
    assert hass.states.get("sensor.echowallclk0be_next_timer").state == "unknown"

    with pytest.raises(ServiceValidationError):
        await call(hass, "cancel_alert", alert_id=token)


async def test_alarm_at_a_time_of_day_and_cancel_all(hass, world):
    await add_entry(hass)
    clock = await connect(hass, world)
    alarm = await call(hass, "set_alarm", at="06:30", alert_id="wake")
    at = dt_util.parse_datetime(alarm["at"])
    assert (at.hour, at.minute) == (6, 30) and at > dt_util.now()
    await call(hass, "set_reminder", at=(dt_util.now() + dt_util.dt.timedelta(hours=2)).isoformat())
    assert {a[1] for a in clock.alerts_sent()} == {"ALARM", "REMINDER"}

    done = await call(hass, "cancel_all", kind="alarm")
    assert done["cancelled"] == ["wake"]
    assert len((await call(hass, "list_alerts"))["alerts"]) == 1

    with pytest.raises(ServiceValidationError):
        await call(hass, "set_reminder", at="2020-01-01 10:00:00")


async def test_changes_while_away_reach_the_clock_later(hass, world):
    await add_entry(hass)
    kept = (await call(hass, "set_timer", duration=600))["alert_id"]
    gone = (await call(hass, "set_timer", duration=900))["alert_id"]
    await call(hass, "cancel_alert", alert_id=gone)
    assert not (await call(hass, "list_alerts"))["connected"]

    clock = await connect(hass, world)
    assert [a[0] for a in clock.alerts_sent()] == [kept]
    assert clock.deletes_sent() == [gone]


async def test_due_alert_rings_then_ends(hass, world):
    entry = await add_entry(hass, options={"ring_for": 1})
    clock = await connect(hass, world)
    due, ended = events(hass, "alert_due"), events(hass, "alert_ended")

    token = (await call(hass, "set_timer", duration=1, label="Tea"))["alert_id"]
    await until(lambda: due, timeout=4)
    assert (due[0]["alert_id"], due[0]["label"]) == (token, "Tea")
    assert due[0]["device_id"]
    assert hass.states.get("sensor.echowallclk0be_next_timer").attributes["alerts"][0]["ringing"]

    await until(lambda: ended, timeout=4)
    assert (ended[0]["alert_id"], ended[0]["reason"]) == (token, "timeout")
    assert clock.deletes_sent() == [token]
    assert entry.runtime_data.clock.state.alerts == {}


async def test_stopping_a_ringing_alert(hass, world):
    await add_entry(hass)
    await connect(hass, world)
    due, ended = events(hass, "alert_due"), events(hass, "alert_ended")
    token = (await call(hass, "set_timer", duration=1))["alert_id"]
    await until(lambda: due, timeout=4)
    await call(hass, "cancel_alert", alert_id=token)
    await until(lambda: ended)
    assert ended[0]["reason"] == "cancelled"


async def test_indicator_and_sync_time(hass, world):
    await add_entry(hass)
    clock = await connect(hass, world)
    await hass.services.async_call(
        "switch",
        "turn_on",
        {"entity_id": "switch.echowallclk0be_notification_indicator"},
        blocking=True,
    )
    assert clock.names()[-1] == "Notifications/SetIndicator"
    assert hass.states.get("switch.echowallclk0be_notification_indicator").state == "on"

    before = len(clock.time_infos())
    await hass.services.async_call(
        "button", "press", {"entity_id": "button.echowallclk0be_sync_time"}, blocking=True
    )
    await hass.services.async_call(DOMAIN, "sync_time", {}, blocking=True)
    assert len(clock.time_infos()) == before + 2


async def test_alerts_survive_a_restart_of_the_entry(hass, world):
    entry = await add_entry(hass)
    token = (await call(hass, "set_timer", duration=3600))["alert_id"]
    assert await hass.config_entries.async_reload(entry.entry_id)
    await hass.async_block_till_done()
    assert [a["alert_id"] for a in (await call(hass, "list_alerts"))["alerts"]] == [token]
    clock = await connect(hass, world)
    assert clock.alerts_sent()[0][0] == token


async def test_unload_releases_bluez(hass, world):
    entry = await add_entry(hass)
    assert world.profile
    assert await hass.config_entries.async_unload(entry.entry_id)
    assert not world.profile
    assert not world.watchers[ADDRESS]
    await asyncio.sleep(0)
