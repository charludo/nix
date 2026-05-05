"""Benchmark two embedding models on the grocery-categorise task.

Run:

    PYTHONPATH=. python scripts/benchmark.py

Reports per-model accuracy on a typo-heavy gold-standard set, both with
and without the fuzzy correction layer. Each result row is the model's
choice for one item; mismatches against the gold label are flagged.

Models compared:

  * paraphrase-multilingual-MiniLM-L12-v2 (default; ~470 MB)
  * intfloat/multilingual-e5-small        (~470 MB; needs no prefix
    for short cross-lingual similarity but officially recommends
    "query: " on inputs — we test both forms.)

Note: the e5 family was trained with explicit "query: ..." /
"passage: ..." prefixes. We try the model both with and without the
prefix on inputs to see what matters in practice.
"""

from __future__ import annotations

import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

# (item, expected_category). A mix of clean items, typos, STT-style
# garble, brand names, and morphologically tricky compounds.
GOLD: list[tuple[str, str]] = [
    # Clean baseline
    ("Vollmilch", "Milchprodukte"),
    ("Apfel", "Obst"),
    ("Roggenbrot", "Backwaren"),
    ("Tofu", "Veganes"),
    ("Espresso", "Coffee&Tea"),
    # Typos / STT garble
    ("Mlich", "Milchprodukte"),
    ("Vollmilsch", "Milchprodukte"),
    ("Hfermlich", "Milchprodukte"),
    ("Hafermilsch", "Milchprodukte"),
    ("Käsekochen", "Backwaren"),
    ("Toiletenpapier", "Reinigungsmittel&Müll"),
    ("Tolettnpapir", "Reinigungsmittel&Müll"),
    ("Mundspülng", "Zahnputz"),
    ("Erkältugnstee", "Coffee&Tea"),
    ("Pflanzendüngr", "Gartencenter&Baumarkt"),
    ("Fishsauce", "Asia"),
    ("Schraubenziher", "Gartencenter&Baumarkt"),
    ("Akkuschraubr", "Gartencenter&Baumarkt"),
    ("Eirlikör", "Alkohol"),
    ("Räuherlachs", "Fisch"),
    ("Tomatnsoße", "Tomatensoße"),
    ("Aspirn", "Apotheke"),
    # Brand names
    ("Pepsi", "Softdrinks"),
    ("Coca-Cola", "Softdrinks"),
    ("Coca Cla", "Softdrinks"),
    ("Pepsii", "Softdrinks"),
    ("Ben & Jerry's", "Tiefgefrorenes"),
    ("Ben&Jeris", "Tiefgefrorenes"),
    ("Häagen-Dazs", "Tiefgefrorenes"),
    ("Milka", "Süßwaren"),
    ("Ritter Sport", "Süßwaren"),
    ("Lindt", "Süßwaren"),
    ("Persil", "Reinigungsmittel&Müll"),
    ("Fairy", "Reinigungsmittel&Müll"),
    ("Oral-B", "Zahnputz"),
    ("Nivea", "Kosmetik"),
    ("Schwarzkopf", "Seife&Shampoo"),
    ("Jacobs", "Coffee&Tea"),
    ("Dallmayr", "Coffee&Tea"),
    ("Jägermeister", "Alkohol"),
    ("Krombacher", "Alkohol"),
    ("Kikkoman", "Asia"),
    ("Old El Paso", "Mexiko"),
    # Compound morphology traps
    ("Hafermilch", "Veganes"),
    ("Eierlikör", "Alkohol"),
    ("Kokosmilch", "Asia"),
    ("Milchschokolade", "Süßwaren"),
    ("Fischsauce", "Asia"),
    ("Schokoladeneis", "Tiefgefrorenes"),
    ("Senfgurken", "Konserven"),
    ("Eiweißpulver", "Apotheke"),
    ("Käsekuchen", "Backwaren"),
]


