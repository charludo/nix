"""Embedding-based shopping-list categoriser for Home Assistant.

Setup flow:

  1. YAML config under ``grocery_categorize:`` declares the todo entity
     and a map of supermarket → ordered list of category names.
  2. We register a ``grocery_categorize.refresh`` service that fetches
     uncompleted todo items, runs the classifier, and stores the result
     keyed by supermarket name in ``hass.data[DOMAIN][DATA_RESULTS]``.
  3. The ``sensor`` platform creates one entity per supermarket whose
     state is the item count and whose ``markdown`` attribute holds the
     rendered list. Entities subscribe to refresh callbacks so a
     service call updates them immediately.

The Classifier is constructed lazily on the first refresh — model load
takes ~5 s, so we don't pay that cost at HA startup.
"""

from __future__ import annotations

import logging
from datetime import datetime
from typing import Any

import voluptuous as vol
from homeassistant.const import Platform
from homeassistant.core import HomeAssistant, ServiceCall, SupportsResponse
from homeassistant.helpers import config_validation as cv, discovery
from homeassistant.helpers.typing import ConfigType

from .classifier import FALLBACK_CATEGORY
from .const import (
    CONF_SUPERMARKETS,
    CONF_TODO_ENTITY,
    DATA_CLASSIFIER,
    DATA_CONFIG,
    DATA_LISTENERS,
    DATA_RESULT,
    DEFAULT_TODO_ENTITY,
    DOMAIN,
    SERVICE_REFRESH,
)
from .print import render_markdown
from .print_view import PrintView

_LOGGER = logging.getLogger(__name__)


_COMPOUND_LEN_DELTA = 3
_COMPOUND_MIN_ANCHOR_LEN = 4


def _is_compound(item: str, anchor: str) -> bool:
    """Does ``item`` contain ``anchor`` as a meaningful substring?

    Two guards: anchor ≥ 4 chars (so ``"gin"`` can't hijack
    ``"obergine"``), and the input is meaningfully longer (≥ 3 extra
    chars) so a one-letter typo doesn't get re-interpreted as a
    compound. Position of the substring inside the input doesn't
    matter — German compounds usually have the noun at the end, but
    English/brand names and the occasional middle-position substring
    are valid too.
    """
    raw_lo = item.lower()
    anchor_lo = anchor.lower()
    return (
        " " not in raw_lo
        and len(anchor_lo) >= _COMPOUND_MIN_ANCHOR_LEN
        and anchor_lo in raw_lo
        and len(raw_lo) - len(anchor_lo) >= _COMPOUND_LEN_DELTA
    )


def _eq_key(s: str) -> str:
    """Lowercase + collapse whitespace — for case/whitespace-insensitive
    comparison of inputs against anchors. STT sometimes emits trailing
    spaces or odd internal spacing that we want to treat as identity."""
    return " ".join(s.lower().split())


def _dedup_preserve_order(items: list[str]) -> list[str]:
    seen: set[str] = set()
    out: list[str] = []
    for s in items:
        k = _eq_key(s)
        if k in seen:
            continue
        seen.add(k)
        out.append(s)
    return out


def _format_group(
    matches: list,
    anchor: Optional[str],
    is_compound: bool = False,
) -> str:
    """Render one display-key group for the markdown output.

    - ``anchor=None``, ``is_compound=False``: Sonstiges item the
      classifier couldn't place. Show the input verbatim — it's
      probably mangled and the user will fix categorisation manually,
      so we don't title-case potential garbage.
    - ``anchor=None``, ``is_compound=True``: matched but the input is
      a compound that extends the anchor (Voll+milch, Edelstahl+
      reiniger). Title-case the input — STT often delivers lowercase,
      and a clean ``"Edelstahlreiniger"`` reads better than
      ``"edelstahlreiniger"``.
    - With an anchor, *all* contributing user inputs go in the
      parenthetical (de-duplicated). If every distinct input is just
      the anchor with different casing/whitespace, drop the parens
      and use the title-cased anchor instead.
    """
    inputs = _dedup_preserve_order([m.item for m in matches])
    if anchor is None:
        return inputs[0].title() if is_compound else inputs[0]
    # The anchor here is already the canonical form from the classifier
    # (title-cased for plain-string anchors, used as-is for list-form
    # anchors). No further .title() — it would mangle multi-word
    # canonicals like ``"Rotkohl im Glas"`` → ``"Rotkohl Im Glas"``.
    distinct_keys = {_eq_key(i) for i in inputs}
    if distinct_keys == {_eq_key(anchor)}:
        return anchor
    return f"{anchor} *({', '.join(inputs)})*"

CONFIG_SCHEMA = vol.Schema(
    {
        DOMAIN: vol.Schema(
            {
                vol.Optional(CONF_TODO_ENTITY, default=DEFAULT_TODO_ENTITY): cv.entity_id,
                vol.Required(CONF_SUPERMARKETS): vol.Schema(
                    {cv.string: vol.All(cv.ensure_list, [cv.string])}
                ),
            }
        )
    },
    extra=vol.ALLOW_EXTRA,
)

SERVICE_SCHEMA = vol.Schema(
    {
        vol.Required("supermarket"): cv.string,
    }
)


