"""Timers: the model, the book of all timers, and which one a request means.

Pure Python, no Home Assistant imports. Times are POSIX timestamps (float
seconds), passed in explicitly so everything is testable without a clock.
"""

from __future__ import annotations

import difflib
import uuid
from dataclasses import asdict, dataclass, field
from enum import StrEnum


class TimerState(StrEnum):
    RUNNING = "running"
    PAUSED = "paused"
    RINGING = "ringing"


@dataclass
class Timer:
    id: str
    # As set, in seconds. Extensions don't change it, so "the 5-minute timer"
    # keeps meaning the same timer after it was extended.
    duration: float
    created: float
    label: str | None = None
    # Area the timer was set in; where it rings.
    area: str | None = None
    state: TimerState = TimerState.RUNNING
    # Set while running or ringing.
    ends_at: float | None = None
    # Set while paused.
    paused_remaining: float | None = None
    # Net seconds added (negative: shortened).
    extended: float = 0.0

    def remaining(self, now: float) -> float:
        if self.state == TimerState.PAUSED:
            return self.paused_remaining or 0.0
        if self.state == TimerState.RINGING:
            return 0.0
        return max(0.0, (self.ends_at or now) - now)

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict) -> Timer:
        return cls(**{**data, "state": TimerState(data["state"])})


class TimerError(Exception):
    """A request that can't apply to this timer (e.g. pausing a ringing one)."""


@dataclass
class TimerBook:
    timers: dict[str, Timer] = field(default_factory=dict)

    def start(
        self, duration: float, now: float, label: str | None = None, area: str | None = None
    ) -> Timer:
        if duration <= 0:
            raise TimerError("duration must be positive")
        timer = Timer(
            id=uuid.uuid4().hex[:12],
            duration=duration,
            created=now,
            label=normalise_label(label),
            area=area,
            ends_at=now + duration,
        )
        self.timers[timer.id] = timer
        return timer

    def extend(self, timer: Timer, delta: float, now: float) -> None:
        """Add `delta` seconds (negative shortens, but never below 1 s left)."""
        if timer.state == TimerState.RINGING:
            raise TimerError("ringing")
        if timer.state == TimerState.PAUSED:
            new = max(1.0, (timer.paused_remaining or 0.0) + delta)
            timer.extended += new - (timer.paused_remaining or 0.0)
            timer.paused_remaining = new
            return
        left = timer.remaining(now)
        new = max(1.0, left + delta)
        timer.extended += new - left
        timer.ends_at = now + new

    def pause(self, timer: Timer, now: float) -> None:
        if timer.state != TimerState.RUNNING:
            raise TimerError(timer.state)
        timer.paused_remaining = timer.remaining(now)
        timer.ends_at = None
        timer.state = TimerState.PAUSED

    def resume(self, timer: Timer, now: float) -> None:
        if timer.state != TimerState.PAUSED:
            raise TimerError(timer.state)
        timer.ends_at = now + (timer.paused_remaining or 0.0)
        timer.paused_remaining = None
        timer.state = TimerState.RUNNING

    def ring(self, timer: Timer) -> None:
        timer.state = TimerState.RINGING
        timer.paused_remaining = None

    def remove(self, timer: Timer) -> None:
        self.timers.pop(timer.id, None)

    def active(self) -> list[Timer]:
        """Running and paused timers, soonest first."""
        return sorted(
            (t for t in self.timers.values() if t.state != TimerState.RINGING),
            key=lambda t: (t.ends_at or float("inf"), t.created),
        )

    def ringing(self) -> list[Timer]:
        return [t for t in self.timers.values() if t.state == TimerState.RINGING]

    def to_list(self) -> list[dict]:
        return [t.to_dict() for t in self.timers.values()]

    @classmethod
    def from_list(cls, data: list[dict]) -> TimerBook:
        return cls({t["id"]: Timer.from_dict(t) for t in data})


def normalise_label(label: str | None) -> str | None:
    """Label as spoken to label: "Nudel-Timer", "nudeltimer", "den Nudel" -> "Nudel"."""
    if not label:
        return None
    words = label.replace("-", " ").split()
    words = [w for w in words if w.lower() not in _ARTICLES]
    if words and words[-1].lower().endswith("timer"):
        words[-1] = words[-1][: -len("timer")]
    text = " ".join(w for w in words if w).strip()
    return text[:1].upper() + text[1:] if text else None


_ARTICLES = {"der", "die", "das", "den", "dem", "einen", "ein", "eine", "the", "a", "my", "meinen"}


@dataclass
class Selector:
    """What a request said about the timer it means; all parts optional."""

    label: str | None = None
    # "the 5-minute timer": the duration it was set to.
    duration: float | None = None
    # "the one with 3 minutes left".
    remaining: float | None = None
    # Area the request came from; only breaks ties.
    area: str | None = None

    def is_empty(self) -> bool:
        return self.label is None and self.duration is None and self.remaining is None


def resolve(timers: list[Timer], sel: Selector, now: float) -> list[Timer]:
    """The timers `sel` can mean, best first. One result: unambiguous.

    Label, then set duration, then remaining time narrow it down; the area
    only decides between otherwise equal candidates. With nothing said and a
    single timer, that one is meant.
    """
    candidates = list(timers)
    if not candidates:
        return []

    if sel.label:
        wanted = (normalise_label(sel.label) or "").lower()
        scored = [(_label_score(t.label, wanted), t) for t in candidates]
        best = max(score for score, _ in scored)
        if best < 0.75:
            return []
        candidates = [t for score, t in scored if score >= best - 0.05]

    if sel.duration is not None:
        exact = [t for t in candidates if abs(t.duration - sel.duration) < 1]
        if not exact:
            # Also accept the duration including extensions.
            exact = [t for t in candidates if abs(t.duration + t.extended - sel.duration) < 1]
        if not exact:
            return []
        candidates = exact

    if sel.remaining is not None:
        tolerance = max(30.0, sel.remaining * 0.2)
        close = sorted(
            (t for t in candidates if abs(t.remaining(now) - sel.remaining) <= tolerance),
            key=lambda t: abs(t.remaining(now) - sel.remaining),
        )
        if not close:
            return []
        candidates = close[:1] if len(close) == 1 or _clear_winner(close, sel, now) else close

    if len(candidates) > 1 and sel.area:
        same = [t for t in candidates if t.area == sel.area]
        if len(same) == 1:
            return same
    return candidates


def _label_score(label: str | None, wanted: str) -> float:
    if not label:
        return 0.0
    have = label.lower()
    if have == wanted:
        return 1.0
    return difflib.SequenceMatcher(None, have, wanted).ratio()


def _clear_winner(close: list[Timer], sel: Selector, now: float) -> bool:
    """The closest is clearly closer than the runner-up."""
    assert sel.remaining is not None
    first = abs(close[0].remaining(now) - sel.remaining)
    second = abs(close[1].remaining(now) - sel.remaining)
    return second - first >= 15
