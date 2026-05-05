"""Hassil-pattern expansion + RapidFuzz scoring + slot extraction.

Pure-Python, no Home Assistant imports. Unit-testable on its own.
Language-agnostic: never inspects or coerces slot values, only captures
the text the user spoke between fixed parts of the pattern.

Optionally augmented by a :class:`Resolver` that holds Hassil expansion
rules (``<rule>`` references) and slot-list values (``{list}`` look-ups).
When passed in, patterns get richer pre-expansion (so user patterns that
reference HA built-in rules like ``<stelle>`` actually score correctly)
and captured slot text gets fuzz-resolved against the slot list (so
``"wohnzma"`` becomes ``"Wohnzimmer"`` before being substituted into the
canonical sentence).
"""

from __future__ import annotations

import logging
import re
from dataclasses import dataclass, field
from typing import Iterable, Optional

from rapidfuzz import fuzz

# Importable both as part of the package and as a standalone module (tests).
try:
    from .const import SLOT_WILDCARD
except ImportError:  # pragma: no cover
    from const import SLOT_WILDCARD  # type: ignore

_LOGGER = logging.getLogger(__name__)

# `{list}` or `{list:capture}` — Hassil's syntax. We capture the LIST
# name (group 1); the optional capture name (group 2) is for HA's own
# downstream slot capture and we don't need to track it.
_SLOT_RE = re.compile(r"\{([a-zA-Z_][a-zA-Z0-9_]*)(?::[a-zA-Z_][a-zA-Z0-9_]*)?\}")
# `<rule_name>` — expansion-rule reference.
_RULE_RE = re.compile(r"<([a-zA-Z_][a-zA-Z0-9_]*)>")
_ALT_RE = re.compile(r"\(([^()]+)\)")
_OPT_RE = re.compile(r"\[([^\[\]]+)\]")


# ---------------------------------------------------------------------------
# Resolver
# ---------------------------------------------------------------------------


@dataclass
class Resolver:
    """Pre-computed pools for ``<rule>`` and ``{list}`` references.

    - ``expansion_rules``: rule name → list of surface forms. Each form
      is a string that can match against user input.
    - ``slot_values``: list name → list of acceptable values. Used to
      fuzz-resolve captured slot text into a value Hassil will accept.
    """

    expansion_rules: dict[str, list[str]] = field(default_factory=dict)
    slot_values: dict[str, list[str]] = field(default_factory=dict)

    def inline_rules(self, pattern: str) -> str:
        """Replace ``<rule>`` references in ``pattern`` with ``(form1|form2|…)``.

        Recursive — rules whose definitions reference other rules get
        resolved transitively. References to undefined rules are left
        untouched.
        """
        seen_in_chain: set[str] = set()
        return self._inline_rules_inner(pattern, seen_in_chain, depth=0)

    def _inline_rules_inner(
        self, pattern: str, seen: set[str], depth: int
    ) -> str:
        if depth > 10:
            return pattern  # cycle guard

        def sub(m: re.Match[str]) -> str:
            rule = m.group(1)
            if rule in seen or rule not in self.expansion_rules:
                return m.group(0)
            forms = self.expansion_rules[rule]
            if not forms:
                return m.group(0)
            inner = "(" + "|".join(forms) + ")"
            return self._inline_rules_inner(inner, seen | {rule}, depth + 1)

        return _RULE_RE.sub(sub, pattern)

    def resolve_slot(
        self, captured: str, list_name: Optional[str], threshold: int = 70
    ) -> str:
        """Fuzz-match ``captured`` against the ``list_name`` values.

        Returns the closest known value if it scores above ``threshold``;
        otherwise returns ``captured`` unchanged so the canonical sentence
        carries through the user's original speech (and Hassil downstream
        either resolves it via its own rules or politely fails).
        """
        if not captured or not list_name:
            return captured
        values = self.slot_values.get(list_name)
        if not values:
            return captured

        captured_norm = captured.strip().lower()
        # Direct match short-circuit.
        for v in values:
            if v.lower() == captured_norm:
                return v

        best: Optional[str] = None
        best_score = 0
        for v in values:
            s = int(fuzz.token_sort_ratio(captured_norm, v.lower()))
            if s > best_score:
                best, best_score = v, s
        if best is not None and best_score >= threshold:
            return best
        return captured


# ---------------------------------------------------------------------------
# Candidate
# ---------------------------------------------------------------------------


