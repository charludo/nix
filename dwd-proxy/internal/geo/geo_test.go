package geo

import (
	"math"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestParseBBox(t *testing.T) {
	b, err := ParseBBox("500000,5800000,1800000,7400000")
	require.NoError(t, err)
	assert.InDelta(t, 500000.0, b.MinX, 1e-9)
	assert.InDelta(t, 7400000.0, b.MaxY, 1e-9)
	assert.InDelta(t, 1300000.0, b.Width(), 1e-9)
	assert.InDelta(t, 1600000.0, b.Height(), 1e-9)

	for _, bad := range []string{"", "1,2,3", "1,2,3,4,5", "a,2,3,4", "5,5,1,1"} {
		_, err := ParseBBox(bad)
		assert.Error(t, err, "expected %q to be rejected", bad)
	}
}

func TestBBoxRoundTrip(t *testing.T) {
	orig := BBox{MinX: -1.5, MinY: 2.25, MaxX: 3.125, MaxY: 4.5}
	got, err := ParseBBox(orig.String())
	require.NoError(t, err)
	assert.Equal(t, orig, got)
}

func TestLonLatToMercator(t *testing.T) {
	x, y := LonLatToMercator(0, 0)
	assert.InDelta(t, 0.0, x, 1e-6)
	assert.InDelta(t, 0.0, y, 1e-6)

	// Berlin. Easting is exact by construction: lon/180 * MercatorMax.
	x, y = LonLatToMercator(13.405, 52.52)
	assert.InDelta(t, 13.405*MercatorMax/180, x, 1e-6)
	assert.InDelta(t, 6894699.8, y, 1.0)

	// The projection is symmetric about the equator.
	_, north := LonLatToMercator(0, 45)
	_, south := LonLatToMercator(0, -45)
	assert.InDelta(t, north, -south, 1e-6)
}

// TestSquareAroundCoversGroundRadius is the property that matters: every edge
// must sit at least the requested ground distance from the centre. Scaling by
// the centre's own cosine silently fails this to the north, because Mercator
// stretches harder the further from the equator you get.
func TestSquareAroundCoversGroundRadius(t *testing.T) {
	// A mean meridian degree. Using a value larger than the constant the
	// implementation assumes keeps this an independent check rather than a
	// restatement of the same arithmetic.
	const metresPerDegreeLat = 111132.0

	for _, c := range []struct {
		name     string
		lon, lat float64
		radiusKm float64
	}{
		{"germany", 13.405, 52.52, 250},
		{"germany small", 9.0, 50.0, 50},
		{"equator", 0, 0, 250},
		{"high latitude", 20, 69, 250},
		{"southern hemisphere", -58, -34, 250},
	} {
		t.Run(c.name, func(t *testing.T) {
			b := SquareAround(c.lon, c.lat, c.radiusKm*1000)
			require.True(t, b.Valid())
			assert.InDelta(t, b.Width(), b.Height(), 1e-6, "must be square in projected metres")

			north := mercatorYToLat(b.MaxY)
			south := mercatorYToLat(b.MinY)
			assert.GreaterOrEqual(t, (north-c.lat)*metresPerDegreeLat, c.radiusKm*1000,
				"north edge must cover the ground radius")
			assert.GreaterOrEqual(t, (c.lat-south)*metresPerDegreeLat, c.radiusKm*1000,
				"south edge must cover the ground radius")

			// East-west coverage is worst at whichever edge is furthest from the
			// equator, since a degree of longitude shrinks with cos(latitude).
			worst := math.Max(math.Abs(north), math.Abs(south))
			halfLon := (b.Width() / 2) / (MercatorMax / 180)
			eastWest := halfLon * (MercatorMax / 180) * math.Cos(worst*math.Pi/180)
			assert.GreaterOrEqual(t, eastWest, c.radiusKm*1000,
				"east-west coverage must hold across the whole band")

			// Generous, but it should not balloon into a wildly oversized fetch.
			assert.Less(t, b.Width()/2, c.radiusKm*1000*4)
		})
	}
}

func TestSquareAroundStaysInsideTheWorld(t *testing.T) {
	b := SquareAround(179.9, 84, 500*1000)
	assert.GreaterOrEqual(t, b.MinX, -MercatorMax)
	assert.LessOrEqual(t, b.MaxX, MercatorMax)
	assert.LessOrEqual(t, b.MaxY, MercatorMax)
}

func TestContains(t *testing.T) {
	outer := BBox{MinX: 0, MinY: 0, MaxX: 100, MaxY: 100}
	assert.True(t, outer.Contains(BBox{MinX: 10, MinY: 10, MaxX: 20, MaxY: 20}))
	assert.True(t, outer.Contains(outer), "a box contains itself")
	assert.False(t, outer.Contains(BBox{MinX: -1, MinY: 10, MaxX: 20, MaxY: 20}))
	assert.False(t, outer.Contains(BBox{MinX: 10, MinY: 10, MaxX: 101, MaxY: 20}))

	// Leaflet prints float bounds, so an edge-coincident tile can land a
	// fraction outside; the tolerance must absorb that.
	assert.True(t, outer.Contains(BBox{MinX: -1e-9, MinY: 0, MaxX: 100 + 1e-9, MaxY: 100}))
}
