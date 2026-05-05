# hass-grocery-categorize

Categorises German shopping-list items into a small set of supermarket
sections (produce, dairy, bakery, …) via sentence embeddings. No LLM,
no exhaustive keyword lists — anchor terms per category are enough; the
model generalises from there.

## Why

Substring keyword matching needs you to enumerate every variant
(`milch`, `h-milch`, `vollmilch`, `buttermilch`, `kondensmilch`, …).
Embedding similarity catches all of those from a handful of anchors.
The trade-off is ~500 MB RAM and a ~3-5 s startup cost to load the
model — fine for a "build me a printable list" flow, less fine for
sub-second per-keystroke use.

## Install

Editable, for development:

```sh
pip install -e .
```

## CLI usage

```sh
# Args:
grocery-categorize Milch Apfel "Toilettenpapier" Sahne

# Or stdin:
printf "Milch\nApfel\nSahne\n" | grocery-categorize
```

Output is JSON: `[{ "item": ..., "category": ..., "score": ... }, ...]`.

Items below the score threshold (default `0.45`) fall into
`"Sonstiges"` rather than getting force-fit into the closest category.

## Categories

Defined in [`grocery_categorize/categories.py`](./grocery_categorize/categories.py).
Each entry is `(name, [anchor terms])`. Edit there to add/remove
categories or adjust anchors. Print order is *not* defined here — that's
left to the consumer (Home Assistant / Nix config orders categories
according to your store layout).

## Design

- **Model**: `paraphrase-multilingual-MiniLM-L12-v2` by default
  (overrideable via `--model`). 384-dim, multilingual, CPU-only.
- **Category embeddings**: built once from
  `"<name>: <anchor1> <anchor2> …"`. Including the category name helps
  when it's already a strong semantic signal.
- **Item embeddings**: computed in one batched call per invocation.
- **Classification**: argmax cosine similarity per item; below threshold
  → `"Sonstiges"`.

## Future

Currently a one-shot CLI. If startup latency becomes painful (e.g.
hooked into a real-time UI), wrap it as a long-running daemon (FastAPI
or a HA `custom_components/grocery_categorize/` integration) so the
model stays loaded.
