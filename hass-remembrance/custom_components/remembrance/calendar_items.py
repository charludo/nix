"""Calendar entries: reading tagged events, planning their rings, writing new ones.

Pure Python on top of icalendar and recurring_ical_events, no Home Assistant.
An entry is one event series (one UID in one calendar resource), tagged with a
category that says what it is (`HomeAssistant Reminder`, `HomeAssistant
Alarm`). It rings at its own reminders (VALARMs) only.
"""

from __future__ import annotations

import uuid
from dataclasses import dataclass, field
from datetime import date, datetime, time, timedelta, tzinfo

import recurring_ical_events
from icalendar import Alarm, Calendar, Event

PRODID = "-//remembrance//Home Assistant//EN"
WEEKDAYS = ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]


@dataclass(frozen=True)
class Ring:
    """One planned ring: an entry's reminder for one occurrence."""

    uid: str
    kind: str
    # Start of the occurrence the reminder belongs to.
    occurrence: datetime
    at: datetime
    # Seconds before the occurrence's start (0: on the dot; negative: after).
    offset: float

    @property
    def key(self) -> str:
        return f"{self.uid}|{self.occurrence.isoformat()}|{self.offset:g}"


@dataclass
class Entry:
    """One tagged event series and the calendar resource it lives in."""

    uid: str
    kind: str
    summary: str
    # The other categories (besides the kind's): which name rooms is up to
    # the caller.
    categories: list[str]
    location: str | None
    # Free text, uninterpreted: what it means is up to the caller (e.g. a
    # playlist to wake up to).
    description: str | None
    start: datetime
    recurring: bool
    cancelled: bool
    # Seconds before the start, as set in the master event's VALARMs.
    alerts: list[float]
    href: str | None = None
    calendar: Calendar = field(repr=False, default=None)  # type: ignore[assignment]

    def to_ical(self) -> str:
        return self.calendar.to_ical().decode()


def _categories(component) -> list[str]:
    raw = component.get("CATEGORIES")
    if raw is None:
        return []
    values = raw if isinstance(raw, list) else [raw]
    names: list[str] = []
    for value in values:
        names.extend(str(c) for c in getattr(value, "cats", [value]))
    return [n.strip() for n in names]


def _aware(value: date | datetime, tz: tzinfo) -> datetime:
    """All-day dates start at local midnight; floating times are local."""
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=tz)
    return datetime.combine(value, time(), tz)


def _alerts(event: Event, start: datetime, end: datetime) -> list[float]:
    """VALARM triggers as seconds before `start`."""
    offsets: list[float] = []
    for alarm in event.walk("VALARM"):
        trigger = alarm.get("TRIGGER")
        if trigger is None:
            continue
        value = trigger.dt
        if isinstance(value, timedelta):
            anchor = end if trigger.params.get("RELATED") == "END" else start
            offsets.append((start - (anchor + value)).total_seconds())
        elif isinstance(value, datetime):
            offsets.append((start - _aware(value, start.tzinfo)).total_seconds())
    return sorted(set(offsets), reverse=True)


def _times(event: Event, tz: tzinfo) -> tuple[datetime, datetime]:
    start = _aware(event.decoded("DTSTART"), tz)
    if "DTEND" in event:
        end = _aware(event.decoded("DTEND"), tz)
    elif "DURATION" in event:
        end = start + event.decoded("DURATION")
    else:
        end = start
    return start, end


