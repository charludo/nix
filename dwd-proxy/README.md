# dwd-proxy

A caching proxy and prefetcher for the [DWD radar WMS service](https://maps.dwd.de/geoserver/dwd/wms).

It fetches a wide area around a fixed centre point as **one raster per time
step**, then derives every tile a client asks for by cropping and scaling those
rasters locally. Requests it cannot answer are relayed upstream unchanged, so it
is safe to point a client at it wholesale.

## Why

The upstream service sends **no cache headers at all** — no `Cache-Control`, no
`ETag`, no `Last-Modified`, no `Expires`. Browsers therefore re-fetch every tile
on every page load, and a tile-based client can easily issue hundreds of requests
to redraw one animation. This proxy fixes both ends:

- **Upstream**: roughly one request per five-minute frame, instead of dozens of
  tiles per frame. A single `GetMap` can cover the whole area at once.
- **Downstream**: frames whose valid time has passed are immutable and are served
  with a one-year `immutable` lifetime, so clients stop asking for them entirely.

## How it decides what is cacheable

A frame is served as immutable only once it has been **observed twice, at least
one model run apart, with identical bytes, and has aged past ten minutes**.
Everything else gets a short lifetime and is re-examined when the next run lands.

The age requirement is not redundant with byte-stability. For a minute or two
after a frame's nominal time, DWD serves the *previous* frame's raster under the
new timestamp — with `GetCapabilities` already advertising the new one, so there
is no metadata signal to distinguish it. Two fetches landing inside that window
agree with each other, and without the age requirement that agreement would
freeze a known-wrong duplicate as immutable for a year, with no way to invalidate
it short of wiping the state directory.

The obvious rule — treat any frame whose valid time has passed as final, since
radar that has already fallen cannot change — is wrong in practice. While DWD is
publishing a run, the service answers with HTTP 200 and a well-formed PNG that is
partially or **entirely blank**, for past valid times as much as future ones.
Measured against the live service, a first pass captured frames at ~16% coverage
and several completely empty, where the settled values were ~35–40%. Trusting the
first response would pin those artefacts behind a one-year immutable lifetime.

New runs are detected from the `REFERENCE_TIME` dimension in `GetCapabilities`,
so frames are only re-examined when something could actually have changed. If
that dimension is missing, the proxy falls back to re-examining every tick.

Note that `REFERENCE_TIME` cannot be *pinned*: passing an explicit value returns
the latest run regardless, so there is no way to make a frame's URL immutable at
the source. That is why freshness is established here, by observation.

## Resampling

Tiles are derived with **nearest-neighbour** sampling, deliberately. The radar
product is categorical — each colour encodes a reflectivity class — and clients
may run palette-sensitive filters over the pixels. Interpolating would invent
colours that sit between two classes and belong to neither.

Against the live service, tiles derived from the cache come out byte-identical to
the same tile fetched directly from DWD when the pixel grids align, and differ
only in antialiasing detail otherwise.

## Sizing

`-radius-km` and `-master-size` together set the cache's ground resolution. The
source product is a 1 km grid, so there is nothing to gain below that:

| radius | master size | ground resolution | PNG per frame |
| ------ | ----------- | ----------------- | ------------- |
| 250 km | 1024        | ~490 m/px         | ~50 KB        |
| 250 km | 2048        | ~240 m/px         | ~330 KB       |

Encoded frames are all held in memory and on disk; decoded rasters are kept only
for the few most recently used, since a decoded 2048×2048 RGBA raster costs
16 MiB against roughly 330 KiB encoded (`-decoded-cache`).

## Usage

```console
$ dwd-proxy -lat 52.52 -lon 13.405 -radius-km 250 -addr :8080
```

Run `dwd-proxy -help` for the full set of flags.

To eyeball the result, `radar-url.sh` builds a browsable GetMap URL for a view
centred on a point, working out the EPSG:3857 bounding box and snapping `TIME`
onto the five-minute grid:

```console
$ ./radar-url.sh 50.6 8.5 --open
```

It warns if nothing is listening, or if the proxy is up but still warming. Note
that the radar layer is transparent where there is no rain, so a dry sky and a
broken setup look alike in a browser — check `/metrics` to tell them apart.

Endpoints:

- `/healthz` — liveness.
- `/readyz` — 503 until the first prefetch pass completes.
- `/metrics` — Prometheus metrics, including a `result` breakdown of how each
  request was served (`hit-settled`, `hit-forecast`, `not-modified`,
  `miss-bbox`, `miss-time`, `proxied`, …). A steady stream of `miss-bbox` means
  clients are panning outside the prefetched area — raise `-radius-km`.
- Everything else is treated as a WMS request.

## NixOS

```nix
{
  inputs.dwd-proxy.url = "github:charludo/dwd-proxy";

  # in your host configuration:
  imports = [ inputs.dwd-proxy.nixosModules.default ];

  services.dwd-proxy = {
    enable = true;
    latitude = 52.52;
    longitude = 13.405;
    radiusKm = 250;
    port = 8080;
  };
}
```

The module runs the service under `DynamicUser` with a hardened sandbox and
persists frames in `/var/lib/dwd-proxy`.
