"""Pure-rapidfuzz item → category classifier.

We dropped the embedding model — torch + transformers + the inference
overhead were too heavy for the benefit, given that anchor coverage is
now thick enough (~60 per category) for lexical matching to do most of
the work.

Per item we score every anchor with ``token_set_ratio`` only. We had
``WRatio`` on too — it handles compounds slightly better — but its
weighted internal use of ``partial_ratio`` makes it score short anchors
like ``"gin"`` at 100 against any input that contains the substring
(``"obergine"`` → Alcohol). ``token_set_ratio`` falls back to a plain
``ratio`` (Levenshtein) when there's no token overlap, which still
catches compounds (``"Vollmilch"`` → ``"vollmilch"`` at 100) and typos
(``"Vollmilsch"`` → ``"vollmilch"`` at ~95) without the false-positive
risk on short anchors.

The category whose best anchor scores highest wins, gated only by an
absolute score floor (no margin gate — rapidfuzz's scores cluster at
100, so margin would gate away too many clean hits). Items below the
floor land in ``Sonstiges`` — fix by adding the missing anchor.
"""

from __future__ import annotations

import logging
import re
from dataclasses import dataclass
from typing import Iterable, Optional

import numpy as np
from rapidfuzz import fuzz, process

# Importable both as part of the package (HA loads it under
# `custom_components/grocery_categorize/`) and as a standalone module
# from tests (sys.path points into the dir).
try:
    from .categories import CATEGORIES
except ImportError:  # pragma: no cover
    from categories import CATEGORIES  # type: ignore

_LOGGER = logging.getLogger(__name__)

# rapidfuzz scores are 0-100 ints. 80 lets through near-perfect anchor
# matches; 70 admits more typo'd inputs at the cost of more false
# positives on truly OOD strings. 80 was empirically the sweet spot on
# the gold-standard set.
DEFAULT_THRESHOLD = 80
FALLBACK_CATEGORY = "Sonstiges"


_LEADING_E_RE = re.compile(r"^e\s+")


def _normalize(s: str) -> str:
    """Lowercase + treat ``&`` and ``-`` as word boundaries + collapse
    whitespace + strip a common STT artifact.

    German STT routinely prepends a stray ``"e "`` (probably misreading
    a glottal stop or initial vowel), so ``"e reiben-motorhalla"``
    becomes ``"reiben motorhalla"`` for matching purposes. Dashes are
    word boundaries because compounds like ``"Reibe-Mozzarella"`` and
    brands like ``"Häagen-Dazs"`` should match against space-separated
    anchors.
    """
    s = s.replace("&", " ").replace("-", " ").lower()
    s = _LEADING_E_RE.sub("", s)
    return " ".join(s.split())


@dataclass
class Match:
    item: str
    category: str
    score: float
    matched_anchor: Optional[str] = None  # the winning anchor's original form

    def to_dict(self) -> dict:
        d = {
            "item": self.item,
            "category": self.category,
            "score": round(self.score, 2),
        }
        if self.matched_anchor is not None:
            d["matched_anchor"] = self.matched_anchor
        return d


