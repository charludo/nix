"""The tagged calendar entries as an HA calendar (read-only; edit them in the
calendar itself or through the services)."""

from __future__ import annotations

from datetime import datetime, timedelta

from homeassistant.components.calendar import CalendarEntity, CalendarEvent
from homeassistant.core import HomeAssistant, callback
from homeassistant.helpers.dispatcher import async_dispatcher_connect
from homeassistant.helpers.entity_platform import AddEntitiesCallback

from .const import DOMAIN, SIGNAL_UPDATED
from .engine import Engine


async def async_setup_platform(
    hass: HomeAssistant, config, async_add_entities: AddEntitiesCallback, discovery_info=None
) -> None:
    async_add_entities([RemembranceCalendar(hass.data[DOMAIN])])


class RemembranceCalendar(CalendarEntity):
    _attr_name = "Remembrance"
    _attr_unique_id = "calendar"
    _attr_icon = "mdi:calendar-clock"
    _attr_should_poll = False

    def __init__(self, engine: Engine) -> None:
        self.engine = engine
        self.entity_id = f"calendar.{DOMAIN}"

    async def async_added_to_hass(self) -> None:
        @callback
        def update(_changed_id: str | None = None) -> None:
            self.async_write_ha_state()

        self.async_on_remove(async_dispatcher_connect(self.hass, SIGNAL_UPDATED, update))

    def _events(self, start: datetime, end: datetime) -> list[CalendarEvent]:
        manager = self.engine.calendar
        if manager is None:
            return []
        events = []
        for entry, occ_start, occ_end in manager.occurrences(start, end):
            events.append(
                CalendarEvent(
                    start=occ_start,
                    # As long as in the calendar; a minute when it has no end.
                    end=max(occ_end, occ_start + timedelta(minutes=1)),
                    summary=entry.summary,
                    location=entry.location,
                    description=entry.kind,
                    uid=entry.uid,
                )
            )
        return events

    @property
    def event(self) -> CalendarEvent | None:
        now = datetime.now().astimezone()
        upcoming = self._events(now, now + timedelta(days=30))
        return upcoming[0] if upcoming else None

    async def async_get_events(
        self, hass: HomeAssistant, start_date: datetime, end_date: datetime
    ) -> list[CalendarEvent]:
        return self._events(start_date, end_date)
