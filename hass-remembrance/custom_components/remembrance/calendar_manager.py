"""Reminders and alarms from a CalDAV calendar: sync, plan, ring, write.

The calendar is the source of truth; this keeps a cache of it (so rings work
offline), the runtime state per ring (rung, snoozed) and the scheduled rings.
"""

from __future__ import annotations

import difflib
import logging
from dataclasses import dataclass
from datetime import UTC, date, datetime, time, timedelta, tzinfo
from typing import TYPE_CHECKING, Any
from zoneinfo import ZoneInfo

from homeassistant.core import CALLBACK_TYPE, HomeAssistant, callback
from homeassistant.helpers import area_registry as ar
from homeassistant.helpers import entity_registry as er
from homeassistant.helpers.event import async_track_point_in_utc_time, async_track_time_interval

from . import calendar_items as ci
from .caldav_source import CalDAVSource, Changes, SourceError
from .const import (
    CONF_ALARM_CATEGORY,
    CONF_PASSWORD,
    CONF_POLL_INTERVAL,
    CONF_REMINDER_CATEGORY,
    CONF_URL,
    CONF_USERNAME,
    DEFAULT_ALARM_CATEGORY,
    DEFAULT_POLL_INTERVAL,
    DEFAULT_REMINDER_CATEGORY,
    DOMAIN,
    EVENT_MISSED,
    KIND_ALARM,
    KIND_REMINDER,
)
from .timers import Selector

if TYPE_CHECKING:
    from .engine import Engine

_LOGGER = logging.getLogger(__name__)

HORIZON = timedelta(hours=48)
REPLAN_EVERY = timedelta(hours=1)
# Rung keys older than this are forgotten.
RUNG_KEEP = timedelta(days=8)
EVENT_LENGTH = {KIND_REMINDER: timedelta(minutes=15), KIND_ALARM: timedelta(minutes=5)}


def _norm(text: str) -> str:
    return " ".join(
        text.lower()
        .replace("-", " ")
        .replace("ü", "ue")
        .replace("ö", "oe")
        .replace("ä", "ae")
        .replace("ß", "ss")
        .split()
    )


@dataclass
class Snooze:
    uid: str
    occurrence: datetime
    at: datetime

    def to_dict(self) -> dict:
        return {
            "uid": self.uid,
            "occurrence": self.occurrence.isoformat(),
            "at": self.at.isoformat(),
        }

    @classmethod
    def from_dict(cls, data: dict) -> Snooze:
        return cls(
            data["uid"],
            datetime.fromisoformat(data["occurrence"]),
            datetime.fromisoformat(data["at"]),
        )


