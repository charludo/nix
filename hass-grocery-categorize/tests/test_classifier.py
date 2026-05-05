"""Pure rapidfuzz classifier — no model deps to mock."""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(
    0,
    str(
        Path(__file__).resolve().parent.parent
        / "custom_components"
        / "grocery_categorize"
    ),
)

from classifier import Classifier  # type: ignore  # noqa: E402


# Real-world category lists carry compound forms (``"vollmilch"``)
# alongside roots (``"milch"``); the classifier deliberately doesn't
# do partial-substring matching anymore (it caused false positives
# like ``"obergine"`` → ``"gin"``). Tests therefore include the full
# forms users would actually type/say, not just the roots.
CATS = [
    (
        "Milchprodukte",
        ["milch", "vollmilch", "joghurt", "käse", "vollmilch h"],
    ),
    ("Obst", ["apfel", "äpfel", "banane", "trauben"]),
    ("Backwaren", ["brot", "brötchen", "kuchen", "roggenbrot"]),
]


def test_clean_inputs() -> None:
    clf = Classifier(categories=CATS, threshold=80)
    matches = {
        m.item: m.category
        for m in clf.classify(["Vollmilch", "Apfel", "Roggenbrot"])
    }
    assert matches == {
        "Vollmilch": "Milchprodukte",
        "Apfel": "Obst",
        "Roggenbrot": "Backwaren",
    }


def test_typo_tolerance() -> None:
    clf = Classifier(categories=CATS, threshold=70)
    # 1-char typo on a fully-anchored word — ratio drops a few points
    # but still over the relaxed threshold.
    matches = {m.item: m.category for m in clf.classify(["Vollmilsch", "Apfle"])}
    assert matches["Vollmilsch"] == "Milchprodukte"
    assert matches["Apfle"] == "Obst"


def test_oods_fall_to_sonstiges() -> None:
    clf = Classifier(categories=CATS, threshold=80)
    # No tri/quadgram overlap with any anchor.
    matches = clf.classify(["Xylophon"])
    assert matches[0].category == "Sonstiges"


def test_handles_empty_input() -> None:
    clf = Classifier(categories=CATS)
    assert clf.classify([]) == []
    assert clf.classify(["", "  ", "\n"]) == []


def test_score_is_returned() -> None:
    clf = Classifier(categories=CATS, threshold=80)
    m = clf.classify(["Vollmilch"])[0]
    assert m.score >= 80
    assert m.matched_anchor == "vollmilch"
