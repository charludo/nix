"""HTTP view that renders the latest list as a print-ready HTML page.

Returns ``text/html`` with the markdown converted to a minimal styled
document plus a ``window.print()`` call at the end of body, so the
browser's native print dialog opens immediately when the user
navigates here. From the dashboard, a Print button does just that:

    tap_action:
      action: url
      url_path: /api/grocery_categorize/print

Eventually this is also where a thermal-receipt-printer integration
would slot in: instead of (or in addition to) returning HTML, render to
ESC/POS bytes and POST to the printer's network endpoint. Until then,
the browser handles it.
"""

from __future__ import annotations

import html
import logging

import markdown as _md
from aiohttp import web
from homeassistant.components.http import HomeAssistantView
from homeassistant.core import HomeAssistant

from .const import DATA_RESULT, DOMAIN

_LOGGER = logging.getLogger(__name__)


_PAGE_TEMPLATE = """<!DOCTYPE html>
<html lang="de">
<head>
<meta charset="utf-8">
<title>Einkaufsliste{title_suffix}</title>
<style>
  @page {{ margin: 12mm; }}
  body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
         font-size: 14pt; line-height: 1.4; color: #000; }}
  h2 {{ margin: 16pt 0 4pt 0; padding-bottom: 2pt;
        border-bottom: 1pt solid #000; font-size: 16pt; }}
  ul {{ margin: 0 0 8pt 0; padding-left: 20pt; }}
  li {{ margin: 2pt 0; }}
  .meta {{ margin: 0; color: #444; font-size: 11pt; }}
  @media screen {{ body {{ max-width: 600px; margin: 24px auto; padding: 0 16px; }} }}
</style>
</head>
<body>
{body}
<script>window.addEventListener('load', () => window.print());</script>
</body>
</html>
"""


class PrintView(HomeAssistantView):
    url = "/api/grocery_categorize/print"
    name = "api:grocery_categorize:print"
    # Auth disabled because `tap_action: url` opens a new tab outside
    # HA's frontend and HA's bearer-token auth doesn't carry along.
    # The endpoint exposes only the shopping list — low sensitivity.
    # Restrict via reverse-proxy / firewall if needed.
    requires_auth = False

    def __init__(self, hass: HomeAssistant) -> None:
        self._hass = hass

    async def get(self, request: web.Request) -> web.Response:
        result = self._hass.data.get(DOMAIN, {}).get(DATA_RESULT) or {}
        markdown = result.get("markdown") or "_Noch keine Liste generiert._"
        supermarket = result.get("supermarket") or ""
        suffix = f" — {supermarket}" if supermarket else ""
        body = _md.markdown(markdown, extensions=["extra", "sane_lists"])
        page = _PAGE_TEMPLATE.format(
            title_suffix=html.escape(suffix),
            body=body,
        )
        return web.Response(text=page, content_type="text/html", charset="utf-8")
