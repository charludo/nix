"""Sessions with a stand-in clock: what it's told, and when."""

import asyncio
from datetime import datetime, timedelta, timezone

import pytest
from fakeclock import FakeClock

from echo_wall_clock import clock as clock_mod
from echo_wall_clock.clock import ClockState, WallClock

CET = timezone(timedelta(hours=1))
NOW = datetime(2026, 10, 31, 16, 0, tzinfo=CET)


@pytest.fixture(autouse=True)
def fast(monkeypatch):
    monkeypatch.setattr(clock_mod, "SETTLE", 0)
    monkeypatch.setattr(clock_mod, "DISCOVER_TIMEOUT", 0.2)


async def until(check, timeout=2.0):
    end = asyncio.get_running_loop().time() + timeout
    while not check():
        assert asyncio.get_running_loop().time() < end, "timed out"
        await asyncio.sleep(0.01)


async def start(wall: WallClock, fake: FakeClock):
    link = fake.link()

    async def opener():
        return link

    task = asyncio.create_task(wall.run_session(opener))
    await until(lambda: "Notifications/ClearIndicator" in fake.names() or task.done())
    return link, task


async def test_session_brings_the_clock_up_to_date():
    wall = WallClock(ClockState(), lambda: NOW)
    await wall.set_alert("timer", NOW + timedelta(minutes=5), token="t1")
    fake = FakeClock()
    link, task = await start(wall, fake)

    assert wall.connected
    assert fake.names() == [
        "Alexa.Discovery/Discover",
        "Alexa.Gadget.StateListener/StateUpdate",
        "Alerts/SetAlert",
        "Notifications/ClearIndicator",
    ]
    assert fake.time_infos() == ["2026-10-31T16:00:00+01:00"]
    assert fake.alerts_sent() == [("t1", "TIMER", "2026-10-31T16:05:00+01:00")]
    assert wall.state.info.firmware == "102"

    link.drop()
    await asyncio.wait_for(task, 1)
    assert not wall.connected


async def test_changes_while_connected_go_out_at_once():
    wall = WallClock(ClockState(), lambda: NOW)
    fake = FakeClock()
    link, task = await start(wall, fake)

    alert = await wall.set_alert("alarm", NOW + timedelta(hours=8))
    assert fake.alerts_sent()[-1] == (alert.token, "ALARM", "2026-11-01T00:00:00+01:00")
    assert alert.token.isdigit() and len(alert.token) == 10

    await wall.move_alert(alert.token, NOW + timedelta(hours=9))
    assert fake.alerts_sent()[-1][2] == "2026-11-01T01:00:00+01:00"

    # Same token, other kind: the old one is deleted first.
    await wall.set_alert("reminder", NOW + timedelta(hours=9), token=alert.token)
    assert fake.deletes_sent() == [alert.token]

    assert await wall.cancel_alert(alert.token)
    assert fake.deletes_sent() == [alert.token, alert.token]
    assert not await wall.cancel_alert("nope")

    await wall.set_indicator(True)
    assert fake.names()[-1] == "Notifications/SetIndicator"

    link.drop()
    await task


async def test_cancelled_while_away_is_deleted_next_time():
    wall = WallClock(ClockState(), lambda: NOW)
    await wall.set_alert("timer", NOW + timedelta(minutes=5), token="gone")
    await wall.set_alert("timer", NOW + timedelta(minutes=9), token="kept")
    assert await wall.cancel_alert("gone")
    assert wall.state.pending_deletes == {"gone"}

    fake = FakeClock()
    link, task = await start(wall, fake)
    assert fake.deletes_sent() == ["gone"]
    assert [a[0] for a in fake.alerts_sent()] == ["kept"]
    assert wall.state.pending_deletes == set()
    link.drop()
    await task


async def test_time_is_resent_while_connected():
    wall = WallClock(ClockState(), lambda: NOW, time_sync_every=timedelta(seconds=0.05))
    fake = FakeClock()
    link, task = await start(wall, fake)
    await until(lambda: len(fake.time_infos()) >= 3)
    link.drop()
    await task


async def test_carries_on_without_a_discover_response():
    wall = WallClock(ClockState(), lambda: NOW)
    fake = FakeClock(answer_discover=False)
    link, task = await start(wall, fake)
    assert "Alexa.Gadget.StateListener/StateUpdate" in fake.names()
    assert wall.state.info is None
    link.drop()
    await task


async def test_nothing_is_sent_while_away():
    wall = WallClock(ClockState(), lambda: NOW)
    assert not await wall.sync_time()
    alert = await wall.set_alert("timer", NOW + timedelta(minutes=1))
    assert alert.token in wall.state.alerts


async def test_state_round_trips_and_expires():
    changes = []
    wall = WallClock(ClockState(), lambda: NOW, on_change=lambda: changes.append(1))
    await wall.set_alert("timer", NOW - timedelta(minutes=30), token="old", label="Pasta")
    await wall.set_alert("alarm", NOW + timedelta(hours=1), token="new")
    await wall.cancel_alert("ghost")  # unknown: no change
    await wall.set_indicator(True)

    copy = ClockState.from_dict(wall.state.as_dict())
    assert copy.alerts == wall.state.alerts
    assert copy.indicator

    gone = wall.expire(timedelta(minutes=10))
    assert [a.token for a in gone] == ["old"]
    assert list(wall.state.alerts) == ["new"]
    assert changes


async def test_rejects_bad_alerts():
    wall = WallClock(ClockState(), lambda: NOW)
    with pytest.raises(ValueError):
        await wall.set_alert("snooze", NOW)
    with pytest.raises(ValueError):
        await wall.set_alert("timer", datetime(2026, 1, 1))
    with pytest.raises(KeyError):
        await wall.move_alert("nope", NOW)