class Classifier:
    def __init__(
        self,
        threshold: float = DEFAULT_THRESHOLD,
        categories: Optional[list[tuple[str, list[str]]]] = None,
    ) -> None:
        self._threshold = threshold
        self._categories = categories if categories is not None else CATEGORIES

        # Each anchor entry can be a plain string (single-form anchor)
        # or a list of strings (multi-form, with index 0 = canonical
        # display name). Both flatten into the same flat lookup tables;
        # anchor_orig records the canonical for *every* form, so when
        # any variant matches we surface the canonical for display.
        #
        # We deliberately do NOT auto-anchor on the category name —
        # ``"Salz&Gewürze"`` as a string would otherwise match all kinds
        # of items containing ``"gewürz"``. Add an explicit anchor entry
        # if you want a category name to also be matchable as input.
        self._cat_names: list[str] = []
        anchor_norm: list[str] = []
        anchor_orig: list[str] = []
        anchor_owner: list[int] = []
        for ci, (name, anchors) in enumerate(self._categories):
            self._cat_names.append(name)
            for entry in anchors:
                if isinstance(entry, str):
                    canonical = entry.title() if entry.islower() else entry
                    forms = [entry]
                else:
                    canonical = entry[0]
                    forms = list(entry)
                for form in forms:
                    anchor_norm.append(_normalize(form))
                    anchor_orig.append(canonical)
                    anchor_owner.append(ci)
        self._anchor_norm = anchor_norm
        self._anchor_orig = anchor_orig
        self._anchor_owner = np.asarray(anchor_owner)

    def classify(self, items: Iterable[str]) -> list[Match]:
        original = [i.strip() for i in items]
        items_filtered = [s for s in original if s]
        if not items_filtered:
            return []

        normalized = [_normalize(s) for s in items_filtered]
        n_cats = len(self._cat_names)

        # Two passes:
        #   1. token_set_ratio on normalised strings — handles typos
        #      (Levenshtein on full string when no token overlap), and
        #      multi-token brands (``"Old El Paso"`` ↔ ``"old el paso"``).
        #   2. plain ratio on space-stripped strings — catches
        #      STT-fragmented inputs like ``"e o-liven"`` (normalises to
        #      ``"o liven"``, squashes to ``"oliven"`` which then matches
        #      anchor ``"oliven"`` at 100). Disjoint-token failure mode
        #      of token_set_ratio is the gap this fills.
        scores_token = np.asarray(
            process.cdist(
                normalized, self._anchor_norm, scorer=fuzz.token_set_ratio
            )
        )
        squashed_input = [s.replace(" ", "") for s in normalized]
        squashed_anchors = [a.replace(" ", "") for a in self._anchor_norm]
        scores_squash = np.asarray(
            process.cdist(squashed_input, squashed_anchors, scorer=fuzz.ratio)
        )
        anchor_scores = np.maximum(scores_token, scores_squash)

        results: list[Match] = []
        for item, row, item_norm in zip(items_filtered, anchor_scores, normalized):
            input_len = len(item_norm)
            cat_scores = np.full(n_cats, 0.0, dtype=row.dtype)
            cat_anchor = [None] * n_cats
            for ai, score in enumerate(row):
                ci = int(self._anchor_owner[ai])
                anchor = self._anchor_orig[ai]
                # On ties (rapidfuzz often gives several anchors a
                # score of 100 — a token-set match counts ``"olivenöl"``
                # vs ``"olivenöl extra vergine"`` as 100, same as
                # ``"olivenöl"`` vs ``"olivenöl"``), prefer the anchor
                # whose length is closest to the input. ``"Olivenöl"``
                # picks ``"olivenöl"`` (Δ=0) over ``"olivenöl extra
                # vergine"`` (Δ=14); ``"Coca Cola"`` picks ``"coca-cola"``
                # (Δ=0) over ``"cola"`` (Δ=5).
                better_tie = (
                    cat_anchor[ci] is not None
                    and abs(len(anchor) - input_len)
                    < abs(len(cat_anchor[ci]) - input_len)
                )
                if score > cat_scores[ci] or (
                    score == cat_scores[ci] and better_tie
                ):
                    cat_scores[ci] = score
                    cat_anchor[ci] = anchor
            # Cross-category selection: max score first, then closest
            # anchor-length to input as tiebreak. Without the secondary
            # key the first category in declaration order would win
            # arbitrary ties (e.g. ``"vanille eis"`` hits 100 against
            # both Backzutaten ``"vanille"`` and Tiefgefrorenes
            # ``"vanille eis"`` — we want the one whose anchor matches
            # the input length).
            def _cat_sort_key(ci: int) -> tuple:
                anchor = cat_anchor[ci]
                if anchor is None:
                    return (cat_scores[ci], -float("inf"))
                return (cat_scores[ci], -abs(len(anchor) - input_len))

            top_idx = max(range(n_cats), key=_cat_sort_key)
            top = float(cat_scores[top_idx])
            if top >= self._threshold:
                category = self._cat_names[top_idx]
                anchor = cat_anchor[top_idx]
            else:
                category = FALLBACK_CATEGORY
                anchor = None
            results.append(
                Match(item=item, category=category, score=top, matched_anchor=anchor)
            )
        return results
