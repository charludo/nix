"""The engine: holds the items, schedules and rings them, and reports changes.

Timers live here; reminders and alarms in the calendar (CalendarManager).
Services, entities and events are thin views onto this class.
"""

from __future__ import annotations

import asyncio
import logging
from collections.abc import Callable
from dataclasses import dataclass, field
from datetime import UTC, date, datetime, time, timedelta
from typing import Any

from homeassistant.core import CALLBACK_TYPE, HomeAssistant, callback
from homeassistant.helpers import entity_registry as er
from homeassistant.helpers.dispatcher import async_dispatcher_send
from homeassistant.helpers.event import async_track_point_in_utc_time
from homeassistant.helpers.storage import Store

from . import calendar_items as ci
from .caldav_source import SourceError
from .calendar_manager import CalendarManager, local_datetime
from .const import (
    CONF_CALENDAR,
    CONF_INTERVAL,
    CONF_LIMIT,
    CONF_MISSED_GRACE,
    CONF_RING,
    CONF_RING_SCRIPT,
    CONF_SNOOZE_DELAY,
    DEFAULT_MISSED_GRACE,
    DEFAULT_RING,
    DEFAULT_SNOOZE_DELAY,
    DOMAIN,
    EVENT_CHANGED,
    EVENT_DISMISSED,
    EVENT_MISSED,
    EVENT_RINGING,
    EVENT_SNOOZED,
    KIND_ALARM,
    KIND_REMINDER,
    KIND_TIMER,
    RECENT_WINDOW,
    SIGNAL_UPDATED,
    STATUS_AMBIGUOUS,
    STATUS_INVALID,
    STATUS_NO_MATCH,
    STATUS_OK,
    STORAGE_KEY,
    STORAGE_VERSION,
)
from .timers import Selector, Timer, TimerBook, TimerError, TimerState, resolve

_LOGGER = logging.getLogger(__name__)


def _iso(ts: float | None) -> str | None:
    return datetime.fromtimestamp(ts, UTC).isoformat() if ts is not None else None


def _in_area(areas: list[str], area: str | None) -> bool:
    """Whether an item with `areas` rings in `area`; without areas: everywhere."""
    return bool(area) and (not areas or area in areas)


@dataclass
class Target:
    """Which existing items a service call means (see the ToDo's API)."""

    ids: list[str] = field(default_factory=list)
    selector: Selector = field(default_factory=Selector)
    all: bool = False
    # Reminders and alarms: the time of day they're at.
    at_time: time | None = None

    def is_empty(self) -> bool:
        """Nothing said but (maybe) where: the area only breaks ties."""
        return not self.ids and not self.all and self.selector.is_empty() and self.at_time is None


@dataclass
class Result:
    """What a service call did; becomes its response."""

    status: str = STATUS_OK
    items: list[dict] = field(default_factory=list)
    candidates: list[dict] = field(default_factory=list)
    reason: str | None = None

    def as_response(self) -> dict[str, Any]:
        response: dict[str, Any] = {"status": self.status, "items": self.items}
        if self.candidates:
            response["candidates"] = self.candidates
        if self.reason:
            response["reason"] = self.reason
        return response


@dataclass
class Ringing:
    """Something ringing right now, whatever its kind."""

    kind: str
    id: str
    areas: list[str]
    label: str | None
    # Calendar entries: the ring (occurrence, reminder) that's ringing.
    ring: ci.Ring | None = None