def parse(ics: str, categories: dict[str, str], tz: tzinfo, href: str | None = None) -> list[Entry]:
    """Tagged entries in one calendar resource. `categories` maps a kind to
    the category naming it (matched case-insensitively)."""
    calendar = Calendar.from_ical(ics)
    wanted = {name.lower(): kind for kind, name in categories.items()}
    entries: list[Entry] = []
    for event in calendar.walk("VEVENT"):
        if "RECURRENCE-ID" in event:
            continue  # overrides belong to their master
        cats = _categories(event)
        kind = next((wanted[c.lower()] for c in cats if c.lower() in wanted), None)
        if kind is None:
            continue
        start, end = _times(event, tz)
        entries.append(
            Entry(
                uid=str(event.get("UID")),
                kind=kind,
                summary=str(event.get("SUMMARY", "")),
                categories=[c for c in cats if c and c.lower() not in wanted],
                location=str(event["LOCATION"]) if event.get("LOCATION") else None,
                description=str(event["DESCRIPTION"]) if event.get("DESCRIPTION") else None,
                start=start,
                recurring="RRULE" in event or "RDATE" in event,
                cancelled=str(event.get("STATUS", "")).upper() == "CANCELLED",
                alerts=_alerts(event, start, end),
                href=href,
                calendar=calendar,
            )
        )
    return entries


def plan(entry: Entry, start: datetime, end: datetime, tz: tzinfo) -> list[Ring]:
    """The entry's rings from `start` (inclusive) to `end` (exclusive).

    Repeats, exceptions (EXDATE) and changed occurrences (RECURRENCE-ID) come
    from recurring_ical_events; each occurrence rings at its own VALARMs.
    Cancelled series and occurrences don't ring.
    """
    if entry.cancelled:
        return []
    # Occurrences whose reminders can fall into the window: reminders reach
    # back before the start (positive offsets) or after it (negative ones).
    lead = max([0.0, *entry.alerts])
    lag = max([0.0, *(-a for a in entry.alerts)])
    window_start = start - timedelta(seconds=lag)
    window_end = end + timedelta(seconds=lead)
    rings: list[Ring] = []
    query = recurring_ical_events.of(entry.calendar).between(window_start, window_end)
    for occurrence in query:
        if str(occurrence.get("UID")) != entry.uid:
            continue
        if str(occurrence.get("STATUS", "")).upper() == "CANCELLED":
            continue
        occ_start, occ_end = _times(occurrence, tz)
        for offset in _alerts(occurrence, occ_start, occ_end):
            at = occ_start - timedelta(seconds=offset)
            if start <= at < end:
                rings.append(Ring(entry.uid, entry.kind, occ_start, at, offset))
    return sorted(rings, key=lambda r: (r.at, r.offset))


def spans(
    entry: Entry, start: datetime, end: datetime, tz: tzinfo
) -> list[tuple[datetime, datetime]]:
    """(start, end) of the entry's occurrences in the window, cancelled ones skipped."""
    if entry.cancelled:
        return []
    query = recurring_ical_events.of(entry.calendar).between(start, end)
    return sorted(
        _times(o, tz)
        for o in query
        if str(o.get("UID")) == entry.uid and str(o.get("STATUS", "")).upper() != "CANCELLED"
    )


def occurrences(entry: Entry, start: datetime, end: datetime, tz: tzinfo) -> list[datetime]:
    """Starts of the entry's occurrences in the window, cancelled ones skipped."""
    return [s for s, _ in spans(entry, start, end, tz)]


def next_occurrence(
    entry: Entry, after: datetime, tz: tzinfo, horizon_days: int = 400
) -> datetime | None:
    """Start of the first occurrence at or after `after`, cancelled ones skipped."""
    starts = occurrences(entry, after, after + timedelta(days=horizon_days), tz)
    return next((s for s in starts if s >= after), None)


# --- writing -------------------------------------------------------------


def _new_calendar() -> Calendar:
    calendar = Calendar()
    calendar.add("PRODID", PRODID)
    calendar.add("VERSION", "2.0")
    return calendar


def _alarm(offset: float, description: str) -> Alarm:
    alarm = Alarm()
    alarm.add("ACTION", "DISPLAY")
    alarm.add("DESCRIPTION", description)
    alarm.add("TRIGGER", timedelta(seconds=-offset))
    return alarm


