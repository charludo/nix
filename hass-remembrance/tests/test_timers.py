import pytest

from remembrance.timers import (
    Selector,
    TimerBook,
    TimerError,
    TimerState,
    normalise_label,
    resolve,
)

MIN = 60.0


@pytest.fixture
def book():
    return TimerBook()


def test_start_and_remaining(book):
    t = book.start(5 * MIN, now=1000)
    assert t.state == TimerState.RUNNING
    assert t.remaining(1000 + 60) == 4 * MIN
    assert t.remaining(1000 + 600) == 0


def test_extend_keeps_set_duration(book):
    t = book.start(5 * MIN, now=0)
    book.extend(t, MIN, now=120)
    assert t.remaining(120) == 4 * MIN
    assert t.duration == 5 * MIN
    assert t.extended == MIN


def test_shorten_never_below_one_second(book):
    t = book.start(MIN, now=0)
    book.extend(t, -10 * MIN, now=30)
    assert t.remaining(30) == 1


def test_pause_resume(book):
    t = book.start(5 * MIN, now=0)
    book.pause(t, now=60)
    assert t.state == TimerState.PAUSED
    assert t.remaining(10_000) == 4 * MIN
    book.extend(t, MIN, now=10_000)
    assert t.remaining(10_000) == 5 * MIN
    book.resume(t, now=20_000)
    assert t.remaining(20_000) == 5 * MIN


def test_pause_ringing_fails(book):
    t = book.start(MIN, now=0)
    book.ring(t)
    with pytest.raises(TimerError):
        book.pause(t, now=61)
    with pytest.raises(TimerError):
        book.extend(t, MIN, now=61)


def test_roundtrip(book):
    a = book.start(5 * MIN, now=0, label="Nudeln", area="kueche")
    book.pause(book.start(MIN, now=0), now=10)
    again = TimerBook.from_list(book.to_list())
    assert again.timers[a.id] == a
    assert {t.state for t in again.timers.values()} == {TimerState.RUNNING, TimerState.PAUSED}


@pytest.mark.parametrize(
    ("raw", "label"),
    [
        ("Nudel-Timer", "Nudel"),
        ("nudeltimer", "Nudel"),
        ("den Nudel Timer", "Nudel"),
        ("Pizza", "Pizza"),
        ("Timer", None),
        ("", None),
        (None, None),
    ],
)
def test_normalise_label(raw, label):
    assert normalise_label(raw) == label


def three(book):
    five = book.start(5 * MIN, now=0, area="kueche")
    ten = book.start(10 * MIN, now=0, area="wohnzimmer")
    pasta = book.start(8 * MIN, now=0, label="Nudel", area="kueche")
    return five, ten, pasta


def test_resolve_by_set_duration(book):
    five, _, _ = three(book)
    assert resolve(book.active(), Selector(duration=5 * MIN), now=0) == [five]


def test_resolve_by_duration_after_extension(book):
    five, _, _ = three(book)
    book.extend(five, MIN, now=0)
    # Still "the 5-minute timer", and also "the 6-minute timer".
    assert resolve(book.active(), Selector(duration=5 * MIN), now=0) == [five]
    assert resolve(book.active(), Selector(duration=6 * MIN), now=0) == [five]


def test_resolve_by_label_fuzzy(book):
    _, _, pasta = three(book)
    assert resolve(book.active(), Selector(label="Nudeln"), now=0) == [pasta]
    assert resolve(book.active(), Selector(label="Nudeltimer"), now=0) == [pasta]
    assert resolve(book.active(), Selector(label="Pizza"), now=0) == []


def test_resolve_by_remaining(book):
    five, ten, _ = three(book)
    assert resolve(book.active(), Selector(remaining=3 * MIN), now=2 * MIN) == [five]
    assert resolve(book.active(), Selector(remaining=8 * MIN), now=2 * MIN) == [ten]


def test_resolve_unknown_duration(book):
    three(book)
    assert resolve(book.active(), Selector(duration=7 * MIN), now=0) == []


def test_resolve_single_timer_needs_no_selector(book):
    only = book.start(MIN, now=0)
    assert resolve(book.active(), Selector(), now=0) == [only]


def test_resolve_ambiguous_then_area(book):
    a = book.start(5 * MIN, now=0, area="kueche")
    b = book.start(5 * MIN, now=0, area="wohnzimmer")
    assert set(map(id, resolve(book.active(), Selector(duration=5 * MIN), now=0))) == {id(a), id(b)}
    assert resolve(book.active(), Selector(duration=5 * MIN, area="kueche"), now=0) == [a]
    # Nothing said: the area alone picks among several.
    assert resolve(book.active(), Selector(area="wohnzimmer"), now=0) == [b]


def test_active_sorted_soonest_first(book):
    later = book.start(10 * MIN, now=0)
    sooner = book.start(MIN, now=0)
    paused = book.start(2 * MIN, now=0)
    book.pause(paused, now=0)
    assert book.active() == [sooner, later, paused]
