"""Push Nix-declared ZHA device + entity area assignments into HA.

Two manifests, both optional:

  --manifest         [{ieee, name, area_slug}]
      ZHA pass: set name_by_user + area_id on the matching ZHA device.

  --entity-manifest  [{entity_id, area_slug}]
      Generic pass: look up entity in HA's registry, prefer setting
      area_id on its owning device, fall back to entity-level area.

Idempotent; safe to re-run.
"""

import argparse
import asyncio
import json
import re
import sys

import aiohttp


# Mirrors lib/home-assistant.nix `mkSlug`. Keep in sync.
_UMLAUTS = str.maketrans({
    "ä": "a", "ö": "o", "ü": "u",
    "Ä": "a", "Ö": "o", "Ü": "u",
    "ß": "ss",
})


def slugify(name: str) -> str:
    s = name.translate(_UMLAUTS).lower()
    s = re.sub(r"[^a-z0-9]+", "_", s)
    return s.strip("_")


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--url", required=True,
                   help="HA base URL, e.g. http://127.0.0.1:8123")
    p.add_argument("--token-file", required=True,
                   help="Path to a file containing a long-lived access token")
    p.add_argument("--manifest", default=None,
                   help="JSON manifest of ZHA devices: [{ieee, name, area_slug}, ...]")
    p.add_argument("--entity-manifest", default=None,
                   help="JSON manifest of entities: [{entity_id, area_slug}, ...]")
    p.add_argument("--attempts", type=int, default=10,
                   help="Number of full retry attempts (default: 10)")
    p.add_argument("--retry-delay", type=float, default=15.0,
                   help="Seconds to wait between attempts (default: 15)")
    return p.parse_args()


class Client:
    def __init__(self, ws: aiohttp.ClientWebSocketResponse) -> None:
        self._ws = ws
        self._next_id = 0

    async def call(self, payload: dict) -> dict:
        self._next_id += 1
        payload["id"] = self._next_id
        await self._ws.send_json(payload)
        async for msg in self._ws:
            if msg.type != aiohttp.WSMsgType.TEXT:
                continue
            d = json.loads(msg.data)
            if d.get("id") == self._next_id:
                return d
        raise RuntimeError("websocket closed before reply")


async def reconcile_zha(client: Client, devices: list[dict]) -> None:
    resp = await client.call({"type": "zha/devices"})
    if not resp.get("success", True):
        raise RuntimeError(f"zha/devices failed: {resp}")
    zha_by_ieee = {d["ieee"].lower(): d for d in resp["result"]}

    # Snapshot entity registry once; used to rebuild entity_ids per device.
    ent_resp = await client.call({"type": "config/entity_registry/list"})
    if not ent_resp.get("success", True):
        raise RuntimeError(f"entity_registry/list failed: {ent_resp}")
    entities_by_device: dict[str, list[dict]] = {}
    for e in ent_resp["result"]:
        if e.get("device_id"):
            entities_by_device.setdefault(e["device_id"], []).append(e)

    # The entity registry doesn't carry device_class; fetch it from the
    # live state attributes instead (locale-independent, integration-
    # set). Used as a fallback when translation_key isn't populated, to
    # avoid landing on the localized original_name.
    states_resp = await client.call({"type": "get_states"})
    state_dc: dict[str, str] = {}
    for s in (states_resp.get("result") or []):
        dc = (s.get("attributes") or {}).get("device_class")
        if dc:
            state_dc[s["entity_id"]] = dc

    missing, failed = [], []
    for dev in devices:
        z = zha_by_ieee.get(dev["ieee"].lower())
        if not z:
            missing.append(dev["ieee"])
            continue
        update = await client.call({
            "type": "config/device_registry/update",
            "device_id": z["device_reg_id"],
            "area_id": dev["area_slug"],
            "name_by_user": dev["name"],
        })
        if not update.get("success"):
            failed.append((dev["ieee"], update))
            print(f"FAIL zha {dev['ieee']}: {update}", file=sys.stderr)
            continue
        print(f"ok  zha {dev['ieee']} -> {dev['name']!r} @ {dev['area_slug']}")

        await _rename_device_entities(
            client, z, dev["name"],
            entities_by_device.get(z["device_reg_id"], []),
            state_dc,
            dev.get("entities") or {},
        )
    if missing:
        raise RuntimeError(f"ZHA missing IEEEs (still pairing?): {missing}")
    if failed:
        raise RuntimeError(f"{len(failed)} ZHA device updates failed")


