"""The engine: holds the items, schedules and rings them, and reports changes.

Services, entities and events are thin views onto this class.
"""

from __future__ import annotations

import asyncio
import logging
from dataclasses import dataclass, field
from datetime import UTC, datetime
from typing import Any

from homeassistant.core import CALLBACK_TYPE, HomeAssistant, callback
from homeassistant.helpers import entity_registry as er
from homeassistant.helpers.dispatcher import async_dispatcher_send
from homeassistant.helpers.event import async_track_point_in_utc_time
from homeassistant.helpers.storage import Store

from .const import (
    CONF_DEFAULT_AREA,
    CONF_INTERVAL,
    CONF_LIMIT,
    CONF_MISSED_GRACE,
    CONF_RING,
    CONF_RING_SCRIPT,
    CONF_SNOOZE_DELAY,
    DEFAULT_INTERVAL,
    DEFAULT_LIMIT,
    DEFAULT_MISSED_GRACE,
    DEFAULT_SNOOZE_DELAY,
    DOMAIN,
    EVENT_CHANGED,
    EVENT_DISMISSED,
    EVENT_MISSED,
    EVENT_RINGING,
    EVENT_SNOOZED,
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


@dataclass
class Target:
    """Which existing items a service call means (see the ToDo's API)."""

    ids: list[str] = field(default_factory=list)
    selector: Selector = field(default_factory=Selector)
    all: bool = False

    def is_empty(self) -> bool:
        return not self.ids and not self.all and self.selector.is_empty()


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


class Engine:
    def __init__(self, hass: HomeAssistant, config: dict) -> None:
        self.hass = hass
        self.config = config
        self.book = TimerBook()
        self._store: Store = Store(hass, STORAGE_VERSION, STORAGE_KEY)
        self._unsub: dict[str, CALLBACK_TYPE] = {}
        self._ringers: dict[str, asyncio.Task] = {}
        # Recently rung items (dismissed or timed out), newest last: what
        # "snooze" without a target means after the ringing stopped.
        self._recent: list[tuple[float, dict]] = []

    # --- lifecycle -------------------------------------------------------

    async def async_load(self) -> None:
        data = await self._store.async_load() or {}
        self.book = TimerBook.from_list(data.get("timers", []))
        now = self._now()
        grace = self.config.get(CONF_MISSED_GRACE, DEFAULT_MISSED_GRACE)
        for timer in list(self.book.timers.values()):
            if timer.state == TimerState.PAUSED:
                continue
            due = timer.ends_at or now
            if due > now:
                self._schedule(timer)
            elif now - due <= grace:
                self._fire(timer)
            else:
                self.book.remove(timer)
                self._event(EVENT_MISSED, timer)
        self._save()

    async def async_unload(self) -> None:
        for unsub in self._unsub.values():
            unsub()
        self._unsub.clear()
        for task in self._ringers.values():
            task.cancel()
        self._ringers.clear()
        await self._store.async_save(self._data())

    # --- timers ----------------------------------------------------------

    def timer_start(self, duration: float, label: str | None, area: str | None) -> Result:
        try:
            timer = self.book.start(duration, self._now(), label=label, area=self._area(area))
        except TimerError as err:
            return Result(STATUS_INVALID, reason=str(err))
        self._schedule(timer)
        self._changed(timer)
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
            self._stop_ringing(timer)
            self.book.remove(timer)

        return self._each(target, apply, pool=lambda: list(self.book.timers.values()))

    # --- ringing (all kinds) ---------------------------------------------

    def dismiss(self, target: Target) -> Result:
        """Stop ringing. Without a target: everything ringing (in `area`)."""
        ringing = self.book.ringing()
        if target.is_empty() or (target.selector.area and target.selector.is_empty()):
            area = target.selector.area
            chosen = [t for t in ringing if not area or t.area == area] or ringing
            if not chosen:
                return Result(STATUS_NO_MATCH, reason="nothing ringing")
            for timer in chosen:
                self._dismiss(timer, "dismissed")
            return Result(items=[self.item(t) for t in chosen])
        return self._each(target, lambda t: self._dismiss(t, "dismissed"), pool=lambda: ringing)

    def snooze(self, target: Target, delay: float | None = None) -> Result:
        """Ring again after `delay`. Without a target: what is ringing, else
        what rang last (in `area` if given, else anywhere)."""
        delay = delay or self.config.get(CONF_SNOOZE_DELAY, DEFAULT_SNOOZE_DELAY)
        area = target.selector.area
        if target.is_empty() or (area and target.selector.is_empty()):
            ringing = self.book.ringing()
            pick = [t for t in ringing if t.area == area] or ringing
            if pick:
                timer = pick[0]
            else:
                timer = self._recent_timer(area)
                if timer is None:
                    return Result(STATUS_NO_MATCH, reason="nothing rang recently")
            self._snooze(timer, delay)
            return Result(items=[self.item(timer)])
        return self._each(target, lambda t: self._snooze(t, delay), pool=self.book.ringing)

    # --- queries ---------------------------------------------------------

    def query(self, target: Target, kind: str | None = None, state: str | None = None) -> Result:
        if kind not in (None, KIND_TIMER):
            return Result(items=[])
        pool = [t for t in self.book.timers.values() if state is None or t.state == state]
        pool.sort(key=lambda t: (t.ends_at or float("inf"), t.created))
        if not target.is_empty():
            pool = self._select(target, pool)
        return Result(items=[self.item(t) for t in pool])

    def item(self, timer: Timer) -> dict[str, Any]:
        now = self._now()
        return {
            "id": timer.id,
            "kind": KIND_TIMER,
            "label": timer.label,
            "area": timer.area,
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

    def _area(self, area: str | None) -> str | None:
        return area or self.config.get(CONF_DEFAULT_AREA)

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
            self._changed(timer)
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
        self._changed(timer)
        self._ringers[timer.id] = self.hass.async_create_background_task(
            self._ring(timer), f"{STORAGE_KEY} ring {timer.id}"
        )

    async def _ring(self, timer: Timer) -> None:
        rhythm = self.config.get(CONF_RING, {}).get(KIND_TIMER, {})
        interval = rhythm.get(CONF_INTERVAL, DEFAULT_INTERVAL)
        limit = rhythm.get(CONF_LIMIT, DEFAULT_LIMIT)
        # Rounds every `interval` from the first; dismissed as timed out at
        # `limit`, after the last round has rung out.
        started = self._now()
        round_ = 1
        try:
            while True:
                data = {**self.item(timer), "round": round_}
                self.hass.bus.async_fire(EVENT_RINGING, data)
                if script := self.config.get(CONF_RING_SCRIPT):
                    await self.hass.services.async_call(
                        "script", "turn_on", {"entity_id": script, "variables": data}
                    )
                next_round = started + round_ * interval
                if next_round >= started + limit:
                    await asyncio.sleep(max(0.0, started + limit - self._now()))
                    break
                await asyncio.sleep(max(0.0, next_round - self._now()))
                round_ += 1
        except asyncio.CancelledError:
            return
        self._ringers.pop(timer.id, None)
        if self.book.timers.get(timer.id) is timer and timer.state == TimerState.RINGING:
            self._dismiss(timer, "timeout")

    def _stop_ringing(self, timer: Timer) -> None:
        if task := self._ringers.pop(timer.id, None):
            task.cancel()

    def _dismiss(self, timer: Timer, reason: str) -> None:
        self._stop_ringing(timer)
        item = self.item(timer)
        self.book.remove(timer)
        self._remember(item)
        self._event(EVENT_DISMISSED, timer, reason=reason)
        self._changed(timer)

    def _snooze(self, timer: Timer, delay: float) -> None:
        self._stop_ringing(timer)
        if timer.id not in self.book.timers:
            self.book.timers[timer.id] = timer
        now = self._now()
        timer.state = TimerState.RUNNING
        timer.paused_remaining = None
        timer.ends_at = now + delay
        self._recent = [(t, i) for t, i in self._recent if i["id"] != timer.id]
        self._schedule(timer)
        self._event(EVENT_SNOOZED, timer, delay=delay)
        self._changed(timer)

    def _remember(self, item: dict) -> None:
        now = self._now()
        self._recent = [(t, i) for t, i in self._recent if now - t <= RECENT_WINDOW]
        self._recent.append((now, item))

    def _recent_timer(self, area: str | None) -> Timer | None:
        now = self._now()
        recent = [i for t, i in self._recent if now - t <= RECENT_WINDOW]
        pick = [i for i in recent if area and i["area"] == area] or recent
        if not pick:
            return None
        item = pick[-1]
        return Timer(
            id=item["id"],
            duration=item["duration"],
            created=now,
            label=item["label"],
            area=item["area"],
            extended=item["extended"],
        )

    def _event(self, event: str, timer: Timer, **extra: Any) -> None:
        self.hass.bus.async_fire(event, {**self.item(timer), **extra})

    def _changed(self, timer: Timer) -> None:
        self._save()
        async_dispatcher_send(self.hass, SIGNAL_UPDATED, timer.id)
        self._event(EVENT_CHANGED, timer)

    def _data(self) -> dict:
        return {"timers": self.book.to_list()}

    def _save(self) -> None:
        self._store.async_delay_save(self._data, 1)
