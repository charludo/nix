"""Render a shopping list as Markdown, grouped + ordered per supermarket.

Reads items from stdin (JSON array) or positional args, classifies each
via the embedding model, then groups by category in the order declared
for the chosen supermarket. Categories not in the supermarket's order
list are silently excluded — letting you maintain different aisle
sequences per store. Items the model can't confidently place fall into
``Sonstiges``, which is always rendered last (if non-empty).

Output is JSON:

    {
      "supermarket": "ALDI",
      "generated_at": "2026-05-05 18:30",
      "count": 17,
      "markdown": "# 2026-05-05 — ALDI\\n\\n# Obst\\n- Apfel\\n…"
    }

Designed to be invoked by Home Assistant via ``command_line`` sensor:
HA pipes the active todo items in as a JSON array, parses ``count``
into the sensor state, exposes ``markdown`` as an attribute that a
markdown card renders.
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime
from pathlib import Path

from .classifier import (
    DEFAULT_THRESHOLD,
    FALLBACK_CATEGORY,
    Classifier,
)


def render_markdown(
    supermarket: str,
    ordered_categories: list[str],
    items_by_cat: dict[str, list[str]],
    when: str,
    missing_categories: list[str] | None = None,
) -> str:
    lines = [f"*{when}*  ", f"*{supermarket}*  ", "<br/>"]
    # Sonstiges only renders if explicitly listed in `ordered_categories`
    # — items routed there for supermarkets without it are dropped at
    # assignment time in `__init__.py`.
    for cat in ordered_categories:
        items = items_by_cat.get(cat)
        if not items:
            continue
        lines.append(f"### {cat}")
        for it in items:
            lines.append(f"{it}  ")
        lines.append("<br/>")
    if missing_categories:
        # Confident classifications dropped because this supermarket's
        # category list doesn't include them — useful "buy elsewhere"
        # hint at the bottom of the printout.
        lines.append(
            f"*(Nicht in {supermarket}: {', '.join(missing_categories)})*"
        )
    return "\n".join(lines).rstrip() + "\n"


def _read_items(args: argparse.Namespace) -> list[str]:
    if args.items:
        return list(args.items)
    raw = sys.stdin.read().strip()
    if not raw:
        return []
    if args.json_stdin:
        try:
            data = json.loads(raw)
        except json.JSONDecodeError as e:
            print(f"Error parsing JSON from stdin: {e}", file=sys.stderr)
            sys.exit(2)
        if not isinstance(data, list):
            print("Stdin JSON must be a list of strings.", file=sys.stderr)
            sys.exit(2)
        return [str(s).strip() for s in data if str(s).strip()]
    return [line.strip() for line in raw.splitlines() if line.strip()]


def main() -> int:
    parser = argparse.ArgumentParser(
        prog="grocery-print",
        description="Render a shopping list as Markdown grouped by supermarket aisle order.",
    )
    parser.add_argument("--supermarket", required=True, help="Supermarket key from --config.")
    parser.add_argument(
        "--config",
        required=True,
        type=Path,
        help='JSON file mapping supermarket → ordered category list.',
    )
    parser.add_argument(
        "--json-stdin",
        action="store_true",
        help="Parse stdin as a JSON array (default: newline-separated).",
    )
    parser.add_argument("--threshold", type=float, default=DEFAULT_THRESHOLD)
    parser.add_argument("items", nargs="*")
    args = parser.parse_args()

    try:
        config = json.loads(args.config.read_text())
    except (OSError, json.JSONDecodeError) as e:
        print(f"Failed to load --config: {e}", file=sys.stderr)
        return 2

    if args.supermarket not in config:
        print(
            f"Unknown supermarket {args.supermarket!r}. Known: "
            f"{sorted(config)}",
            file=sys.stderr,
        )
        return 2
    ordered = list(config[args.supermarket])

    items = _read_items(args)
    when_full = datetime.now().strftime("%Y-%m-%d %H:%M")
    when_short = datetime.now().strftime("%Y-%m-%d")

    if not items:
        markdown = f"# {when_short} — {args.supermarket}\n\n_Keine Einträge._\n"
        json.dump(
            {
                "supermarket": args.supermarket,
                "count": 0,
                "generated_at": when_full,
                "markdown": markdown,
            },
            sys.stdout,
            ensure_ascii=False,
        )
        sys.stdout.write("\n")
        return 0

    clf = Classifier(threshold=args.threshold)
    matches = clf.classify(items)

    allowed = set(ordered)
    include_fallback = FALLBACK_CATEGORY in allowed
    items_by_cat: dict[str, list[str]] = {}
    missing_cats: set[str] = set()
    for m in matches:
        if m.category in allowed:
            cat = m.category
        elif m.category == FALLBACK_CATEGORY and include_fallback:
            cat = FALLBACK_CATEGORY
        else:
            if m.category != FALLBACK_CATEGORY:
                missing_cats.add(m.category)
            continue
        items_by_cat.setdefault(cat, []).append(m.item)

    markdown = render_markdown(
        args.supermarket,
        ordered,
        items_by_cat,
        when_short,
        missing_categories=sorted(missing_cats),
    )
    rendered_count = sum(len(v) for v in items_by_cat.values())

    json.dump(
        {
            "supermarket": args.supermarket,
            "count": rendered_count,
            "generated_at": when_full,
            "markdown": markdown,
        },
        sys.stdout,
        ensure_ascii=False,
    )
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