@dataclass
class Candidate:
    """One expanded sentence pattern, ready for scoring + slot extraction."""

    intent: str
    """Intent name (e.g. ``WetterStunde``)."""

    pattern_idx: int
    """Index into the intent's original pattern list (for debugging)."""

    text: str
    """Flattened text used for scoring. ``SLOT_WILDCARD`` stands in for slots."""

    slot_names: list[str] = field(default_factory=list)
    """Per Hassil's ``{LIST:CAPTURE}`` syntax, this is the *list* name in
    each slot position. Used to look up resolver values; HA's downstream
    capture-name (CAPTURE in the pattern) is its own concern."""

    @property
    def has_slots(self) -> bool:
        return bool(self.slot_names)


# ---------------------------------------------------------------------------
# Pattern expansion
# ---------------------------------------------------------------------------


def expand_pattern(
    pattern: str,
    cap: int,
    resolver: Optional[Resolver] = None,
) -> list[tuple[str, list[str]]]:
    """Expand a Hassil-style pattern into ``[(text, slot_lists), …]``.

    Handles ``[optional]``, ``(a|b|c)``, ``{slot}``/``{slot:capture}`` and,
    if a ``resolver`` is supplied, ``<rule>`` references (inlined into
    alternatives before ordinary expansion runs).

    Returns a list of ``(text, slot_list_names)`` tuples; ``slot_list_names``
    has one entry per ``SLOT_WILDCARD`` in the text, in left-to-right order.
    """
    if resolver is not None:
        pattern = resolver.inline_rules(pattern)

    slot_lists: list[str] = []

    def _slot_sub(m: re.Match[str]) -> str:
        slot_lists.append(m.group(1))
        return f" {SLOT_WILDCARD} "

    pat = _SLOT_RE.sub(_slot_sub, pattern)

    if cap == 0:
        text = _ALT_RE.sub(lambda m: m.group(1).split("|")[0], pat)
        text = _OPT_RE.sub(lambda m: m.group(1), text)
        return [(_normalise(text), list(slot_lists))]

    variants: list[str] = [pat]
    while True:
        new_variants: list[str] = []
        changed = False
        for v in variants:
            m_alt = _ALT_RE.search(v)
            m_opt = _OPT_RE.search(v)
            chosen = None
            if m_alt and m_opt:
                chosen = m_alt if m_alt.start() < m_opt.start() else m_opt
            else:
                chosen = m_alt or m_opt
            if chosen is None:
                new_variants.append(v)
                continue
            changed = True
            before, after = v[: chosen.start()], v[chosen.end() :]
            if chosen is m_alt:
                opts = chosen.group(1).split("|")
            else:  # optional
                opts = ["", chosen.group(1)]
            for o in opts:
                new_variants.append(before + o + after)
            if len(new_variants) >= cap:
                break
        variants = new_variants[:cap]
        if not changed:
            break

    out = []
    seen: set[str] = set()
    for v in variants:
        text = _normalise(v)
        if text in seen:
            continue
        seen.add(text)
        out.append((text, list(slot_lists)))
        if len(out) >= cap:
            break
    return out


def _normalise(s: str) -> str:
    """Lowercase, strip extraneous whitespace and trailing punctuation."""
    s = re.sub(r"\s+", " ", s).strip().lower()
    s = s.rstrip("?.!,;:")
    return s


# ---------------------------------------------------------------------------
# Scoring
# ---------------------------------------------------------------------------


def score(user_text: str, candidate_text: str) -> int:
    """Similarity 0..100 with the slot wildcard ignored.

    Two regimes, picked by whether the candidate contains slot positions:

    - **No slots**: ``token_sort_ratio`` on the whole phrase. Order-tolerant
      and character-level, but penalises extra/missing tokens — exactly
      what we want when both sides are supposed to express the same thing
      (e.g. ``"shuffl an"`` ↔ ``"shuffle an"``).

    - **With slots**: ``partial_ratio`` on the candidate's *fixed parts*
      against the full user text. Finds the best contiguous window of
      the fixed parts within the user input, so whatever the user said
      in the slot position(s) doesn't drag the score down. Critical when
      the slot value is multi-token (``"Wohn Zimmern"``) or has typos in
      the fixed parts (``"tst zwei im Wohnzimmer"``).
    """
    user_norm = _normalise(user_text)
    cand_stripped = re.sub(
        r"\s+", " ", candidate_text.replace(SLOT_WILDCARD, " ")
    ).strip()

    if SLOT_WILDCARD in candidate_text:
        if not cand_stripped:
            return 0
        return int(fuzz.partial_ratio(user_norm, cand_stripped))

    return int(fuzz.token_sort_ratio(user_norm, cand_stripped))


