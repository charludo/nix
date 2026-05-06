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
    # Lowercase anchors get auto-title-cased into the canonical form.
    assert m.matched_anchor == "Vollmilch"


def test_tomaten_resolves_to_gemuese_not_tomatensosse() -> None:
    """Bare ``"Tomaten"`` is the produce, not pasta sauce.

    Pulls in the real CATEGORIES because the bug only manifests when
    Tomatensoße (which contains anchors like ``"gehackte tomaten"``,
    ``"stückige tomaten"``) and Gemüse (which contains ``"Tomaten"``)
    coexist — both score 100 via token_set_ratio. Cross-category
    tiebreak by closest anchor-length to input must pick the 7-char
    ``"Tomaten"`` over the 16-char ``"Gehackte Tomaten"``.
    """
    clf = Classifier()  # default = real CATEGORIES
    matches = {m.item: m.category for m in clf.classify(
        ["Tomaten", "Tomate", "Gehackte Tomaten", "Tomatensoße"]
    )}
    assert matches["Tomaten"] == "Gemüse"
    assert matches["Tomate"] == "Gemüse"
    assert matches["Gehackte Tomaten"] == "Tomatensoße"
    assert matches["Tomatensoße"] == "Tomatensoße"


def test_list_anchor_canonical() -> None:
    """List-form anchors: any element matches; index-0 is the
    canonical surfaced on the Match. Used to fold typos / STT garbles
    under a single clean display name."""
    cats = [
        ("Backwaren", [["Süßstoff", "süßstofftabletten", "stevia"]]),
        ("Milchprodukte", [["Crème Fraîche", "creme fraiche"]]),
    ]
    clf = Classifier(categories=cats, threshold=80)
    matches = {m.item: m for m in clf.classify(
        ["süßstofftabletten", "stevia", "creme fraiche", "Crème Fraîche"]
    )}
    assert matches["süßstofftabletten"].matched_anchor == "Süßstoff"
    assert matches["stevia"].matched_anchor == "Süßstoff"
    assert matches["creme fraiche"].matched_anchor == "Crème Fraîche"
    assert matches["Crème Fraîche"].matched_anchor == "Crème Fraîche"