async def _rename_device_entities(
    client: Client, zha_dev: dict, new_name: str, entities: list[dict],
    state_device_class: dict[str, str],
    declared: dict[str, list[str]],
) -> None:
    """For each HA entity owned by the device, match it against the
    suffixes the Nix manifest declared for its domain (via
    translation_key or device_class — both locale-independent) and
    rename to `<domain>.<device_slug>` (primary) or
    `<domain>.<device_slug>_<declared_suffix>`. The Nix declaration is
    the source of truth: an entity not matched by anything declared is
    left alone (we don't want to invent a suffix from a localized
    original_name and end up with a German-coupled entity_id)."""
    new_slug = slugify(new_name)

    for ent in entities:
        eid = ent["entity_id"]
        domain = eid.split(".", 1)[0]
        declared_suffixes = declared.get(domain) or []
        if not declared_suffixes:
            continue

        # Match keys, in priority order. translation_key is the
        # integration's stable id when present; device_class covers
        # most sensors/binary_sensors. Both are locale-independent.
        match_keys = [k for k in (
            ent.get("translation_key"),
            state_device_class.get(eid),
        ) if k]

        matched: str | None = None
        for k in match_keys:
            if k in declared_suffixes:
                matched = k
                break
        # No usable key (e.g. ZHA's primary light has neither a
        # translation_key nor a device_class) → fall back to the
        # single declared suffix, but only if the user declared
        # exactly one entity in this domain. Otherwise we'd be
        # guessing which of N to rename to and could collide.
        if matched is None and not match_keys and len(declared_suffixes) == 1:
            matched = declared_suffixes[0]

        if matched is None:
            print(f"warn rename {eid}: no declared suffix matched "
                  f"(domain={domain}, declared={declared_suffixes}, keys={match_keys})",
                  file=sys.stderr)
            continue

        # Mirrors the same primary-entity rule in devices.nix: when
        # the declared suffix equals the domain, drop it.
        if matched == domain:
            new_eid = f"{domain}.{new_slug}"
        else:
            new_eid = f"{domain}.{new_slug}_{matched}"

        if new_eid == eid:
            continue
        upd = await client.call({
            "type": "config/entity_registry/update",
            "entity_id": eid,
            "new_entity_id": new_eid,
        })
        if not upd.get("success"):
            print(f"FAIL rename {eid} -> {new_eid}: {upd}", file=sys.stderr)
        else:
            print(f"ok  rename {eid} -> {new_eid}")


async def reconcile_entities(client: Client, entities: list[dict]) -> None:
    # Pull the entity registry once and index by entity_id; cheaper than
    # one round-trip per lookup, and avoids errors for entities not yet
    # provisioned (we just skip them with a warning).
    resp = await client.call({"type": "config/entity_registry/list"})
    if not resp.get("success", True):
        raise RuntimeError(f"entity_registry/list failed: {resp}")
    by_id = {e["entity_id"]: e for e in resp["result"]}

    skipped, failed = [], []
    for ent in entities:
        eid = ent["entity_id"]
        area = ent["area_slug"]
        e = by_id.get(eid)
        if not e:
            skipped.append(eid)
            print(f"skip {eid}: not in entity registry yet", file=sys.stderr)
            continue
        if e.get("device_id"):
            payload = {
                "type": "config/device_registry/update",
                "device_id": e["device_id"],
                "area_id": area,
            }
            scope = "device"
        else:
            payload = {
                "type": "config/entity_registry/update",
                "entity_id": eid,
                "area_id": area,
            }
            scope = "entity"
        upd = await client.call(payload)
        if not upd.get("success"):
            failed.append((eid, upd))
            print(f"FAIL ent {eid}: {upd}", file=sys.stderr)
        else:
            print(f"ok  ent {eid} -> {area} ({scope})")
    if failed:
        raise RuntimeError(f"{len(failed)} entity area updates failed")
    # Missing entities are non-fatal: integrations may not have loaded.


async def reconcile(url: str, token: str,
                    zha_devices: list[dict] | None,
                    entities: list[dict] | None) -> None:
    async with aiohttp.ClientSession() as session:
        async with session.ws_connect(f"{url}/api/websocket") as ws:
            hello = json.loads((await ws.receive()).data)
            if hello.get("type") != "auth_required":
                raise RuntimeError(f"unexpected hello: {hello}")
            await ws.send_json({"type": "auth", "access_token": token})
            ok = json.loads((await ws.receive()).data)
            if ok.get("type") != "auth_ok":
                raise RuntimeError(f"auth failed: {ok}")

            client = Client(ws)
            if zha_devices:
                await reconcile_zha(client, zha_devices)
            if entities:
                await reconcile_entities(client, entities)


def _load(path: str | None) -> list[dict] | None:
    if not path:
        return None
    with open(path) as f:
        return json.load(f)


async def main() -> None:
    args = parse_args()
    with open(args.token_file) as f:
        token = f.read().strip()
    zha_devices = _load(args.manifest)
    entities = _load(args.entity_manifest)
    if not zha_devices and not entities:
        raise SystemExit("at least one of --manifest / --entity-manifest required")

    last = None
    for attempt in range(1, args.attempts + 1):
        try:
            await reconcile(args.url, token, zha_devices, entities)
            return
        except Exception as e:
            last = e
            print(f"attempt {attempt} failed: {e}", file=sys.stderr)
            if attempt < args.attempts:
                await asyncio.sleep(args.retry_delay)
    raise SystemExit(f"giving up after {args.attempts} attempts: {last}")


if __name__ == "__main__":
    asyncio.run(main())
