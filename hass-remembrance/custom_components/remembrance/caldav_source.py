"""One CalDAV calendar: incremental sync and writes.

Synchronous (the caldav library is); the engine runs it in an executor. No
Home Assistant imports.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field

import caldav

_LOGGER = logging.getLogger(__name__)


class SourceError(Exception):
    """The calendar couldn't be reached or refused a request."""


@dataclass
class Changes:
    # href -> ics text, for new and changed resources.
    changed: dict[str, str] = field(default_factory=dict)
    deleted: list[str] = field(default_factory=list)
    # Everything was fetched anew: resources not in `changed` are gone.
    full: bool = False


class CalDAVSource:
    def __init__(self, url: str, username: str | None, password: str | None) -> None:
        # The calendar's own URL; the library connects to its server from it.
        self._url = url
        self._username = username
        self._password = password
        self._calendar = None
        self._collection = None

    def _cal(self):
        if self._calendar is None:
            client = caldav.DAVClient(self._url, username=self._username, password=self._password)
            self._calendar = client.calendar(url=self._url)
        return self._calendar

    def sync(self) -> Changes:
        """What changed since the last call; the first call fetches everything
        (also after an error, as the sync state is then unknown)."""
        try:
            if self._collection is None:
                collection = self._cal().objects_by_sync_token(load_objects=True)
                self._collection = collection
                return Changes({str(o.url): o.data for o in collection}, full=True)
            updated, deleted = self._collection.sync()
            return Changes({str(o.url): o.data for o in updated}, [str(o.url) for o in deleted])
        except Exception as err:
            self._collection = None
            self._calendar = None
            raise SourceError(str(err)) from err

    def create(self, ics: str) -> str:
        try:
            return str(self._cal().save_event(ics).url)
        except Exception as err:
            self._calendar = None
            raise SourceError(str(err)) from err

    def update(self, href: str, ics: str) -> None:
        try:
            obj = self._cal().event_by_url(href)
            obj.data = ics
            obj.save()
        except Exception as err:
            self._calendar = None
            raise SourceError(str(err)) from err

    def delete(self, href: str) -> None:
        try:
            self._cal().event_by_url(href).delete()
        except Exception as err:
            self._calendar = None
            raise SourceError(str(err)) from err
