"""Push Nix-declared ZHA device names + areas into HA's device registry.

Reads a JSON manifest of `[{ieee, name, area_slug}]`, talks to the local
Home Assistant websocket API, and for each entry sets `name_by_user` and
`area_id` on the matching ZHA device. Idempotent; safe to re-run.
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
    p.add_argument("--manifest", required=True,
                   help="Path to JSON manifest: [{ieee, name, area_slug}, ...]")
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


async def reconcile(url: str, token: str, devices: list[dict]) -> None:
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
                    print(f"FAIL {dev['ieee']}: {update}", file=sys.stderr)
                else:
                    print(f"ok  {dev['ieee']} -> {dev['name']!r} @ {dev['area_slug']}")
            if missing:
                raise RuntimeError(f"ZHA missing IEEEs (still pairing?): {missing}")
            if failed:
                raise RuntimeError(f"{len(failed)} device updates failed")


async def main() -> None:
    args = parse_args()
    with open(args.token_file) as f:
        token = f.read().strip()
    with open(args.manifest) as f:
        devices = json.load(f)

    last = None
    for attempt in range(1, args.attempts + 1):
        try:
            await reconcile(args.url, token, devices)
            return
        except Exception as e:
            last = e
            print(f"attempt {attempt} failed: {e}", file=sys.stderr)
            if attempt < args.attempts:
                await asyncio.sleep(args.retry_delay)
    raise SystemExit(f"giving up after {args.attempts} attempts: {last}")


if __name__ == "__main__":
    asyncio.run(main())