async def async_setup(hass: HomeAssistant, config: ConfigType) -> bool:
    conf = config.get(DOMAIN)
    if conf is None:
        return True

    hass.data.setdefault(
        DOMAIN,
        {
            DATA_CONFIG: conf,
            DATA_CLASSIFIER: None,
            DATA_RESULT: {},
            DATA_LISTENERS: [],
        },
    )

    # rapidfuzz Classifier is cheap to construct (just embeds anchor
    # normalisation), so we build it eagerly at setup.
    from .classifier import Classifier

    hass.data[DOMAIN][DATA_CLASSIFIER] = Classifier()

    async def _fetch_items() -> list[str]:
        todo_entity = conf[CONF_TODO_ENTITY]
        try:
            response = await hass.services.async_call(
                "todo",
                "get_items",
                {"entity_id": todo_entity, "status": ["needs_action"]},
                blocking=True,
                return_response=True,
            )
        except Exception:
            _LOGGER.exception(
                "grocery_categorize: todo.get_items on %s failed", todo_entity
            )
            return []
        bucket = (response or {}).get(todo_entity) or {}
        items = bucket.get("items") or []
        return [it.get("summary", "") for it in items if it.get("summary")]

    async def _refresh_one(supermarket: str) -> dict[str, Any]:
        ordered = conf[CONF_SUPERMARKETS].get(supermarket)
        if ordered is None:
            raise ValueError(f"unknown supermarket: {supermarket!r}")

        items = await _fetch_items()
        when_full = datetime.now().strftime("%Y-%m-%d %H:%M")
        when_short = datetime.now().strftime("%Y-%m-%d")

        if not items:
            markdown = f"# {when_short} — {supermarket}\n\n_Keine Einträge._\n"
            result = {
                "supermarket": supermarket,
                "count": 0,
                "generated_at": when_full,
                "markdown": markdown,
            }
        else:
            clf = hass.data[DOMAIN][DATA_CLASSIFIER]
            matches = await hass.async_add_executor_job(clf.classify, items)
            # If the supermarket explicitly includes Sonstiges, items
            # whose detected category isn't in the order list spill into
            # it. If it doesn't, those items are silently dropped from
            # this supermarket's view (per user preference).
            # Classifier output is authoritative; the supermarket's
            # category list is purely a filter on what to display.
            #
            # - If an item's classified category is in `ordered`, show
            #   it under that category.
            # - If the item is genuinely Sonstiges (classifier wasn't
            #   confident enough), show it under Sonstiges *only* if the
            #   supermarket includes Sonstiges in its order.
            # - Otherwise (item correctly classified to a category this
            #   supermarket doesn't carry), drop it entirely. e.g. a
            #   Käse item won't show up in an Apotheke-only view.
            allowed = set(ordered)
            include_fallback = FALLBACK_CATEGORY in allowed

            # Group within each category by display key, so that
            # multiple inputs that match the same anchor (or compound
            # form) collapse into one entry with a joined parenthetical.
            grouped: dict[str, dict[tuple, list]] = {}
            # Track categories that the classifier confidently placed
            # items in, but the supermarket doesn't carry. Surfaced at
            # the bottom of the printed list as a hint that items live
            # in a different store. Sonstiges (genuinely unclassified)
            # is not a "missing category" — different signal.
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

                if not m.matched_anchor:
                    key = ("input", m.item.lower())
                    anchor: Optional[str] = None
                elif _is_compound(m.item, m.matched_anchor):
                    key = ("input", m.item.lower())
                    anchor = None
                else:
                    key = ("anchor", m.matched_anchor.lower())
                    anchor = m.matched_anchor
                grouped.setdefault(cat, {}).setdefault(key, []).append(m)

            items_by_cat: dict[str, list[str]] = {}
            count = 0
            for cat, groups in grouped.items():
                rendered: list[str] = []
                for key, ms in groups.items():
                    if key[0] == "anchor":
                        rendered.append(
                            _format_group(ms, ms[0].matched_anchor)
                        )
                    else:
                        # "input" key: either Sonstiges (no anchor) or
                        # a compound (matched anchor, but compound rule
                        # said keep the input). Compound case gets
                        # title-cased.
                        is_compound = ms[0].matched_anchor is not None
                        rendered.append(
                            _format_group(ms, None, is_compound=is_compound)
                        )
                items_by_cat[cat] = rendered
                count += len(rendered)

            markdown = render_markdown(
                supermarket,
                ordered,
                items_by_cat,
                when_short,
                missing_categories=sorted(missing_cats),
            )
            result = {
                "supermarket": supermarket,
                "count": count,
                "generated_at": when_full,
                "markdown": markdown,
            }

        hass.data[DOMAIN][DATA_RESULT] = result
        for listener in hass.data[DOMAIN][DATA_LISTENERS]:
            listener()
        return result

    async def _refresh(call: ServiceCall) -> dict[str, Any]:
        return await _refresh_one(call.data["supermarket"])

    hass.services.async_register(
        DOMAIN,
        SERVICE_REFRESH,
        _refresh,
        schema=SERVICE_SCHEMA,
        supports_response=SupportsResponse.OPTIONAL,
    )

    hass.http.register_view(PrintView(hass))

    hass.async_create_task(
        discovery.async_load_platform(hass, Platform.SENSOR, DOMAIN, {}, config)
    )

    return True
