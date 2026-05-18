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
import sys

import aiohttp


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
        else:
            print(f"ok  zha {dev['ieee']} -> {dev['name']!r} @ {dev['area_slug']}")
    if missing:
        raise RuntimeError(f"ZHA missing IEEEs (still pairing?): {missing}")
    if failed:
        raise RuntimeError(f"{len(failed)} ZHA device updates failed")


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