class Engine:
    def __init__(self, hass: HomeAssistant, config: dict) -> None:
        self.hass = hass
        self.config = config
        self.book = TimerBook()
        self.calendar: CalendarManager | None = (
            CalendarManager(hass, self, config[CONF_CALENDAR]) if CONF_CALENDAR in config else None
        )
        self._store: Store = Store(hass, STORAGE_VERSION, STORAGE_KEY)
        self._unsub: dict[str, CALLBACK_TYPE] = {}
        # Ring loops by item id (timer id or calendar UID).
        self._ringers: dict[str, asyncio.Task] = {}
        self._ringing: dict[str, Ringing] = {}
        # Recently rung items (dismissed or timed out), newest last: what
        # "snooze" without a target means after the ringing stopped.
        self._recent: list[tuple[float, dict]] = []

    @property
    def missed_grace(self) -> float:
        return self.config.get(CONF_MISSED_GRACE, DEFAULT_MISSED_GRACE)

    # --- lifecycle -------------------------------------------------------

    async def async_load(self) -> None:
        data = await self._store.async_load() or {}
        self.book = TimerBook.from_list(data.get("timers", []))
        now = self._now()
        for timer in list(self.book.timers.values()):
            if timer.state == TimerState.PAUSED:
                continue
            due = timer.ends_at or now
            if due > now:
                self._schedule(timer)
            elif now - due <= self.missed_grace:
                self._fire(timer)
            else:
                self.book.remove(timer)
                self._event(EVENT_MISSED, timer)
        if self.calendar:
            self.calendar.load(data.get("calendar", {}))
        self.save()

    async def async_start(self) -> None:
        """After setup: the first calendar sync (needs the network)."""
        if self.calendar:
            await self.calendar.async_start()

    async def async_unload(self) -> None:
        for unsub in self._unsub.values():
            unsub()
        self._unsub.clear()
        for task in self._ringers.values():
            task.cancel()
        self._ringers.clear()
        if self.calendar:
            self.calendar.stop()
        await self._store.async_save(self._data())

    # --- timers ----------------------------------------------------------

    def timer_start(self, duration: float, label: str | None, area: str | None) -> Result:
        try:
            timer = self.book.start(duration, self._now(), label=label, area=area)
        except TimerError as err:
            return Result(STATUS_INVALID, reason=str(err))
        self._schedule(timer)
        self._changed(timer.id)
        return Result(items=[self.item(timer)])

    def timer_adjust(
        self, target: Target, delta: float | None = None, remaining: float | None = None
    ) -> Result:
        def apply(timer: Timer) -> None:
            now = self._now()
            change = delta if delta is not None else (remaining or 0) - timer.remaining(now)
            self.book.extend(timer, change, now)

        return self._each(target, apply, single=True)

    def timer_pause(self, target: Target) -> Result:
        return self._each(target, lambda t: self.book.pause(t, self._now()))

    def timer_resume(self, target: Target) -> Result:
        def apply(timer: Timer) -> None:
            self.book.resume(timer, self._now())

        return self._each(target, apply, pool=self._paused)

    def timer_cancel(self, target: Target) -> Result:
        def apply(timer: Timer) -> None:
            self._stop_ringing(timer.id)
            self.book.remove(timer)

        return self._each(target, apply, pool=lambda: list(self.book.timers.values()))

    # --- reminders and alarms ---------------------------------------------

    def _no_calendar(self) -> Result:
        return Result(STATUS_INVALID, reason="no calendar configured")

    async def reminder_create(
        self,
        summary: str,
        at: datetime | None,
        in_: float | None,
        alerts: list[float] | None,
        area: str | None,
        description: str | None = None,
    ) -> Result:
        if not self.calendar:
            return self._no_calendar()
        tz = self.calendar.tz
        start = (
            local_datetime(at, tz)
            if at is not None
            else datetime.now(tz) + timedelta(seconds=in_ or 0)
        ).replace(microsecond=0)
        if start <= datetime.now(tz):
            return Result(STATUS_INVALID, reason="in the past")
        return await self._write(
            lambda: self.calendar.async_create(  # type: ignore[union-attr]
                KIND_REMINDER,
                summary,
                start,
                sorted(set(alerts or [0.0])),
                area,
                description=description,
            )
        )

    async def alarm_create(
        self,
        at_time: time,
        days: list[str] | None,
        on: date | None,
        label: str | None,
        area: str | None,
        description: str | None = None,
    ) -> Result:
        if not self.calendar:
            return self._no_calendar()
        tz = self.calendar.tz
        now = datetime.now(tz)
        try:
            byday = ci.weekday_codes(days) if days else None
        except ValueError as err:
            return Result(STATUS_INVALID, reason=str(err))
        start = datetime.combine(on or now.date(), at_time.replace(second=0, microsecond=0), tz)
        if on is None and start <= now:
            start += timedelta(days=1)
        if not byday and start <= now:
            return Result(STATUS_INVALID, reason="in the past")
        return await self._write(
            lambda: self.calendar.async_create(  # type: ignore[union-attr]
                KIND_ALARM,
                label or "Wecker",
                start,
                [0.0],
                area,
                byday,
                description=description,
            )
        )

    async def alarm_skip(self, target: Target, on: date | None) -> Result:
        """Leave out one occurrence (default: the next) of a repeating alarm;
        a one-off alarm is deleted."""
        if not self.calendar:
            return self._no_calendar()

        async def apply(entry: ci.Entry) -> ci.Entry | None:
            assert self.calendar
            tz = self.calendar.tz
            if on is None:
                occ = ci.next_occurrence(entry, datetime.now(UTC), tz)
            else:
                day = datetime.combine(on, time(), tz)
                found = ci.occurrences(entry, day, day + timedelta(days=1), tz)
                occ = found[0] if found else None
            if occ is None:
                raise LookupError("no occurrence on that day")
            if not entry.recurring:
                await self.calendar.async_delete(entry)
                return None
            return await self.calendar.async_rewrite(entry, ci.with_exdate(entry, occ))

        return await self._each_entry(target, KIND_ALARM, apply)

    async def alarm_set_enabled(self, target: Target, enabled: bool) -> Result:
        if not self.calendar:
            return self._no_calendar()

        async def apply(entry: ci.Entry) -> ci.Entry:
            assert self.calendar
            self._stop_ringing(entry.uid)
            return await self.calendar.async_rewrite(entry, ci.with_status(entry, not enabled))

        return await self._each_entry(target, KIND_ALARM, apply)

    async def entry_delete(self, target: Target, kind: str) -> Result:
        if not self.calendar:
            return self._no_calendar()

        async def apply(entry: ci.Entry) -> None:
            assert self.calendar
            self._stop_ringing(entry.uid)
            await self.calendar.async_delete(entry)

        return await self._each_entry(target, kind, apply, many=target.all)

    async def _write(self, create: Callable) -> Result:
        try:
            entry = await create()
        except SourceError as err:
            return Result(STATUS_INVALID, reason=f"calendar: {err}")
        self.calendar_changed()
        assert self.calendar
        return Result(items=[self.calendar.item(entry)])

    async def _each_entry(self, target: Target, kind: str, apply, *, many: bool = False) -> Result:
        assert self.calendar
        chosen = self.calendar.select(target.selector, target.ids, target.all, kind, target.at_time)
        if not chosen:
            return Result(STATUS_NO_MATCH)
        if len(chosen) > 1 and not (many or target.all or target.ids):
            return Result(STATUS_AMBIGUOUS, candidates=[self.calendar.item(e) for e in chosen])
        items: list[dict] = []
        skipped: list[str] = []
        for entry in chosen:
            before = self.calendar.item(entry)
            try:
                after = await apply(entry)
            except SourceError as err:
                return Result(STATUS_INVALID, items=items, reason=f"calendar: {err}")
            except LookupError as err:
                # Several at once: those it doesn't apply to are left alone.
                if len(chosen) == 1:
                    return Result(STATUS_INVALID, items=[before], reason=str(err))
                skipped.append(str(err))
                continue
            items.append(self.calendar.item(after) if after else before)
        if not items:
            return Result(STATUS_NO_MATCH, reason=skipped[0] if skipped else None)
        self.calendar_changed()
        return Result(items=items)

    def calendar_changed(self) -> None:
        self.save()
        async_dispatcher_send(self.hass, SIGNAL_UPDATED, None)
        self.hass.bus.async_fire(EVENT_CHANGED, {"kind": "calendar"})

    def ring_calendar(self, entry: ci.Entry, ring: ci.Ring) -> None:
        """Called by the calendar manager when one of its rings is due."""
        assert self.calendar
        self._stop_ringing(entry.uid)
        calendar = self.calendar
        self._ringing[entry.uid] = Ringing(
            entry.kind, entry.uid, calendar.areas_of(entry), entry.summary, ring
        )
        self._start_ringing(
            entry.uid,
            entry.kind,
            lambda: calendar.item(entry, ring=ring),
            lambda: self._dismiss_id(entry.uid, "timeout"),
        )
        self.calendar_changed()

    def is_ringing(self, item_id: str) -> bool:
        return item_id in self._ringing

    # --- ringing (all kinds) ---------------------------------------------

    def ringing(self) -> list[Ringing]:
        return list(self._ringing.values())

    def ringing_items(self) -> list[dict]:
        return [self._ringing_item(r) for r in self.ringing()]

    def dismiss(self, target: Target) -> Result:
        """Stop ringing. Without a target: everything ringing (in `area`)."""
        chosen = self._pick_ringing(target, all_in_area=True)
        if isinstance(chosen, Result):
            return chosen
        items = [self._ringing_item(r) for r in chosen]
        for r in chosen:
            self._dismiss_id(r.id, "dismissed")
        return Result(items=items)

    def snooze(self, target: Target, delay: float | None = None) -> Result:
        """Ring again after `delay`. Without a target: what is ringing, else
        what rang last (in `area` if given, else anywhere)."""
        delay = delay or self.config.get(CONF_SNOOZE_DELAY, DEFAULT_SNOOZE_DELAY)
        chosen = self._pick_ringing(target, all_in_area=False)
        if isinstance(chosen, Result):
            if not target.is_empty():
                return chosen
            recent = self._recent_item(target.selector.area)
            if recent is None:
                return Result(STATUS_NO_MATCH, reason="nothing rang recently")
            return self._snooze_item(recent, delay)
        return self._snooze_item(self._ringing_item(chosen[0]), delay)

    def _pick_ringing(self, target: Target, *, all_in_area: bool) -> list[Ringing] | Result:
        ringing = self.ringing()
        if not ringing:
            return Result(STATUS_NO_MATCH, reason="nothing ringing")
        if target.is_empty():
            area = target.selector.area
            here = [r for r in ringing if _in_area(r.areas, area)] or ringing
            return here if all_in_area else here[:1]
        if target.ids:
            chosen = [r for r in ringing if r.id in target.ids]
        else:
            timers = [self.book.timers[r.id] for r in ringing if r.kind == KIND_TIMER]
            ids = {t.id for t in resolve(timers, target.selector, self._now())} if timers else set()
            if target.selector.label:
                wanted = (target.selector.label or "").lower()
                ids |= {
                    r.id
                    for r in ringing
                    if r.kind != KIND_TIMER and wanted in (r.label or "").lower()
                }
            chosen = [r for r in ringing if r.id in ids]
        if not chosen:
            return Result(STATUS_NO_MATCH)
        if len(chosen) > 1 and not target.all:
            return Result(STATUS_AMBIGUOUS, candidates=[self._ringing_item(r) for r in chosen])
        return chosen

    def _ringing_item(self, r: Ringing) -> dict:
        if r.kind == KIND_TIMER:
            return self.item(self.book.timers[r.id])
        assert self.calendar
        entry = self.calendar.entries[r.id]
        return self.calendar.item(entry, ring=r.ring)

    def _dismiss_id(self, item_id: str, reason: str) -> None:
        r = self._ringing.get(item_id)
        if r is None:
            return
        item = self._ringing_item(r)
        self._stop_ringing(item_id)
        if r.kind == KIND_TIMER:
            timer = self.book.timers[item_id]
            self.book.remove(timer)
        self._remember(item)
        self.hass.bus.async_fire(EVENT_DISMISSED, {**item, "reason": reason})
        self._changed(item_id)

    def _snooze_item(self, item: dict, delay: float) -> Result:
        self._stop_ringing(item["id"])
        self._recent = [(t, i) for t, i in self._recent if i["id"] != item["id"]]
        if item["kind"] == KIND_TIMER:
            timer = self.book.timers.get(item["id"]) or Timer(
                id=item["id"],
                duration=item["duration"],
                created=self._now(),
                label=item["label"],
                area=next(iter(item["areas"]), None),
                extended=item["extended"],
            )
            self.book.timers[timer.id] = timer
            timer.state = TimerState.RUNNING
            timer.paused_remaining = None
            timer.ends_at = self._now() + delay
            self._schedule(timer)
            result = self.item(timer)
        else:
            assert self.calendar
            entry = self.calendar.entries.get(item["id"])
            if entry is None:
                return Result(STATUS_NO_MATCH, reason="entry is gone")
            occurrence = datetime.fromisoformat(item["start"])
            self.calendar.snooze(entry, occurrence, delay)
            result = self.calendar.item(entry, occurrence=occurrence)
        self.hass.bus.async_fire(EVENT_SNOOZED, {**result, "delay": delay})
        self._changed(item["id"])
        return Result(items=[result])

    # --- queries ---------------------------------------------------------

    def query(
        self,
        target: Target,
        kind: str | None = None,
        state: str | None = None,
        start: datetime | None = None,
        end: datetime | None = None,
    ) -> Result:
        """Timers soonest first; reminders and alarms by their next ring, or
        (with a window) one item per occurrence in it."""
        items: list[dict] = []
        if kind in (None, KIND_TIMER):
            pool = [t for t in self.book.timers.values() if state is None or t.state == state]
            pool.sort(key=lambda t: (t.ends_at or float("inf"), t.created))
            if not target.is_empty():
                pool = self._select(target, pool)
            items += [self.item(t) for t in pool]
        if kind in (None, KIND_REMINDER, KIND_ALARM) and self.calendar:
            cal = self.calendar
            chosen = {
                e.uid
                for e in cal.select(target.selector, target.ids, target.all, kind, target.at_time)
            }
            if start or end:
                tz = cal.tz
                window_start = local_datetime(start, tz) if start else datetime.now(tz)
                window_end = local_datetime(end, tz) if end else window_start + timedelta(days=1)
                for entry, occ, _end in cal.occurrences(window_start, window_end, kind):
                    if entry.uid in chosen:
                        items.append(cal.item(entry, occurrence=occ))
            else:
                found = [cal.item(e) for uid, e in cal.entries.items() if uid in chosen]
                items += sorted(
                    (i for i in found if state is None or i["state"] == state),
                    key=lambda i: i["next_ring"] or i["start"] or "~",
                )
        return Result(items=items)

    def item(self, timer: Timer) -> dict[str, Any]:
        now = self._now()
        return {
            "id": timer.id,
            "kind": KIND_TIMER,
            "label": timer.label,
            "areas": [timer.area] if timer.area else [],
            "state": str(timer.state),
            "duration": timer.duration,
            "extended": timer.extended,
            "remaining": round(timer.remaining(now), 1),
            "ends_at": _iso(timer.ends_at),
            "created": _iso(timer.created),
            "entity_id": self.entity_id(timer.id),
        }

    def entity_id(self, timer_id: str) -> str | None:
        return er.async_get(self.hass).async_get_entity_id("sensor", DOMAIN, f"timer_{timer_id}")

    # --- internals -------------------------------------------------------

    def _now(self) -> float:
        return datetime.now(UTC).timestamp()

    def _paused(self) -> list[Timer]:
        return [t for t in self.book.timers.values() if t.state == TimerState.PAUSED]

    def _select(self, target: Target, pool: list[Timer]) -> list[Timer]:
        if target.ids:
            return [t for t in pool if t.id in target.ids]
        if target.all:
            return pool
        return resolve(pool, target.selector, self._now())

    def _each(self, target: Target, apply, *, single: bool = False, pool=None) -> Result:
        """Resolve `target` in `pool` (default: running and paused timers) and
        apply to each; ambiguous or unknown targets change nothing."""
        candidates = (pool or self.book.active)()
        chosen = self._select(target, candidates)
        if not chosen:
            return Result(STATUS_NO_MATCH)
        if len(chosen) > 1 and (single or not (target.all or target.ids)):
            return Result(STATUS_AMBIGUOUS, candidates=[self.item(t) for t in chosen])
        done: list[Timer] = []
        for timer in chosen:
            try:
                apply(timer)
            except TimerError as err:
                if len(chosen) == 1:
                    return Result(STATUS_INVALID, items=[self.item(timer)], reason=str(err))
                continue
            done.append(timer)
        for timer in done:
            if timer.id in self.book.timers:
                self._schedule(timer)
            else:
                self._unschedule(timer)
            self._changed(timer.id)
        return Result(items=[self.item(t) for t in done])

    def _schedule(self, timer: Timer) -> None:
        self._unschedule(timer)
        if timer.state != TimerState.RUNNING or timer.ends_at is None:
            return
        when = datetime.fromtimestamp(timer.ends_at, UTC)

        @callback
        def fire(_now: datetime) -> None:
            self._unsub.pop(timer.id, None)
            if self.book.timers.get(timer.id) is timer and timer.state == TimerState.RUNNING:
                self._fire(timer)

        self._unsub[timer.id] = async_track_point_in_utc_time(self.hass, fire, when)

    def _unschedule(self, timer: Timer) -> None:
        if unsub := self._unsub.pop(timer.id, None):
            unsub()

    def _fire(self, timer: Timer) -> None:
        self.book.ring(timer)
        self._ringing[timer.id] = Ringing(
            KIND_TIMER, timer.id, [timer.area] if timer.area else [], timer.label
        )
        self._start_ringing(
            timer.id,
            KIND_TIMER,
            lambda: self.item(timer),
            lambda: self._dismiss_id(timer.id, "timeout"),
        )
        self._changed(timer.id)

    def _start_ringing(
        self, item_id: str, kind: str, data: Callable[[], dict], on_timeout: Callable[[], None]
    ) -> None:
        self._ringers[item_id] = self.hass.async_create_background_task(
            self._ring(item_id, kind, data, on_timeout), f"{STORAGE_KEY} ring {item_id}"
        )

    async def _ring(
        self, item_id: str, kind: str, data: Callable[[], dict], on_timeout: Callable[[], None]
    ) -> None:
        """Ring rounds every `interval` from the first; timed out at `limit`,
        after the last round has rung out. `limit` 0: a single round."""
        default_interval, default_limit = DEFAULT_RING[kind]
        rhythm = self.config.get(CONF_RING, {}).get(kind, {})
        interval = rhythm.get(CONF_INTERVAL, default_interval)
        limit = rhythm.get(CONF_LIMIT, default_limit)
        started = self._now()
        round_ = 1
        try:
            while True:
                payload = {**data(), "round": round_}
                self.hass.bus.async_fire(EVENT_RINGING, payload)
                if script := self.config.get(CONF_RING_SCRIPT):
                    await self.hass.services.async_call(
                        "script", "turn_on", {"entity_id": script, "variables": payload}
                    )
                next_round = started + round_ * interval
                if next_round >= started + limit:
                    await asyncio.sleep(max(0.0, started + limit - self._now()))
                    break
                await asyncio.sleep(max(0.0, next_round - self._now()))
                round_ += 1
        except asyncio.CancelledError:
            return
        self._ringers.pop(item_id, None)
        on_timeout()

    def _stop_ringing(self, item_id: str) -> None:
        self._ringing.pop(item_id, None)
        if task := self._ringers.pop(item_id, None):
            task.cancel()

    def _remember(self, item: dict) -> None:
        now = self._now()
        self._recent = [(t, i) for t, i in self._recent if now - t <= RECENT_WINDOW]
        self._recent.append((now, item))

    def _recent_item(self, area: str | None) -> dict | None:
        now = self._now()
        recent = [i for t, i in self._recent if now - t <= RECENT_WINDOW]
        pick = [i for i in recent if _in_area(i["areas"], area)] or recent
        return pick[-1] if pick else None

    def _event(self, event: str, timer: Timer, **extra: Any) -> None:
        self.hass.bus.async_fire(event, {**self.item(timer), **extra})

    def _changed(self, item_id: str | None) -> None:
        self.save()
        async_dispatcher_send(self.hass, SIGNAL_UPDATED, item_id)
        timer = self.book.timers.get(item_id) if item_id else None
        self.hass.bus.async_fire(EVENT_CHANGED, self.item(timer) if timer else {"id": item_id})

    def _data(self) -> dict:
        data: dict[str, Any] = {"timers": self.book.to_list()}
        if self.calendar:
            data["calendar"] = self.calendar.data()
        return data

    def save(self) -> None:
        self._store.async_delay_save(self._data, 1)
