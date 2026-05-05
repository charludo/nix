"""Hassil-pattern expansion + RapidFuzz scoring + slot extraction.

Pure-Python, no Home Assistant imports. Unit-testable on its own.
Language-agnostic: never inspects or coerces slot values, only captures
the text the user spoke between fixed parts of the pattern.
"""

from __future__ import annotations

import logging
import re
from dataclasses import dataclass, field
from typing import Iterable

from rapidfuzz import fuzz

# Importable both as part of the package and as a standalone module (tests).
try:
    from .const import SLOT_WILDCARD
except ImportError:  # pragma: no cover
    from const import SLOT_WILDCARD  # type: ignore

_LOGGER = logging.getLogger(__name__)

# Slot syntax: `{name}` or `{name:list}`. We only care about the name here,
# the optional `:list` reference is for HA's downstream Hassil and is
# preserved untouched in the canonical output.
_SLOT_RE = re.compile(r"\{([a-zA-Z_][a-zA-Z0-9_]*)(?::[a-zA-Z0-9_]+)?\}")
# `(a|b|c)` alternative group.
_ALT_RE = re.compile(r"\(([^()]+)\)")
# `[…]` optional group.
_OPT_RE = re.compile(r"\[([^\[\]]+)\]")


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
    """Slot names in left-to-right order; same length as wildcard count in ``text``."""

    @property
    def has_slots(self) -> bool:
        return bool(self.slot_names)


def expand_pattern(pattern: str, cap: int) -> list[tuple[str, list[str]]]:
    """Expand a Hassil-style pattern into ``[(text, slot_names), …]``.

    Handles ``[optional]`` and ``(a|b|c)``. Slots become ``SLOT_WILDCARD``
    tokens. ``cap=0`` disables expansion (returns just the raw template
    with everything stripped to a single canonical form).
    """
    slot_names: list[str] = []

    def _slot_sub(m: re.Match[str]) -> str:
        slot_names.append(m.group(1))
        return f" {SLOT_WILDCARD} "

    pat = _SLOT_RE.sub(_slot_sub, pattern)

    if cap == 0:
        text = _ALT_RE.sub(lambda m: m.group(1).split("|")[0], pat)
        text = _OPT_RE.sub(lambda m: m.group(1), text)
        return [(_normalise(text), list(slot_names))]

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
        out.append((text, list(slot_names)))
        if len(out) >= cap:
            break
    return out


def _normalise(s: str) -> str:
    """Lowercase, strip extraneous whitespace and trailing punctuation."""
    s = re.sub(r"\s+", " ", s).strip().lower()
    s = s.rstrip("?.!,;:")
    return s


def score(user_text: str, candidate_text: str) -> int:
    """Whole-phrase similarity 0..100 with the slot wildcard ignored.

    Uses ``fuzz.token_sort_ratio``: order-tolerant, character-level
    Levenshtein on the sorted tokens. The wildcard is stripped before
    scoring so missing/extra slot text doesn't drag the score down —
    slot capture happens separately.
    """
    cand = candidate_text.replace(SLOT_WILDCARD, " ")
    cand = re.sub(r"\s+", " ", cand).strip()
    return int(fuzz.token_sort_ratio(_normalise(user_text), cand))


def extract_slots(user_text: str, candidate: Candidate) -> list[str] | None:
    """Pull slot values out of ``user_text`` aligned to ``candidate``.

    Returns the captured text segments in left-to-right slot order, or
    ``None`` if alignment is ambiguous. Values are returned **as the
    user said them** — no coercion, no language-specific lookups. The
    caller substitutes them back into the canonical sentence and lets
    HA's Hassil resolve them via whatever slot list the pattern names.
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
        prefix = prefix.strip()
        if prefix:
            idx = user.find(prefix, cursor)
            if idx < 0:
                last_tok = prefix.split()[-1] if prefix.split() else ""
                idx = user.find(last_tok, cursor) if last_tok else -1
                if idx < 0:
                    return None
                idx += len(last_tok)
            else:
                idx += len(prefix)
        else:
            idx = cursor

        next_prefix = parts[i + 1].strip()
        if next_prefix:
            end = user.find(next_prefix.split()[0], idx) if next_prefix else -1
            if end < 0:
                end = len(user)
        else:
            end = len(user)

        captured.append(user[idx:end].strip())
        cursor = end

    return captured


def build_canonical(candidate: Candidate, captured: list[str]) -> str:
    """Reconstruct a clean sentence from ``candidate`` with slot values.

    Walks ``candidate.text``, substituting each ``SLOT_WILDCARD`` with the
    corresponding entry from ``captured``. The result is what we hand to
    HA's default conversation agent — at that point Hassil takes over,
    matches the slot lists, and dispatches the intent.
    """
    if SLOT_WILDCARD not in candidate.text:
        return candidate.text
    parts = candidate.text.split(SLOT_WILDCARD)
    out: list[str] = [parts[0]]
    for i, value in enumerate(captured):
        out.append(value)
        out.append(parts[i + 1])
    return _normalise("".join(out))


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
