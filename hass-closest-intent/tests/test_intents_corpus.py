"""End-to-end matching tests against the real intent corpus.

Mirrors the patterns defined in ``modules/home-assistant/intents/`` and
verifies that representative user phrases (clean, with typos, with
merged/split tokens, with multi-token slot values) all score above the
default threshold and pick the right intent. Catches regressions where
expansion / scoring changes break specific real-world cases.

The corpus is duplicated here (rather than parsed from the .nix files)
so the test suite has no Nix dependency and so each pattern can have
its own targeted phrase list.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(
    0,
    str(
        Path(__file__).resolve().parent.parent
        / "custom_components"
        / "closest_intent"
    ),
)

import pytest  # noqa: E402

from matching import (  # type: ignore  # noqa: E402
    Candidate,
    Resolver,
    build_canonical,
    expand_pattern,
    extract_slots,
    find_best,
)


THRESHOLD = 70
EXPANSION_CAP = 32


# ---------------------------------------------------------------------------
# Corpus
# ---------------------------------------------------------------------------


CORPUS: dict[str, list[str]] = {
    # botty.nix
    "Botty_Start": [
        "Starte die Reinigung",
        "Beginne Reinigung",
        "Reinigung starten",
        "Botty los",
        "Botty saugen",
        "Sauge",
    ],
    "Botty_Ende": [
        "Beende die Reinigung",
        "Stoppe Reinigung",
        "Reinigung beenden",
        "Botty zurück",
        "Botty nach Hause",
        "Botty stop",
    ],
    "Botty_Wohnzimmer": [
        "Reinige im Wohnzimmer",
        "Sauge das Wohnzimmer",
        "Botty ins Wohnzimmer",
        "Wohnzimmer reinigen",
    ],
    "Botty_Buero": [
        "Reinige Büro",
        "Sauge im Arbeitszimmer",
        "Büro reinigen",
        "Arbeitszimmer saugen",
    ],
    "Botty_Kueche": [
        "Reinige in der Küche",
        "Sauge die Küche",
        "Küche reinigen",
    ],
    "Botty_Sofa": [
        "Reinige vor dem Sofa",
        "Sauge unter dem Fernseher",
        "Sofa reinigen",
    ],
    # garden.nix
    "PumpeAn": [
        "Aktiviere die Pumpe",
        "Schalte die Wasserpumpe an",
        "Pumpe an",
        "Wasserpumpe ein",
    ],
    "PumpeAus": [
        "Deaktiviere die Pumpe",
        "Schalte die Wasserpumpe aus",
        "Pumpe aus",
        "Wasserpumpe ab",
    ],
    # music.nix
    "MusikAn": [
        "Spiele Musik",
        "Spiel die Musik",
        "Starte Musik",
        "Musik an",
        "Musik abspielen",
    ],
    "MusikFortsetzen": [
        "Musik fortsetzen",
        "Mache Musik fort",
        "Setze Musik fort",
        "Weiter abspielen",
        "Weiterspielen",
    ],
    "MusikPause": [
        "Pausiere die Musik",
        "Stoppe Musik",
        "Musik pausieren",
        "Musik anhalten",
        "Pause",
    ],
    "MusikNaechster": [
        "Nächster Titel",
        "Nächstes Lied",
        "Skip",
        "Weiter",
    ],
    "MusikShuffleAn": [
        "Shuffle an",
        "Mischen ein",
        "Zufallswiedergabe aktivieren",
    ],
    "MusikShuffleAus": [
        "Shuffle aus",
        "Mischen ab",
        "Zufallswiedergabe deaktivieren",
    ],
    "PlayerNeustart": [
        "Player neu starten",
        "Spieler neustarten",
        "Sonos resetten",
        "Restart Player",
    ],
    "ZufaelligesAlbum": [
        "Spiele ein zufälliges Album",
        "Zufälliges Album",
        "Random Album",
    ],
    "ZufaelligerKuenstler": [
        "Spiele einen zufälligen Künstler",
        "Zufälliger Artist",
        "Random Artist",
    ],
    "NeueMusik": [
        "Spiele die neue Musik",
        "Spiel die neuesten Tracks",
        "Spiele die Playlist Recently Added",
        "Recently Added",
    ],
    "KuerzlichGespielt": [
        "Spiele die zuletzt gehörten Titel",
        "Spiel die zuletzt gespielten Lieder",
        "Recently Played",
        "Spiel die selben Songs nochmal",
    ],
    # news.nix
    "Tagesschau": [
        "Spiele die Tagesschau",
        "Spiel Tagesschau in 100 Sekunden",
        "Starte die Tagesschau",
        "Tagesschau",
    ],
    "WDR_Aktuell": [
        "Spiele WDR Aktuell",
        "WDR Nachrichten",
    ],
    "Nachrichten": [
        "Spiele die Nachrichten",
        "Starte Nachrichten",
        "Nachrichten",
        "Tägliche Zusammenfassung",
    ],
    # time.nix
    "UhrZeit": [
        "Wie spät ist es",
        "Wie viel Uhr ist es",
        "Uhrzeit",
    ],
    "Datum": [
        "Welches Datum haben wir",
        "Was ist heute für ein Datum",
        "Datum",
    ],
    "Wochentag": [
        "Welcher Tag ist heute",
        "Welcher Wochentag ist heute",
        "Was ist heute für ein Tag",
        "Tag",
        "Wochentag",
    ],
    # tv.nix
    "TV_Hell": [
        "Mache den Fernseher heller",
        "Setze das Bild hell",
        "Fernseher Tagmodus",
    ],
    "TV_Dunkel": [
        "Mache den Fernseher dunkel",
        "Stelle das Bild dunkler",
        "Fernseher Nachtmodus",
    ],
    # weather.nix (no-slot patterns; slot patterns covered separately)
    "WetterHeute": [
        "Wie ist das Wetter heute",
        "Wie ist das Wetter draußen",
        "Wie warm ist es draußen",
    ],
    "WetterMorgen": [
        "Wie wird das Wetter morgen",
        "Wie wird das Wetter morgen früh",
        "Wie warm wird es morgen",
    ],
    "WetterWoche": [
        "Wie wird das Wetter diese Woche",
        "Wie wird das Wetter in den nächsten Tagen",
        "Wettervorhersage",
    ],
    "WindAktuell": [
        "Wie windig ist es heute",
        "Wie stark weht der Wind",
    ],
    "WindHeuteNacht": [
        "Wie windig wird es heute Nacht",
        "Wie windig wird es nachts",
    ],
    "TemperaturMaxHeute": [
        "Wie warm wird es heute",
        "Was ist die Höchsttemperatur heute",
    ],
    "RegenHeute": [
        "Regnet es heute",
        "Wird es heute regnen",
        "Gibt es heute Regen",
    ],
}


# Slot-bearing intents handled separately so we can also assert the
# captured slot value is right.
SLOT_CORPUS: list[tuple[str, str, str, list[str]]] = [
    # (intent, pattern, user_text, expected_slots)
    ("WetterStunde", "Wie ist das Wetter um {timer_hours:hours} Uhr",
        "wie ist das wetter um zwölf uhr", ["zwölf"]),
    ("WetterStunde", "Wie wird das Wetter um {timer_hours:hours} Uhr",
        "wie wird das wetter um 14 uhr", ["14"]),
    ("RegenStunde", "Regnet es um {timer_hours:hours} Uhr",
        "regnet es um 18 uhr", ["18"]),
    ("Test_Area", "Test zwei im {area}",
        "test zwei im wohnzimmer", ["wohnzimmer"]),
    ("Test_Name", "Test drei mit {name}",
        "test drei mit charlotte", ["charlotte"]),
    ("Einkauf_Add", "(setze|pack|tu|schreib) {item} auf (die|meine) Einkaufsliste",
        "schreib brot auf die einkaufsliste", ["brot"]),
    ("Einkauf_Add", "{item} auf die Einkaufsliste",
        "salami auf die einkaufsliste", ["salami"]),
    ("Einkauf_Add", "Füge {item} zur Einkaufsliste hinzu",
        "füge milch zur einkaufsliste hinzu", ["milch"]),
    ("ToDo_Add", "(setze|pack|tu|schreib) {item} auf (die|meine) (ToDo|To-Do|To Do)-Liste",
        "schreib termin auf die todo-liste", ["termin"]),
    ("MusikPlaylist", "(Spiele|Spiel|Starte) [die ]Playlist {playlist}",
        "spiele playlist sea shanties", ["sea shanties"]),
]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _build_no_slot_candidates() -> list[Candidate]:
    """Treat each utterance pattern in CORPUS as if it came from a
    user-defined intent and expand into candidates."""
    out: list[Candidate] = []
    for intent_name, phrases in CORPUS.items():
        for idx, phrase in enumerate(phrases):
            for text, slot_names in expand_pattern(phrase, EXPANSION_CAP):
                out.append(
                    Candidate(
                        intent=intent_name,
                        pattern_idx=idx,
                        text=text,
                        slot_names=slot_names,
                    )
                )
    return out


# Pre-build once — same candidate pool used across every utterance.
_CANDIDATES = _build_no_slot_candidates()


# Each row: (intent name, user utterance) — generated from CORPUS so a
# new entry there flows into the parametrised tests automatically.
NOSLOT_PARAMS = [
    pytest.param(intent_name, phrase, id=f"{intent_name}::{phrase}")
    for intent_name, phrases in CORPUS.items()
    for phrase in phrases
]


@pytest.mark.parametrize("intent_name,phrase", NOSLOT_PARAMS)
def test_corpus_clean_phrase_matches(intent_name: str, phrase: str) -> None:
    """Exact corpus phrase must match its own intent above threshold."""
    match = find_best(phrase, _CANDIDATES, threshold=THRESHOLD)
    assert match is not None, f"no match for {phrase!r}"
    assert match[0].intent == intent_name, (
        f"{phrase!r} matched {match[0].intent!r} instead of {intent_name!r}"
    )


# A handful of representative typo'd / abbreviated cases — check the
# fuzzy matcher actually delivers value over a strict matcher.
TYPO_CASES = [
    ("Botty_Start", "starte rinigung"),         # one-char typo
    ("PumpeAn", "pumpr an"),                    # one-char typo
    ("MusikShuffleAn", "shuffl an"),            # truncation
    ("MusikPause", "pausir die musik"),         # typo + alternation
    ("UhrZeit", "wie sät ist es"),              # one-char drop
    ("WetterHeute", "wie warm ist es draussn"), # one-char typo
    ("Tagesschau", "spiel tagesshau"),          # one-char typo
]


@pytest.mark.parametrize("intent_name,phrase", TYPO_CASES)
def test_corpus_typo_matches(intent_name: str, phrase: str) -> None:
    match = find_best(phrase, _CANDIDATES, threshold=THRESHOLD)
    assert match is not None, f"no match for typo'd {phrase!r}"
    assert match[0].intent == intent_name


# ---------------------------------------------------------------------------
# Slot-bearing patterns
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "intent_name,pattern,user_text,expected",
    [
        pytest.param(*row, id=f"{row[0]}::{row[2]}") for row in SLOT_CORPUS
    ],
)
def test_slot_corpus_extracts(
    intent_name: str,
    pattern: str,
    user_text: str,
    expected: list[str],
) -> None:
    """Slot patterns: best expansion is picked, slot text aligns."""
    expansions = expand_pattern(pattern, EXPANSION_CAP)
    candidates = [
        Candidate(
            intent=intent_name,
            pattern_idx=0,
            text=text,
            slot_names=slots,
        )
        for text, slots in expansions
    ]
    match = find_best(user_text, candidates, threshold=THRESHOLD)
    assert match is not None, f"no match for {user_text!r}"

    # Walk siblings: the highest-scoring expansion may not be the one
    # whose fixed parts align — production code does the same fallback.
    # We additionally reject empty captures: when two expansions tie on
    # partial_ratio (alternations like "(setze|schreib) ..."), the one
    # whose prefix isn't actually in the user text "extracts" with an
    # empty slot, which isn't useful. Prefer extractions that actually
    # captured something.
    best = None
    for c, _s in sorted(
        ((c, find_best(user_text, [c], 0)[1]) for c in candidates),  # type: ignore
        key=lambda kv: -kv[1],
    ):
        captured = extract_slots(user_text, c)
        if captured is None:
            continue
        if any(s.strip() for s in captured):
            best = (c, captured)
            break
    assert best is not None, f"no extractable expansion for {user_text!r}"
    candidate, captured = best
    assert captured == expected, (
        f"expected {expected!r}, got {captured!r} (matched expansion {candidate.text!r})"
    )


# ---------------------------------------------------------------------------
# Resolver-backed slot resolution
# ---------------------------------------------------------------------------


def test_resolver_canonicalises_typo_d_area() -> None:
    """The end-to-end shape: pattern → expansion → score → extract →
    resolve slot value → canonical sentence."""
    pattern = "Test zwei im {area}"
    candidates = [
        Candidate(
            intent="Test_Area",
            pattern_idx=0,
            text=text,
            slot_names=slots,
        )
        for text, slots in expand_pattern(pattern, EXPANSION_CAP)
    ]
    resolver = Resolver(slot_values={"area": ["Wohnzimmer", "Büro", "Küche"]})
    user = "test zwei im wohnzma"
    match = find_best(user, candidates, threshold=THRESHOLD)
    assert match is not None
    captured = extract_slots(user, match[0])
    assert captured is not None
    canonical = build_canonical(match[0], captured, resolver=resolver)
    assert canonical == "test zwei im wohnzimmer"
