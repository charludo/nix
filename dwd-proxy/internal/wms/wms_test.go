package wms

import (
	"context"
	"net/http"
	"net/http/httptest"
	"net/url"
	"testing"
	"time"

	"github.com/charludo/dwd-proxy/internal/geo"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestParseGetMap(t *testing.T) {
	// Mixed-case keys: WMS parameter names are case-insensitive and Leaflet
	// spells them differently from the capabilities document.
	q := url.Values{
		"SERVICE": {"WMS"},
		"request": {"GetMap"},
		"Layers":  {"dwd:Radar_wn-product_1x1km_ger"},
		"BBOX":    {"500000,5800000,1800000,7400000"},
		"width":   {"512"},
		"HEIGHT":  {"512"},
		"time":    {"2026-08-18T05:20:00Z"},
	}
	g, err := ParseGetMap(q)
	require.NoError(t, err)
	assert.Equal(t, "dwd:Radar_wn-product_1x1km_ger", g.Layer)
	assert.Equal(t, 512, g.Width)
	assert.True(t, g.HasTime)
	assert.Equal(t, time.Date(2026, 8, 18, 5, 20, 0, 0, time.UTC), g.Time)
}

func TestParseGetMapCurrentTime(t *testing.T) {
	// "current" and an absent TIME both mean "whatever is latest", which cannot
	// be pinned to a stored frame.
	for _, ts := range []string{"", "current", "CURRENT"} {
		q := url.Values{
			"request": {"GetMap"}, "bbox": {"0,0,10,10"},
			"width": {"1"}, "height": {"1"}, "time": {ts},
		}
		g, err := ParseGetMap(q)
		require.NoError(t, err)
		assert.False(t, g.HasTime, "time %q should not pin a frame", ts)
	}
}

func TestParseGetMapRejects(t *testing.T) {
	base := func() url.Values {
		return url.Values{
			"request": {"GetMap"}, "bbox": {"0,0,10,10"},
			"width": {"256"}, "height": {"256"},
		}
	}
	t.Run("not a GetMap", func(t *testing.T) {
		q := base()
		q.Set("request", "GetCapabilities")
		_, err := ParseGetMap(q)
		assert.Error(t, err)
	})
	t.Run("bad width", func(t *testing.T) {
		q := base()
		q.Set("width", "wide")
		_, err := ParseGetMap(q)
		assert.Error(t, err)
	})
	t.Run("bad time", func(t *testing.T) {
		q := base()
		q.Set("time", "yesterday")
		_, err := ParseGetMap(q)
		assert.Error(t, err)
	})
}

func TestCRS(t *testing.T) {
	assert.Equal(t, "EPSG:3857", CRS(url.Values{"crs": {"epsg:3857"}}))
	assert.Equal(t, "EPSG:3857", CRS(url.Values{"SRS": {"EPSG:3857"}}))
	assert.Empty(t, CRS(url.Values{}))
}

func TestParseISODuration(t *testing.T) {
	for _, c := range []struct {
		in   string
		want time.Duration
	}{
		{"PT5M", 5 * time.Minute},
		{"PT1H", time.Hour},
		{"PT1H30M", 90 * time.Minute},
		{"P1D", 24 * time.Hour},
		{"P1DT12H", 36 * time.Hour},
		{"PT30S", 30 * time.Second},
	} {
		got, err := parseISODuration(c.in)
		require.NoError(t, err, c.in)
		assert.Equal(t, c.want, got, c.in)
	}
	for _, bad := range []string{"", "5M", "PT", "PTM", "PT5X"} {
		_, err := parseISODuration(bad)
		assert.Error(t, err, "expected %q to be rejected", bad)
	}
}

const capsDoc = `<?xml version="1.0"?>
<WMS_Capabilities version="1.3.0">
 <Capability>
  <Layer>
   <Title>root</Title>
   <Layer>
    <Name>Other_layer</Name>
    <Dimension name="time" default="current" units="ISO8601">2026-01-01T00:00:00.000Z/2026-01-02T00:00:00.000Z/PT10M</Dimension>
   </Layer>
   <Layer>
    <Name>Radar_wn-product_1x1km_ger</Name>
    <Dimension name="time" default="current" units="ISO8601">2026-08-14T00:00:00.000Z/2026-08-18T07:20:00.000Z/PT5M</Dimension>
    <Dimension name="REFERENCE_TIME" default="2026-08-18T05:20:00.000Z" units="ISO8601">2026-08-18T05:15:00.000Z,2026-08-18T05:20:00.000Z</Dimension>
    <Style><Name>should-not-match</Name></Style>
   </Layer>
  </Layer>
 </Capability>
</WMS_Capabilities>`

func TestParseCapabilities(t *testing.T) {
	// The workspace prefix appears in GetMap but not in capabilities.
	info, err := parseCapabilities([]byte(capsDoc), "dwd:Radar_wn-product_1x1km_ger")
	require.NoError(t, err)
	assert.Equal(t, time.Date(2026, 8, 14, 0, 0, 0, 0, time.UTC), info.Start)
	assert.Equal(t, time.Date(2026, 8, 18, 7, 20, 0, 0, time.UTC), info.End)
	assert.Equal(t, 5*time.Minute, info.Interval)
	assert.Equal(t, time.Date(2026, 8, 18, 5, 20, 0, 0, time.UTC), info.ReferenceTime)

	_, err = parseCapabilities([]byte(capsDoc), "dwd:Nonexistent")
	assert.Error(t, err)
}

func TestParseCapabilitiesEnumeratedExtent(t *testing.T) {
	doc := `<WMS_Capabilities><Capability><Layer><Layer><Name>L</Name>
	<Dimension name="time" units="ISO8601">2026-08-15T05:24:30.000Z,2026-08-15T05:25:30.000Z,2026-08-15T05:26:30.000Z</Dimension>
	</Layer></Layer></Capability></WMS_Capabilities>`
	info, err := parseCapabilities([]byte(doc), "L")
	require.NoError(t, err)
	assert.Equal(t, time.Date(2026, 8, 15, 5, 24, 30, 0, time.UTC), info.Start)
	assert.Equal(t, time.Date(2026, 8, 15, 5, 26, 30, 0, time.UTC), info.End)
}

// TestFetchMapServiceException is the trap this proxy exists to avoid: DWD
// reports an out-of-range TIME as an XML document served with HTTP 200. Caching
// that as if it were a frame would replay an error forever.
func TestFetchMapServiceException(t *testing.T) {
	const exc = `<?xml version="1.0" encoding="UTF-8"?><ServiceExceptionReport version="1.3.0" xmlns="http://www.opengis.net/ogc">
	<ServiceException code="InvalidDimensionValue" locator="time">Could not find a match for 'time' value: '2026-08-18T12:00:00Z'</ServiceException></ServiceExceptionReport>`

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "text/xml;charset=UTF-8")
		w.WriteHeader(http.StatusOK) // note: success status, error body
		_, _ = w.Write([]byte(exc))
	}))
	defer srv.Close()

	c := NewClient(srv.URL, DefaultLayer, srv.Client())
	_, err := c.FetchMap(t.Context(), geo.BBox{MinX: 0, MinY: 0, MaxX: 1, MaxY: 1}, 256, time.Now())
	require.Error(t, err)

	var svcErr *ServiceError
	require.ErrorAs(t, err, &svcErr)
	assert.Equal(t, "InvalidDimensionValue", svcErr.Code)
	assert.Equal(t, "time", svcErr.Locator)
}