class CalendarManager:
    def __init__(self, hass: HomeAssistant, engine: Engine, config: dict) -> None:
        self.hass = hass
        self.engine = engine
        self.config = config
        self.categories = {
            KIND_REMINDER: config.get(CONF_REMINDER_CATEGORY, DEFAULT_REMINDER_CATEGORY),
            KIND_ALARM: config.get(CONF_ALARM_CATEGORY, DEFAULT_ALARM_CATEGORY),
        }
        self.source = CalDAVSource(
            config[CONF_URL],
            config.get(CONF_USERNAME),
            config.get(CONF_PASSWORD),
        )
        # href -> ics text: the cache of the calendar's resources.
        self.resources: dict[str, str] = {}
        self.entries: dict[str, ci.Entry] = {}
        self.rung: dict[str, float] = {}
        self.snoozes: list[Snooze] = []
        self.online = False
        # When this ran last (from the stored state): rings between then and
        # now never rang and are reported as missed.
        self._last_seen: datetime | None = None
        self._scheduled: dict[str, CALLBACK_TYPE] = {}
        self._unsubs: list[CALLBACK_TYPE] = []

    # --- lifecycle -------------------------------------------------------

    @property
    def tz(self) -> tzinfo:
        return ZoneInfo(self.hass.config.time_zone)

    def load(self, data: dict) -> None:
        self.resources = dict(data.get("resources", {}))
        self.rung = dict(data.get("rung", {}))
        self.snoozes = [Snooze.from_dict(s) for s in data.get("snoozes", [])]
        if seen := data.get("last_seen"):
            self._last_seen = datetime.fromisoformat(seen)
        self._reparse()

    def data(self) -> dict:
        return {
            "resources": self.resources,
            "rung": self.rung,
            "snoozes": [s.to_dict() for s in self.snoozes],
            "last_seen": datetime.now(UTC).isoformat(),
        }

    async def async_start(self) -> None:
        self.replan(startup=True)
        await self.async_sync()
        interval = timedelta(seconds=self.config.get(CONF_POLL_INTERVAL, DEFAULT_POLL_INTERVAL))
        self._unsubs.append(async_track_time_interval(self.hass, self._poll, interval))
        self._unsubs.append(async_track_time_interval(self.hass, self._replan_tick, REPLAN_EVERY))

    def stop(self) -> None:
        for unsub in [*self._unsubs, *self._scheduled.values()]:
            unsub()
        self._unsubs.clear()
        self._scheduled.clear()

    async def _poll(self, _now: datetime) -> None:
        await self.async_sync()

    @callback
    def _replan_tick(self, _now: datetime) -> None:
        self.replan()

    async def async_sync(self) -> bool:
        try:
            changes: Changes = await self.hass.async_add_executor_job(self.source.sync)
        except SourceError as err:
            if self.online:
                _LOGGER.warning("calendar unreachable, using the cached copy: %s", err)
            self.online = False
            return False
        self.online = True
        if changes.full:
            self.resources = dict(changes.changed)
        else:
            for href in changes.deleted:
                self.resources.pop(href, None)
            self.resources.update(changes.changed)
        if changes.full or changes.changed or changes.deleted:
            self._reparse()
            self.replan()
            self.engine.calendar_changed()
        return True

    def _reparse(self) -> None:
        entries: dict[str, ci.Entry] = {}
        for href, text in self.resources.items():
            try:
                for entry in ci.parse(text, self.categories, self.tz, href=href):
                    entries[entry.uid] = entry
            except Exception as err:  # a broken resource shouldn't stop the rest
                _LOGGER.warning("skipping unreadable calendar resource %s: %s", href, err)
        for entry in entries.values():
            if not entry.alerts and not entry.cancelled:
                _LOGGER.info("%r is tagged but has no reminder; it won't ring", entry.summary)
        self.entries = entries

    # --- planning --------------------------------------------------------

    def replan(self, *, startup: bool = False) -> None:
        """Schedule every ring from now to the horizon; on startup also ring
        what was missed within the grace period, and report older ones."""
        for unsub in self._scheduled.values():
            unsub()
        self._scheduled.clear()
        now = datetime.now(UTC)
        cutoff = now.timestamp() - RUNG_KEEP.total_seconds()
        self.rung = {k: t for k, t in self.rung.items() if t >= cutoff}
        grace = timedelta(seconds=self.engine.missed_grace)
        start = now - (grace if startup else timedelta(0))
        for entry in self.entries.values():
            for ring in ci.plan(entry, start, now + HORIZON, self.tz):
                self._schedule(ring, entry, now, grace)
        for snooze in list(self.snoozes):
            entry = self.entries.get(snooze.uid)
            if entry is None:
                self.snoozes.remove(snooze)
                continue
            ring = ci.Ring(
                entry.uid, entry.kind, snooze.occurrence, snooze.at, self._snooze_offset(snooze)
            )
            self._schedule(ring, entry, now, grace, snooze=snooze)
        if startup and self._last_seen:
            self._report_missed(self._last_seen, now - grace)
        self.engine.save()

    def _snooze_offset(self, snooze: Snooze) -> float:
        return (snooze.occurrence - snooze.at).total_seconds()

    def _schedule(
        self,
        ring: ci.Ring,
        entry: ci.Entry,
        now: datetime,
        grace: timedelta,
        snooze: Snooze | None = None,
    ) -> None:
        key = f"snooze|{ring.key}|{ring.at.isoformat()}" if snooze else ring.key
        if key in self.rung or key in self._scheduled:
            return
        if ring.at <= now:
            if now - ring.at <= grace:
                self.hass.async_create_task(self._fire_async(key, ring, snooze))
            return

        @callback
        def fire(_now: datetime) -> None:
            self._scheduled.pop(key, None)
            self.hass.async_create_task(self._fire_async(key, ring, snooze))

        self._scheduled[key] = async_track_point_in_utc_time(
            self.hass, fire, ring.at.astimezone(UTC)
        )

    def _report_missed(self, since: datetime, until: datetime) -> None:
        """Rings from `since` (the last run) to `until` that never rang."""
        now = datetime.now(UTC)
        since = max(since, now - RUNG_KEEP)
        for entry in self.entries.values():
            for ring in ci.plan(entry, since, until, self.tz):
                if ring.key not in self.rung:
                    self.rung[ring.key] = now.timestamp()
                    self.hass.bus.async_fire(EVENT_MISSED, self.item(entry, ring=ring))

    async def _fire_async(self, key: str, ring: ci.Ring, snooze: Snooze | None) -> None:
        entry = self.entries.get(ring.uid)
        if entry is None or entry.cancelled or key in self.rung:
            return
        self.rung[key] = datetime.now(UTC).timestamp()
        if snooze and snooze in self.snoozes:
            self.snoozes.remove(snooze)
        self.engine.ring_calendar(entry, ring)

    # --- items -----------------------------------------------------------

    def areas_of(self, entry: ci.Entry) -> list[str]:
        """The areas the entry's categories name (an area's id, name or alias,
        ignoring case); other categories are left alone."""
        names = {
            _norm(name): area.id
            for area in ar.async_get(self.hass).async_list_areas()
            for name in [area.id, area.name, *area.aliases]
        }
        found = [names[n] for c in entry.categories if (n := _norm(c)) in names]
        return list(dict.fromkeys(found))

    def rings(self, entry: ci.Entry, start: datetime, end: datetime) -> list[ci.Ring]:
        """The entry's rings still to come in the window, snoozes included."""
        planned = [r for r in ci.plan(entry, start, end, self.tz) if r.key not in self.rung]
        snoozed = [
            ci.Ring(entry.uid, entry.kind, s.occurrence, s.at, self._snooze_offset(s))
            for s in self.snoozes
            if s.uid == entry.uid and start <= s.at < end
        ]
        return sorted([*planned, *snoozed], key=lambda r: r.at)

    def next_ring(self, entry: ci.Entry, after: datetime) -> ci.Ring | None:
        return next(iter(self.rings(entry, after, after + timedelta(days=60))), None)

    def item(
        self, entry: ci.Entry, ring: ci.Ring | None = None, occurrence: datetime | None = None
    ) -> dict[str, Any]:
        """The entry as the services, events and the ring script see it. With
        `ring`: about that ring, incl. the next one of the same occurrence."""
        now = datetime.now(UTC)
        upcoming = self.next_ring(entry, now)
        occ = ring.occurrence if ring else occurrence or ci.next_occurrence(entry, now, self.tz)
        # The next ring of the same occurrence (reminders: "I'll remind you again").
        following = (
            next(
                (
                    r
                    for r in self.rings(
                        entry, ring.at + timedelta(seconds=1), ring.occurrence + timedelta(days=1)
                    )
                    if r.occurrence == ring.occurrence
                ),
                None,
            )
            if ring
            else None
        )
        item = {
            "id": entry.uid,
            "kind": entry.kind,
            "label": entry.summary,
            "location": entry.location,
            "description": entry.description,
            "areas": self.areas_of(entry),
            "state": "ringing"
            if self.engine.is_ringing(entry.uid)
            else ("disabled" if entry.cancelled else "scheduled"),
            "recurring": entry.recurring,
            "enabled": not entry.cancelled,
            "start": occ.isoformat() if occ else None,
            "alerts": entry.alerts,
            "next_ring": upcoming.at.isoformat() if upcoming else None,
            "entity_id": self._entity_id(entry),
        }
        if ring:
            item["offset"] = ring.offset
            item["next_offset"] = following.offset if following else None
            item["next_ring_of_occurrence"] = following.at.isoformat() if following else None
        return item

    def _entity_id(self, entry: ci.Entry) -> str | None:
        if entry.kind != KIND_ALARM or not entry.recurring:
            return None
        return er.async_get(self.hass).async_get_entity_id("switch", DOMAIN, f"alarm_{entry.uid}")

    def occurrences(
        self, start: datetime, end: datetime, kind: str | None = None
    ) -> list[tuple[ci.Entry, datetime, datetime]]:
        """(entry, start, end) for every tagged occurrence in the window."""
        found: list[tuple[ci.Entry, datetime, datetime]] = []
        for entry in self.entries.values():
            if kind and entry.kind != kind or entry.cancelled:
                continue
            for occ_start, occ_end in ci.spans(entry, start, end, self.tz):
                found.append((entry, occ_start, occ_end))
        return sorted(found, key=lambda p: p[1])

    def select(
        self, sel: Selector, ids: list[str], all_: bool, kind: str | None, at_time: time | None
    ) -> list[ci.Entry]:
        pool = [e for e in self.entries.values() if kind is None or e.kind == kind]
        if ids:
            return [e for e in pool if e.uid in ids]
        if all_:
            return pool
        if at_time is not None:
            pool = [
                e
                for e in pool
                if (occ := ci.next_occurrence(e, datetime.now(UTC), self.tz) or e.start)
                and occ.astimezone(self.tz).time().replace(second=0) == at_time.replace(second=0)
            ]
        if sel.label:
            wanted = _norm(sel.label)
            scored = [
                (difflib.SequenceMatcher(None, _norm(e.summary), wanted).ratio(), e) for e in pool
            ]
            best = max((s for s, _ in scored), default=0)
            if best < 0.75:
                return []
            pool = [e for s, e in scored if s >= best - 0.05]
        if len(pool) > 1 and sel.area:
            same = [e for e in pool if sel.area in self.areas_of(e)]
            if len(same) == 1:
                return same
        return pool

    # --- writes ----------------------------------------------------------

    def area_name(self, area: str | None) -> str | None:
        if not area:
            return None
        found = ar.async_get(self.hass).async_get_area(area)
        return found.name if found else area

    async def async_create(
        self,
        kind: str,
        summary: str,
        start: datetime,
        alerts: list[float],
        area: str | None,
        byday: list[str] | None = None,
        description: str | None = None,
    ) -> ci.Entry:
        uid, text = ci.new_event(
            category=self.categories[kind],
            summary=summary,
            start=start,
            duration=EVENT_LENGTH[kind],
            alerts=alerts,
            categories=[name] if (name := self.area_name(area)) else None,
            description=description,
            byday=byday,
            now=datetime.now(UTC),
        )
        href = await self.hass.async_add_executor_job(self.source.create, text)
        self._apply(href, text)
        return self.entries[uid]

    async def async_rewrite(self, entry: ci.Entry, text: str) -> ci.Entry:
        assert entry.href
        await self.hass.async_add_executor_job(self.source.update, entry.href, text)
        self._apply(entry.href, text)
        return self.entries[entry.uid]

    async def async_delete(self, entry: ci.Entry) -> None:
        assert entry.href
        await self.hass.async_add_executor_job(self.source.delete, entry.href)
        self.resources.pop(entry.href, None)
        self.snoozes = [s for s in self.snoozes if s.uid != entry.uid]
        self._reparse()
        self.replan()

    def _apply(self, href: str, text: str) -> None:
        self.resources[href] = text
        self._reparse()
        self.replan()

    def snooze(self, entry: ci.Entry, occurrence: datetime, delay: float) -> Snooze:
        snooze = Snooze(entry.uid, occurrence, datetime.now(UTC) + timedelta(seconds=delay))
        self.snoozes.append(snooze)
        self.replan()
        return snooze


def local_datetime(value: datetime | date | str, tz: tzinfo) -> datetime:
    """Naive times are local."""
    if isinstance(value, str):
        value = datetime.fromisoformat(value)
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=tz)
    return datetime.combine(value, time(), tz)