def evaluate(model_name: str, fuzzy: bool, label: str) -> dict:
    from grocery_categorize.classifier import Classifier  # type: ignore

    print(f"\n=== {label} ===", flush=True)
    t0 = time.time()
    clf = Classifier(model_name=model_name, threshold=0.45)
    load_s = time.time() - t0

    items = [item for item, _ in GOLD]
    t0 = time.time()
    matches = clf.classify(items, fuzzy=fuzzy)
    classify_s = time.time() - t0

    direct_correct = 0
    fuzzy_correct = 0
    either_correct = 0
    disagree = 0
    misses: list[tuple] = []
    for (item, expected), m in zip(GOLD, matches):
        d_ok = m.category == expected
        f_ok = m.fuzzy_category == expected if m.fuzzy_category is not None else False
        if d_ok:
            direct_correct += 1
        if f_ok:
            fuzzy_correct += 1
        if d_ok or f_ok:
            either_correct += 1
        else:
            misses.append(
                (item, expected, m.category, m.score, m.fuzzy_category, m.corrected)
            )
        if (
            m.fuzzy_category is not None
            and m.fuzzy_category != m.category
        ):
            disagree += 1

    n = len(GOLD)
    print(f"  load:   {load_s:5.2f} s")
    print(f"  classify {n} items: {classify_s:5.2f} s ({classify_s/n*1000:.0f} ms/item)")
    print(f"  direct accuracy: {direct_correct}/{n} = {direct_correct/n*100:.1f}%")
    if fuzzy:
        print(f"  fuzzy  accuracy: {fuzzy_correct}/{n} = {fuzzy_correct/n*100:.1f}%")
        print(f"  either accuracy: {either_correct}/{n} = {either_correct/n*100:.1f}%")
        print(f"  disagreements:   {disagree}/{n}")
    if misses:
        print(f"  misses ({len(misses)}, neither branch right):")
        for item, exp, got, sc, fcat, corr in misses:
            extra = ""
            if fcat is not None:
                extra = f" fuzzy→{fcat!r} (corrected→{corr!r})"
            print(f"    {item!r:30s} expected={exp!r:30s} got={got!r:30s}{extra}")
    return {
        "label": label,
        "model": model_name,
        "fuzzy": fuzzy,
        "load_s": load_s,
        "classify_s": classify_s,
        "direct_accuracy": direct_correct / n,
        "fuzzy_accuracy": fuzzy_correct / n if fuzzy else None,
        "either_accuracy": either_correct / n,
        "disagreements": disagree,
        "n": n,
    }


def main() -> int:
    runs = [
        ("paraphrase-multilingual-MiniLM-L12-v2", False, "MiniLM-L12  (no fuzzy)"),
        ("paraphrase-multilingual-MiniLM-L12-v2", True,  "MiniLM-L12  (+fuzzy)"),
        ("intfloat/multilingual-e5-small",        False, "e5-small    (no fuzzy)"),
        ("intfloat/multilingual-e5-small",        True,  "e5-small    (+fuzzy)"),
    ]
    summaries = [evaluate(model, fuzzy, label) for model, fuzzy, label in runs]

    print("\n=== summary ===")
    header = f"  {'config':35s} {'direct':>8s} {'fuzzy':>8s} {'either':>8s} {'time':>8s}"
    print(header)
    for s in summaries:
        f = (
            f"{s['fuzzy_accuracy']*100:7.1f}%"
            if s["fuzzy_accuracy"] is not None
            else "      —"
        )
        print(
            f"  {s['label']:35s} "
            f"{s['direct_accuracy']*100:7.1f}% "
            f"{f} "
            f"{s['either_accuracy']*100:7.1f}% "
            f"{s['classify_s']:7.2f}s"
        )

    out = Path(__file__).resolve().parent / "benchmark_results.json"
    out.write_text(json.dumps(summaries, ensure_ascii=False, indent=2))
    print(f"\nwrote {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