def new_event(
    *,
    category: str,
    summary: str,
    start: datetime,
    duration: timedelta,
    alerts: list[float],
    categories: list[str] | None = None,
    location: str | None = None,
    description: str | None = None,
    byday: list[str] | None = None,
    now: datetime,
) -> tuple[str, str]:
    """A new calendar resource with one tagged event: (uid, ics text).

    `alerts` are seconds before the start; `categories` go next to `category`;
    `byday` (MO … SU) makes it repeat
    weekly on those days (daily when all seven).
    """
    uid = f"{uuid.uuid4()}@remembrance"
    if byday:
        # DTSTART is always an occurrence, rule or not: start on a listed day.
        while WEEKDAYS[start.weekday()] not in byday:
            start += timedelta(days=1)
    event = Event()
    event.add("UID", uid)
    event.add("DTSTAMP", now)
    event.add("SUMMARY", summary)
    event.add("DTSTART", start)
    event.add("DTEND", start + duration)
    event.add("CATEGORIES", [category, *(categories or [])])
    if location:
        event.add("LOCATION", location)
    if description:
        event.add("DESCRIPTION", description)
    if byday:
        days = [d for d in WEEKDAYS if d in byday]
        rule = {"FREQ": "DAILY"} if len(days) == 7 else {"FREQ": "WEEKLY", "BYDAY": days}
        event.add("RRULE", rule)
    for offset in alerts:
        event.add_component(_alarm(offset, summary))
    calendar = _new_calendar()
    calendar.add_component(event)
    calendar.add_missing_timezones()
    return uid, calendar.to_ical().decode()


def _master(calendar: Calendar, uid: str) -> Event:
    for event in calendar.walk("VEVENT"):
        if str(event.get("UID")) == uid and "RECURRENCE-ID" not in event:
            return event
    raise KeyError(uid)


def with_exdate(entry: Entry, occurrence: datetime) -> str:
    """The entry's resource with `occurrence` excluded from the series."""
    calendar = Calendar.from_ical(entry.to_ical())
    master = _master(calendar, entry.uid)
    start = master.decoded("DTSTART")
    value = (
        occurrence.astimezone(start.tzinfo)
        if isinstance(start, datetime) and start.tzinfo
        else occurrence
    )
    master.add("EXDATE", value)
    return calendar.to_ical().decode()


def with_status(entry: Entry, cancelled: bool) -> str:
    """The entry's resource with the series cancelled (disabled) or not."""
    calendar = Calendar.from_ical(entry.to_ical())
    master = _master(calendar, entry.uid)
    master.pop("STATUS", None)
    if cancelled:
        master.add("STATUS", "CANCELLED")
    return calendar.to_ical().decode()


def weekday_codes(days: list[str]) -> list[str]:
    """ "mon", "Montag", "MO" … -> "MO"; also "weekdays", "weekend", "daily"."""
    groups = {
        "weekdays": WEEKDAYS[:5],
        "werktags": WEEKDAYS[:5],
        "weekend": WEEKDAYS[5:],
        "wochenende": WEEKDAYS[5:],
        "daily": WEEKDAYS,
        "täglich": WEEKDAYS,
    }
    names = {
        **{d.lower(): d for d in WEEKDAYS},
        **dict(zip(["mon", "tue", "wed", "thu", "fri", "sat", "sun"], WEEKDAYS, strict=True)),
        **dict(
            zip(
                ["montag", "dienstag", "mittwoch", "donnerstag", "freitag", "samstag", "sonntag"],
                WEEKDAYS,
                strict=True,
            )
        ),
    }
    codes: set[str] = set()
    for day in days:
        key = day.strip().lower()
        if key in groups:
            codes.update(groups[key])
        elif key.rstrip("s") in names:
            codes.add(names[key.rstrip("s")])
        elif key in names:
            codes.add(names[key])
        else:
            raise ValueError(f"unknown day: {day}")
    return [d for d in WEEKDAYS if d in codes]
