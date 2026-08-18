// Package geo provides the EPSG:3857 (Web Mercator) math the proxy needs to
// relate a client's requested bounding box to the cached master raster.
package geo

import (
	"fmt"
	"math"
	"strconv"
	"strings"
)

// MercatorMax is half the width of the EPSG:3857 world, in projected metres.
const MercatorMax = 20037508.342789244

// BBox is an axis-aligned bounding box in EPSG:3857 metres.
//
// As in the WMS/OGC convention, MinY is the southern edge: y grows northwards,
// which is the opposite of the row order of a raster image.
type BBox struct {
	MinX, MinY, MaxX, MaxY float64
}

// Width returns the east-west extent in projected metres.
func (b BBox) Width() float64 { return b.MaxX - b.MinX }

// Height returns the north-south extent in projected metres.
func (b BBox) Height() float64 { return b.MaxY - b.MinY }

// Valid reports whether the box is non-degenerate.
func (b BBox) Valid() bool {
	return b.Width() > 0 && b.Height() > 0 &&
		!math.IsNaN(b.MinX) && !math.IsNaN(b.MinY) &&
		!math.IsNaN(b.MaxX) && !math.IsNaN(b.MaxY)
}

// Contains reports whether other lies entirely within b.
//
// A small tolerance absorbs the rounding that Leaflet's float formatting
// introduces when it prints tile bounds, which would otherwise push a tile that
// is geometrically identical to a master edge just outside it.
func (b BBox) Contains(other BBox) bool {
	const tol = 1e-6
	return other.MinX >= b.MinX-tol && other.MaxX <= b.MaxX+tol &&
		other.MinY >= b.MinY-tol && other.MaxY <= b.MaxY+tol
}

// String renders the box in the "minx,miny,maxx,maxy" form WMS expects.
func (b BBox) String() string {
	f := func(v float64) string { return strconv.FormatFloat(v, 'f', -1, 64) }
	return f(b.MinX) + "," + f(b.MinY) + "," + f(b.MaxX) + "," + f(b.MaxY)
}

// ParseBBox parses a WMS "minx,miny,maxx,maxy" bounding box.
//
// This is only ever used for EPSG:3857, where the axis order is easting first.
// (WMS 1.3.0 flips to latitude-first for EPSG:4326, but that CRS never reaches
// us: the card leaves the layer CRS at the map default.)
func ParseBBox(s string) (BBox, error) {
	parts := strings.Split(s, ",")
	if len(parts) != 4 {
		return BBox{}, fmt.Errorf("bbox %q: want 4 comma-separated values, got %d", s, len(parts))
	}
	var v [4]float64
	for i, p := range parts {
		f, err := strconv.ParseFloat(strings.TrimSpace(p), 64)
		if err != nil {
			return BBox{}, fmt.Errorf("bbox %q: component %d: %w", s, i, err)
		}
		v[i] = f
	}
	b := BBox{MinX: v[0], MinY: v[1], MaxX: v[2], MaxY: v[3]}
	if !b.Valid() {
		return BBox{}, fmt.Errorf("bbox %q: degenerate or non-finite", s)
	}
	return b, nil
}

// LonLatToMercator projects WGS84 degrees to EPSG:3857 metres.
func LonLatToMercator(lon, lat float64) (x, y float64) {
	// Clamp to the Web Mercator validity band; beyond it the projection diverges.
	lat = clampLat(lat)
	x = lon * MercatorMax / 180
	y = math.Log(math.Tan((90+lat)*math.Pi/360)) * MercatorMax / math.Pi
	return x, y
}

// minMetresPerDegreeLat is the shortest one-degree meridian arc on the WGS84
// ellipsoid, at the equator. Using the minimum makes the latitude offset below
// an over-estimate everywhere else, which keeps the box on the safe side.
const minMetresPerDegreeLat = 110574.0

// SquareAround returns a square EPSG:3857 box centred on (lon, lat) that covers
// at least radiusMetres of true ground distance in every direction.
//
// Web Mercator inflates distances by 1/cos(latitude), and that factor is only
// exact at the latitude it is evaluated at. Scaling the radius by the centre's
// own cosine therefore under-covers towards the pole, where the projection
// stretches harder: at 52°N a 250 km request comes up roughly 6 km short to the
// north. The box is instead sized against the worst case over the whole
// latitude band it spans, so every edge is at least radiusMetres away.
func SquareAround(lon, lat, radiusMetres float64) BBox {
	lat = clampLat(lat)
	cx, cy := LonLatToMercator(lon, lat)

	// North-south: convert the radius to a latitude offset and project the
	// resulting edges, rather than assuming a constant scale.
	dLat := radiusMetres / minMetresPerDegreeLat
	_, northY := LonLatToMercator(lon, clampLat(lat+dLat))
	_, southY := LonLatToMercator(lon, clampLat(lat-dLat))
	halfHeight := math.Max(northY-cy, cy-southY)

	// East-west: the band's cosine is smallest at whichever edge lies further
	// from the equator, and that is where a projected metre buys the least
	// ground distance.
	//
	// Squaring the box can push its edges past lat±dLat, which lowers that
	// worst-case cosine and so demands a wider box again. The dependency is
	// circular, so settle it by iterating to a fixed point. Convergence is quick
	// at mid latitudes and slower near the poles, where the cosine term steepens.
	r := halfHeight
	for range 64 {
		worstLat := math.Max(math.Abs(mercatorYToLat(cy+r)), math.Abs(mercatorYToLat(cy-r)))
		next := math.Max(halfHeight, radiusMetres/math.Cos(worstLat*math.Pi/180))
		if next <= r*(1+1e-15) {
			break
		}
		r = next
	}
	// The iteration approaches its fixed point from below, so it lands a hair
	// short of the requested radius. Nudge it out by a relative epsilon -- well
	// under a millimetre at any realistic radius -- so "at least radiusMetres"
	// holds strictly rather than to within rounding.
	r *= 1 + 1e-7
	b := BBox{MinX: cx - r, MinY: cy - r, MaxX: cx + r, MaxY: cy + r}
	// Keep the box inside the projected world so upstream never sees an
	// out-of-range request; clamping the centre would be worse than shrinking.
	b.MinX = math.Max(b.MinX, -MercatorMax)
	b.MinY = math.Max(b.MinY, -MercatorMax)
	b.MaxX = math.Min(b.MaxX, MercatorMax)
	b.MaxY = math.Min(b.MaxY, MercatorMax)
	return b
}

// clampLat limits a latitude to the Web Mercator validity band.
func clampLat(lat float64) float64 {
	return math.Min(math.Max(lat, -85.05112878), 85.05112878)
}

// mercatorYToLat inverts the northing component of LonLatToMercator.
func mercatorYToLat(y float64) float64 {
	return (2*math.Atan(math.Exp(y/MercatorMax*math.Pi)) - math.Pi/2) * 180 / math.Pi
}
