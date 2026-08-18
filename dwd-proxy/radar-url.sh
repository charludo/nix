#!/usr/bin/env bash
# Print a dwd-proxy GetMap URL for a view centred on a latitude/longitude.
#
# The proxy speaks WMS, so a browsable URL needs an EPSG:3857 bounding box and a
# TIME on the five-minute grid the radar product publishes on. This works both
# out so you can paste the result straight into a browser.
set -euo pipefail

readonly DEFAULT_PORT=8080
readonly DEFAULT_VIEW_KM=100
readonly DEFAULT_SIZE=900
readonly DEFAULT_AGE_MIN=15
readonly LAYER='dwd:Radar_wn-product_1x1km_ger'

usage() {
  cat >&2 <<EOF
Usage: ${0##*/} <latitude> <longitude> [options]

Prints a GetMap URL for a square view centred on the given point.

Options:
  -p, --port PORT       Proxy port (default: ${DEFAULT_PORT})
  -v, --view-km KM      Half-width of the view, in ground kilometres
                        (default: ${DEFAULT_VIEW_KM}). Keep this below the proxy's
                        -radius-km or the request falls through to upstream.
  -s, --size PX         Output width and height in pixels (default: ${DEFAULT_SIZE})
  -a, --age MINUTES     How far back to pick the frame (default: ${DEFAULT_AGE_MIN}).
                        Recent frames may still be unconfirmed nowcasts.
  -o, --open            Open the URL with xdg-open instead of printing it
  -h, --help            Show this help

Example:
  ${0##*/} 50.6 8.5 --open
EOF
}

die() {
  echo "${0##*/}: $*" >&2
  exit 1
}

lat=""
lon=""
port=$DEFAULT_PORT
view_km=$DEFAULT_VIEW_KM
size=$DEFAULT_SIZE
age_min=$DEFAULT_AGE_MIN
open_it=0

while [[ $# -gt 0 ]]; do
  case "$1" in
  -p | --port)
    port="${2:-}"
    shift 2
    ;;
  -v | --view-km)
    view_km="${2:-}"
    shift 2
    ;;
  -s | --size)
    size="${2:-}"
    shift 2
    ;;
  -a | --age)
    age_min="${2:-}"
    shift 2
    ;;
  -o | --open)
    open_it=1
    shift
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  -*) die "unknown option $1" ;;
  *)
    if [[ -z $lat ]]; then
      lat="$1"
    elif [[ -z $lon ]]; then
      lon="$1"
    else
      die "unexpected argument $1"
    fi
    shift
    ;;
  esac
done

[[ -n $lat && -n $lon ]] || {
  usage
  exit 2
}

is_number() { [[ $1 =~ ^-?[0-9]+([.][0-9]+)?$ ]]; }
is_number "$lat" || die "latitude must be a number, got '$lat'"
is_number "$lon" || die "longitude must be a number, got '$lon'"
is_number "$view_km" || die "view half-width must be a number, got '$view_km'"

awk -v lat="$lat" -v lon="$lon" 'BEGIN {
  if (lat < -85 || lat > 85) { print "latitude out of range (-85..85)" > "/dev/stderr"; exit 1 }
  if (lon < -180 || lon > 180) { print "longitude out of range (-180..180)" > "/dev/stderr"; exit 1 }
}' || exit 1

# Project the centre to EPSG:3857 and expand by the view radius. Web Mercator
# stretches distances by 1/cos(latitude), so the ground kilometres asked for have
# to be divided by that cosine to become the projected metres a BBOX is measured
# in. awk has no tan(), hence sin()/cos().
read -r min_x min_y max_x max_y < <(
  awk -v lat="$lat" -v lon="$lon" -v view_km="$view_km" 'BEGIN {
    pi = atan2(0, -1)
    m  = 20037508.342789244
    cx = lon * m / 180
    a  = (90 + lat) * pi / 360
    cy = log(sin(a) / cos(a)) * m / pi
    h  = (view_km * 1000) / cos(lat * pi / 180)
    printf "%.6f %.6f %.6f %.6f\n", cx - h, cy - h, cx + h, cy + h
  }'
)

# Snap onto the five-minute grid the radar product publishes on.
now_epoch=$(date -u +%s)
frame_epoch=$(((now_epoch - age_min * 60) / 300 * 300))
frame_time=$(date -u -d "@${frame_epoch}" +%Y-%m-%dT%H:%M:%SZ)

base="http://127.0.0.1:${port}/geoserver/dwd/wms"
url="${base}?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap"
url+="&LAYERS=${LAYER}&STYLES=&FORMAT=image/png&TRANSPARENT=true"
url+="&CRS=EPSG:3857&BBOX=${min_x},${min_y},${max_x},${max_y}"
url+="&WIDTH=${size}&HEIGHT=${size}&TIME=${frame_time}"

# A dead proxy and a dry sky both render as "nothing happened" in a browser, so
# say which one this is before handing over the URL.
if ! curl -fsS -o /dev/null --max-time 3 "http://127.0.0.1:${port}/healthz" 2>/dev/null; then
  cat >&2 <<EOF
warning: nothing is answering on port ${port}.

Start the proxy first, e.g.:
  nix run . -- -lat ${lat} -lon ${lon} -radius-km 250 -addr 127.0.0.1:${port} -state-dir /tmp/dwd-proxy

EOF
elif ! curl -fsS -o /dev/null --max-time 3 "http://127.0.0.1:${port}/readyz" 2>/dev/null; then
  echo "note: the proxy is up but still warming; the first pass takes about a minute." >&2
fi

if [[ $open_it -eq 1 ]]; then
  command -v xdg-open >/dev/null || die "xdg-open not found"
  xdg-open "$url" >/dev/null 2>&1 &
  echo "$url"
else
  echo "$url"
fi