func TestFetchMapRejectsNonPNG(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "text/html")
		_, _ = w.Write([]byte("<html>a portal login page</html>"))
	}))
	defer srv.Close()

	c := NewClient(srv.URL, DefaultLayer, srv.Client())
	_, err := c.FetchMap(t.Context(), geo.BBox{MinX: 0, MinY: 0, MaxX: 1, MaxY: 1}, 256, time.Now())
	assert.ErrorContains(t, err, "not a PNG")
}

func TestFetchMapSuccess(t *testing.T) {
	png := append([]byte{0x89, 'P', 'N', 'G', '\r', '\n', 0x1a, '\n'}, []byte("payload")...)
	var gotQuery url.Values
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotQuery = r.URL.Query()
		w.Header().Set("Content-Type", "image/png")
		_, _ = w.Write(png)
	}))
	defer srv.Close()

	c := NewClient(srv.URL, DefaultLayer, srv.Client())
	when := time.Date(2026, 8, 18, 5, 20, 0, 0, time.UTC)
	got, err := c.FetchMap(t.Context(), geo.BBox{MinX: 0, MinY: 1, MaxX: 2, MaxY: 3}, 1024, when)
	require.NoError(t, err)
	assert.Equal(t, png, got)

	assert.Equal(t, "2026-08-18T05:20:00Z", gotQuery.Get("TIME"))
	assert.Equal(t, "EPSG:3857", gotQuery.Get("CRS"))
	assert.Equal(t, "1024", gotQuery.Get("WIDTH"))
	assert.Equal(t, "0,1,2,3", gotQuery.Get("BBOX"))
}

func TestFetchMapUpstreamStatus(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		http.Error(w, "slow down", http.StatusTooManyRequests)
	}))
	defer srv.Close()

	c := NewClient(srv.URL, DefaultLayer, srv.Client())
	_, err := c.FetchMap(context.Background(), geo.BBox{MinX: 0, MinY: 0, MaxX: 1, MaxY: 1}, 256, time.Now())
	assert.ErrorContains(t, err, "429")
}