def find_best(
    user_text: str, candidates: Iterable[Candidate], threshold: int
) -> tuple[Candidate, int] | None:
    """Find the highest-scoring candidate above ``threshold``."""
    best: tuple[Candidate, int] | None = None
    for c in candidates:
        s = score(user_text, c.text)
        if s < threshold:
            continue
        if best is None or s > best[1]:
            best = (c, s)
    return best


# ---------------------------------------------------------------------------
# Slot extraction + canonical building
# ---------------------------------------------------------------------------


_FIXED_PART_ALIGNMENT_THRESHOLD = 60


def _align_fixed_part(
    fixed: str, user: str, start: int
) -> tuple[int, int] | None:
    """Find where ``fixed`` approximately occurs in ``user[start:]``.

    Uses ``partial_ratio_alignment`` for character-level alignment, which
    tolerates merged tokens (``"im büro"`` → ``"imbüro"``), split tokens
    (``"wohnzimmer"`` → ``"wohn zimmer"``) and per-character typos in the
    fixed parts. Returns ``(begin, end)`` offsets into ``user`` of the
    matched span, or ``None`` if no decent alignment exists.
    """
    sub = user[start:]
    if not fixed:
        return (start, start)
    if not sub:
        return None
    alignment = fuzz.partial_ratio_alignment(fixed, sub)
    if alignment is None or alignment.score < _FIXED_PART_ALIGNMENT_THRESHOLD:
        return None
    return (start + alignment.dest_start, start + alignment.dest_end)


def extract_slots(user_text: str, candidate: Candidate) -> list[str] | None:
    """Pull slot values out of ``user_text`` aligned to ``candidate``.

    Character-level fuzzy alignment of each fixed part. Slot value is
    whatever lies between adjacent fixed parts (or between a fixed part
    and the end of the user text). Imperfect captures (extra leading
    chars from a misaligned boundary) get cleaned up downstream by
    ``Resolver.resolve_slot`` fuzz-matching against the slot's known
    values.

    Returns captured segments in left-to-right slot order, or ``None`` if
    alignment fails.
    """
    if not candidate.has_slots:
        return []

    parts = candidate.text.split(SLOT_WILDCARD)
    if len(parts) - 1 != len(candidate.slot_names):
        return None

    user = _normalise(user_text)
    cursor = 0
    captured: list[str] = []

    for i, prefix in enumerate(parts[:-1]):
        prefix_norm = " ".join(prefix.split())
        span = _align_fixed_part(prefix_norm, user, cursor)
        if span is None:
            return None
        end_pos = span[1]

        next_norm = " ".join(parts[i + 1].split())
        if next_norm:
            next_span = _align_fixed_part(next_norm, user, end_pos)
            slot_end = next_span[0] if next_span else len(user)
        else:
            slot_end = len(user)

        captured.append(user[end_pos:slot_end].strip())
        cursor = slot_end

    return captured


def build_canonical(
    candidate: Candidate,
    captured: list[str],
    resolver: Optional[Resolver] = None,
    slot_resolution_threshold: int = 70,
) -> str:
    """Reconstruct a clean sentence from ``candidate`` with slot values.

    If ``resolver`` is supplied, each captured slot value is fuzz-matched
    against the slot's known values (``resolver.slot_values[list_name]``)
    and replaced with the closest known value when one scores above
    ``slot_resolution_threshold``. Otherwise (or when nothing scores high
    enough) the user's raw spoken text is preserved.
    """
    if SLOT_WILDCARD not in candidate.text:
        return candidate.text
    parts = candidate.text.split(SLOT_WILDCARD)
    out: list[str] = [parts[0]]
    for i, raw in enumerate(captured):
        list_name = (
            candidate.slot_names[i] if i < len(candidate.slot_names) else None
        )
        if resolver is not None:
            value = resolver.resolve_slot(raw, list_name, slot_resolution_threshold)
        else:
            value = raw
        out.append(value)
        out.append(parts[i + 1])
    return _normalise("".join(out))
