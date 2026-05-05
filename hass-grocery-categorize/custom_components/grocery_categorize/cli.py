"""CLI: ``grocery-categorize <items...>`` — outputs JSON with category
assignments. Useful for quick testing outside HA.
"""

from __future__ import annotations

import argparse
import json
import sys

from .classifier import DEFAULT_THRESHOLD


def main() -> int:
    parser = argparse.ArgumentParser(
        prog="grocery-categorize",
        description="Categorise shopping-list items via fuzzy matching.",
    )
    parser.add_argument(
        "items",
        nargs="*",
        help="Items to categorise. If none, read newline-separated from stdin.",
    )
    parser.add_argument(
        "--threshold",
        type=float,
        default=DEFAULT_THRESHOLD,
        help=(
            f"rapidfuzz score cutoff below which items fall into "
            f"\"Sonstiges\" (default: {DEFAULT_THRESHOLD})."
        ),
    )
    args = parser.parse_args()

    items = args.items or [line.strip() for line in sys.stdin if line.strip()]
    if not items:
        print("[]")
        return 0

    from .classifier import Classifier

    clf = Classifier(threshold=args.threshold)
    matches = clf.classify(items)
    json.dump(
        [m.to_dict() for m in matches],
        sys.stdout,
        ensure_ascii=False,
        indent=2,
    )
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
