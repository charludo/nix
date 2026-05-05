"""Unit tests for the pure-Python matching logic.

Run with: nix-shell -p 'python3.withPackages (p: [ p.pytest p.rapidfuzz ])' --run pytest
"""

from __future__ import annotations

import sys
from pathlib import Path

# Add the package's *internal* directory so we can import const.py and
# matching.py directly without triggering the package __init__.py (which
# pulls in voluptuous + homeassistant).
sys.path.insert(
    0, str(Path(__file__).resolve().parent.parent / "custom_components" / "closest_intent")
)

from const import SLOT_WILDCARD  # type: ignore  # noqa: E402
from matching import (  # type: ignore  # noqa: E402
    Candidate,
    build_canonical,
    expand_pattern,
    extract_slots,
    find_best,
    score,
)


# ---------------------------------------------------------------------------
# expand_pattern
# ---------------------------------------------------------------------------


def test_expand_no_syntax() -> None:
    out = expand_pattern("Wie spät ist es", cap=16)
    assert out == [("wie spät ist es", [])]


def test_expand_alternatives() -> None:
    texts = [t for (t, _) in expand_pattern("(Hallo|Guten Tag)", cap=16)]
    assert "hallo" in texts
    assert "guten tag" in texts


def test_expand_optional() -> None:
    texts = [t for (t, _) in expand_pattern("Pumpe [an]", cap=16)]
    assert "pumpe" in texts
    assert "pumpe an" in texts


def test_expand_combined() -> None:
    texts = {t for (t, _) in expand_pattern("(Schalte|Mache) [die ]Pumpe an", cap=16)}
    assert "schalte pumpe an" in texts
    assert "mache die pumpe an" in texts


def test_expand_cap_zero_disables_expansion() -> None:
    out = expand_pattern("(a|b) [c] d", cap=0)
    assert len(out) == 1
    assert out[0][0] == "a c d"


def test_expand_records_slots_in_order() -> None:
    out = expand_pattern("Wetter um {stunde} Uhr am {tag}", cap=16)
    for _, slots in out:
        assert slots == ["stunde", "tag"]
    assert all(SLOT_WILDCARD in t for (t, _) in out)


def test_expand_records_slots_with_list_reference() -> None:
    # `{name:list}` syntax is also supported; only the name is captured.
    out = expand_pattern("Wetter um {stunde:time} Uhr", cap=16)
    for _, slots in out:
        assert slots == ["stunde"]


# ---------------------------------------------------------------------------
# score
# ---------------------------------------------------------------------------


def test_score_handles_typos() -> None:
    assert score("pumpr an", "pumpe an") >= 70


def test_score_handles_intra_word_truncation() -> None:
    assert score("shuffl an", "shuffle an") >= 70


def test_score_unrelated_with_shared_short_token() -> None:
    pumpe = score("schaffeln aus", "pumpe aus")
    shuffle = score("schaffeln aus", "shuffle aus")
    assert shuffle > pumpe
    assert pumpe < 70


def test_score_handles_extra_words() -> None:
    assert score("schalte mal die pumpe an", "schalte die pumpe an") >= 80


def test_score_ignores_slot_wildcard() -> None:
    cand = f"wie ist das wetter um {SLOT_WILDCARD} uhr"
    assert score("wie ist das wetter um zwölf uhr", cand) >= 80


# ---------------------------------------------------------------------------
# find_best
# ---------------------------------------------------------------------------


def test_find_best_picks_highest() -> None:
    cands = [
        Candidate(intent="A", pattern_idx=0, text="schalte das licht an"),
        Candidate(intent="B", pattern_idx=0, text="pumpe an"),
    ]
    res = find_best("pumpr an", cands, threshold=60)
    assert res is not None
    assert res[0].intent == "B"


def test_find_best_below_threshold() -> None:
    cands = [Candidate(intent="A", pattern_idx=0, text="hallo welt")]
    assert find_best("purple banana", cands, threshold=70) is None


# ---------------------------------------------------------------------------
# extract_slots
# ---------------------------------------------------------------------------


def test_extract_slots_returns_empty_for_no_slots() -> None:
    cand = Candidate(intent="X", pattern_idx=0, text="pumpe an")
    assert extract_slots("pumpe an", cand) == []


def test_extract_slots_returns_raw_text() -> None:
    # No coercion: whatever lies between the surrounding fixed tokens
    # is captured verbatim. HA's Hassil resolves number words / digits
    # downstream when the canonical sentence is forwarded.
    cand = Candidate(
        intent="WetterStunde",
        pattern_idx=0,
        text=f"wie ist das wetter um {SLOT_WILDCARD} uhr",
        slot_names=["stunde"],
    )
    assert extract_slots("wie ist das wetter um zwölf uhr", cand) == ["zwölf"]
    assert extract_slots("wie ist das wetter um 14 uhr", cand) == ["14"]


def test_extract_slots_two_slots() -> None:
    cand = Candidate(
        intent="X",
        pattern_idx=0,
        text=f"wetter am {SLOT_WILDCARD} um {SLOT_WILDCARD} uhr",
        slot_names=["tag", "stunde"],
    )
    assert extract_slots("wetter am freitag um 12 uhr", cand) == ["freitag", "12"]


# ---------------------------------------------------------------------------
# build_canonical
# ---------------------------------------------------------------------------


def test_build_canonical_passthrough_no_slots() -> None:
    cand = Candidate(intent="X", pattern_idx=0, text="pumpe an")
    assert build_canonical(cand, []) == "pumpe an"


def test_build_canonical_substitutes_slot() -> None:
    cand = Candidate(
        intent="WetterStunde",
        pattern_idx=0,
        text=f"wie ist das wetter um {SLOT_WILDCARD} uhr",
        slot_names=["stunde"],
    )
    assert build_canonical(cand, ["zwölf"]) == "wie ist das wetter um zwölf uhr"
    assert build_canonical(cand, ["14"]) == "wie ist das wetter um 14 uhr"


def test_build_canonical_handles_multiple_slots() -> None:
    cand = Candidate(
        intent="X",
        pattern_idx=0,
        text=f"a {SLOT_WILDCARD} b {SLOT_WILDCARD} c",
        slot_names=["x", "y"],
    )
    assert build_canonical(cand, ["foo", "bar"]) == "a foo b bar c"
