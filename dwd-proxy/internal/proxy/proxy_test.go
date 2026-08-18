package proxy

import (
	"bytes"
	"image"
	"image/color"
	"image/png"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/charludo/dwd-proxy/internal/geo"
	"github.com/charludo/dwd-proxy/internal/store"
	"github.com/charludo/dwd-proxy/internal/wms"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

var masterBox = geo.BBox{MinX: 0, MinY: 0, MaxX: 400, MaxY: 400}

type alwaysWarm struct{}

func (alwaysWarm) Warm() bool { return true }

func masterPNG(t *testing.T) []byte {
	t.Helper()
	img := image.NewRGBA(image.Rect(0, 0, 4, 4))
	for y := range 4 {
		for x := range 4 {
			img.Set(x, y, color.RGBA{R: uint8(x * 40), G: uint8(y * 40), B: 200, A: 255})
		}
	}
	var buf bytes.Buffer
	require.NoError(t, png.Encode(&buf, img))
	return buf.Bytes()
}

// newTestServer wires a Server against a stub upstream, returning the server, the
// frame store, and a counter of requests that reached the upstream.
func newTestServer(t *testing.T) (*Server, *store.Store, *int) {
	t.Helper()
	var upstreamHits int
	up := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		upstreamHits++
		w.Header().Set("Content-Type", "image/png")
		_, _ = w.Write([]byte("upstream-body"))
	}))
	t.Cleanup(up.Close)

	s, err := store.New(t.TempDir(), 4)
	require.NoError(t, err)

	srv, err := New(Config{
		BBox:           masterBox,
		Size:           4,
		Layer:          wms.DefaultLayer,
		ForecastMaxAge: 5 * time.Minute,
	}, s, up.URL, alwaysWarm{}, slog.New(slog.DiscardHandler), nil)
	require.NoError(t, err)
	return srv, s, &upstreamHits
}

func tileRequest(bbox string, when time.Time) *http.Request {
	q := url.Values{
		"SERVICE": {"WMS"}, "VERSION": {"1.3.0"}, "REQUEST": {"GetMap"},
		"LAYERS": {wms.DefaultLayer}, "FORMAT": {"image/png"},
		"CRS": {"EPSG:3857"}, "BBOX": {bbox},
		"WIDTH": {"256"}, "HEIGHT": {"256"},
		"TIME": {wms.FormatTime(when)},
	}
	return httptest.NewRequest(http.MethodGet, "/geoserver/dwd/wms?"+q.Encode(), nil)
}

// TestServeSettledFrame is the core behaviour: a past frame is derived locally,
// never touches upstream, and is marked immutable so clients stop re-asking.
func TestServeSettledFrame(t *testing.T) {
	srv, s, hits := newTestServer(t)
	valid := time.Now().UTC().Add(-time.Hour).Truncate(5 * time.Minute)
	_, err := s.Put(valid, time.Now().UTC(), masterPNG(t), true)
	require.NoError(t, err)

	rec := httptest.NewRecorder()
	srv.ServeHTTP(rec, tileRequest("0,0,200,200", valid))

	require.Equal(t, http.StatusOK, rec.Code)
	assert.Equal(t, 0, *hits, "a cached frame must not reach upstream")
	assert.Equal(t, "image/png", rec.Header().Get("Content-Type"))
	assert.Contains(t, rec.Header().Get("Cache-Control"), "immutable")
	assert.Contains(t, rec.Header().Get("Cache-Control"), "max-age=31536000")
	assert.Equal(t, "*", rec.Header().Get("Access-Control-Allow-Origin"))
	assert.NotEmpty(t, rec.Header().Get("ETag"))

	img, err := png.Decode(bytes.NewReader(rec.Body.Bytes()))
	require.NoError(t, err)
	assert.Equal(t, 256, img.Bounds().Dx())
}

// TestNoVaryHeader guards CDN cacheability. The CORS header is a constant, so
// the response does not vary by origin; advertising that it does would make
// caches that only understand "Vary: Accept-Encoding" refuse to store it at all.
func TestNoVaryHeader(t *testing.T) {
	srv, s, _ := newTestServer(t)
	valid := time.Now().UTC().Add(-time.Hour).Truncate(5 * time.Minute)
	_, err := s.Put(valid, time.Now().UTC(), masterPNG(t), true)
	require.NoError(t, err)

	rec := httptest.NewRecorder()
	srv.ServeHTTP(rec, tileRequest("0,0,200,200", valid))

	require.Equal(t, http.StatusOK, rec.Code)
	assert.Empty(t, rec.Header().Values("Vary"), "a Vary header makes this uncacheable at the edge")
	assert.Equal(t, "*", rec.Header().Get("Access-Control-Allow-Origin"))
}

// TestServeForecastFrame checks the other half of the freshness split: a nowcast
// frame gets a short lifetime, because the same TIME will be re-rendered later.
func TestServeForecastFrame(t *testing.T) {
	srv, s, _ := newTestServer(t)
	valid := time.Now().UTC().Add(time.Hour).Truncate(5 * time.Minute)
	_, err := s.Put(valid, time.Now().UTC(), masterPNG(t), false)
	require.NoError(t, err)

	rec := httptest.NewRecorder()
	srv.ServeHTTP(rec, tileRequest("0,0,200,200", valid))

	require.Equal(t, http.StatusOK, rec.Code)
	cc := rec.Header().Get("Cache-Control")
	assert.Contains(t, cc, "max-age="+strconv.Itoa(int((5*time.Minute).Seconds())))
	assert.NotContains(t, cc, "immutable")
}

func TestConditionalRequest(t *testing.T) {
	srv, s, _ := newTestServer(t)
	valid := time.Now().UTC().Add(-time.Hour).Truncate(5 * time.Minute)
	_, err := s.Put(valid, time.Now().UTC(), masterPNG(t), true)
	require.NoError(t, err)

	first := httptest.NewRecorder()
	srv.ServeHTTP(first, tileRequest("0,0,200,200", valid))
	tag := first.Header().Get("ETag")
	require.NotEmpty(t, tag)

	for _, header := range []string{tag, "W/" + tag, "*", `"other", ` + tag} {
		req := tileRequest("0,0,200,200", valid)
		req.Header.Set("If-None-Match", header)
		rec := httptest.NewRecorder()
		srv.ServeHTTP(rec, req)
		assert.Equal(t, http.StatusNotModified, rec.Code, "If-None-Match: %s", header)
		assert.Empty(t, rec.Body.Bytes())
	}

	req := tileRequest("0,0,200,200", valid)
	req.Header.Set("If-None-Match", `"stale"`)
	rec := httptest.NewRecorder()
	srv.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusOK, rec.Code)
}

// TestDistinctCropsGetDistinctETags guards against keying the tag on the master
// frame, which would make every crop of one frame collide.
func TestDistinctCropsGetDistinctETags(t *testing.T) {
	srv, s, _ := newTestServer(t)
	valid := time.Now().UTC().Add(-time.Hour).Truncate(5 * time.Minute)
	_, err := s.Put(valid, time.Now().UTC(), masterPNG(t), true)
	require.NoError(t, err)

	tags := map[string]bool{}
	for _, bbox := range []string{"0,0,200,200", "200,200,400,400", "0,200,200,400"} {
		rec := httptest.NewRecorder()
		srv.ServeHTTP(rec, tileRequest(bbox, valid))
		require.Equal(t, http.StatusOK, rec.Code)
		tags[rec.Header().Get("ETag")] = true
	}
	assert.Len(t, tags, 3, "each crop must have its own entity tag")
}

func TestFallbackToUpstream(t *testing.T) {
	valid := time.Now().UTC().Add(-time.Hour).Truncate(5 * time.Minute)

	for _, c := range []struct {
		name    string
		mutate  func(*url.Values)
		seeded  bool
		expects string
	}{
		{name: "unknown time", seeded: false, mutate: func(*url.Values) {}},
		{
			name: "panned outside the cached area", seeded: true,
			mutate: func(q *url.Values) { q.Set("BBOX", "900,900,1000,1000") },
		},
		{
			name: "different layer", seeded: true,
			mutate: func(q *url.Values) { q.Set("LAYERS", "dwd:Some_other_layer") },
		},
		{
			name: "unsupported projection", seeded: true,
			mutate: func(q *url.Values) { q.Set("CRS", "EPSG:4326") },
		},
		{
			name: "time=current cannot be pinned", seeded: true,
			mutate: func(q *url.Values) { q.Set("TIME", "current") },
		},
		{
			name: "not a GetMap", seeded: true,
			mutate: func(q *url.Values) { q.Set("REQUEST", "GetCapabilities") },
		},
	} {
		t.Run(c.name, func(t *testing.T) {
			srv, s, hits := newTestServer(t)
			if c.seeded {
				_, err := s.Put(valid, time.Now().UTC(), masterPNG(t), true)
				require.NoError(t, err)
			}
			q := url.Values{
				"SERVICE": {"WMS"}, "REQUEST": {"GetMap"},
				"LAYERS": {wms.DefaultLayer}, "CRS": {"EPSG:3857"},
				"BBOX": {"0,0,200,200"}, "WIDTH": {"256"}, "HEIGHT": {"256"},
				"TIME": {wms.FormatTime(valid)},
			}
			c.mutate(&q)

			rec := httptest.NewRecorder()
			srv.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/geoserver/dwd/wms?"+q.Encode(), nil))

			assert.Equal(t, 1, *hits, "request should have been relayed upstream")
			assert.Equal(t, "upstream-body", rec.Body.String())
		})
	}
}

// TestLayerWorkspacePrefixOptional covers the card and capabilities spelling the
// same layer differently.
func TestLayerWorkspacePrefixOptional(t *testing.T) {
	srv, s, hits := newTestServer(t)
	valid := time.Now().UTC().Add(-time.Hour).Truncate(5 * time.Minute)
	_, err := s.Put(valid, time.Now().UTC(), masterPNG(t), true)
	require.NoError(t, err)

	q := url.Values{
		"REQUEST": {"GetMap"}, "LAYERS": {"Radar_wn-product_1x1km_ger"},
		"CRS": {"EPSG:3857"}, "BBOX": {"0,0,200,200"},
		"WIDTH": {"256"}, "HEIGHT": {"256"}, "TIME": {wms.FormatTime(valid)},
	}
	rec := httptest.NewRecorder()
	srv.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/x?"+q.Encode(), nil))

	assert.Equal(t, http.StatusOK, rec.Code)
	assert.Equal(t, 0, *hits)
}

func TestHeadRequestOmitsBody(t *testing.T) {
	srv, s, _ := newTestServer(t)
	valid := time.Now().UTC().Add(-time.Hour).Truncate(5 * time.Minute)
	_, err := s.Put(valid, time.Now().UTC(), masterPNG(t), true)
	require.NoError(t, err)

	req := tileRequest("0,0,200,200", valid)
	req.Method = http.MethodHead
	rec := httptest.NewRecorder()
	srv.ServeHTTP(rec, req)

	assert.Equal(t, http.StatusOK, rec.Code)
	assert.Empty(t, rec.Body.Bytes())
	assert.NotEmpty(t, rec.Header().Get("Content-Length"))
}

func TestHealthAndReadiness(t *testing.T) {
	srv, _, _ := newTestServer(t)
	for _, path := range []string{"/healthz", "/readyz"} {
		rec := httptest.NewRecorder()
		srv.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, path, nil))
		assert.Equal(t, http.StatusOK, rec.Code, path)
	}
}

type coldWarmer struct{}

func (coldWarmer) Warm() bool { return false }

func TestReadinessWhileWarming(t *testing.T) {
	s, err := store.New(t.TempDir(), 2)
	require.NoError(t, err)
	srv, err := New(Config{BBox: masterBox, Size: 4, Layer: wms.DefaultLayer},
		s, "http://127.0.0.1:1", coldWarmer{}, slog.New(slog.DiscardHandler), nil)
	require.NoError(t, err)

	rec := httptest.NewRecorder()
	srv.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/readyz", nil))
	assert.Equal(t, http.StatusServiceUnavailable, rec.Code)
}

func TestMetricsExposed(t *testing.T) {
	srv, s, _ := newTestServer(t)
	valid := time.Now().UTC().Add(-time.Hour).Truncate(5 * time.Minute)
	_, err := s.Put(valid, time.Now().UTC(), masterPNG(t), true)
	require.NoError(t, err)
	srv.ServeHTTP(httptest.NewRecorder(), tileRequest("0,0,200,200", valid))

	rec := httptest.NewRecorder()
	srv.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/metrics", nil))
	require.Equal(t, http.StatusOK, rec.Code)

	body, err := io.ReadAll(rec.Body)
	require.NoError(t, err)
	assert.Contains(t, string(body), `dwd_proxy_requests_total{result="hit-settled"} 1`)
}

func TestETagMatches(t *testing.T) {
	assert.True(t, etagMatches(`"a"`, `"a"`))
	assert.True(t, etagMatches(`W/"a"`, `"a"`))
	assert.True(t, etagMatches("*", `"a"`))
	assert.True(t, etagMatches(`"b", "a"`, `"a"`))
	assert.False(t, etagMatches(`"b"`, `"a"`))
	assert.False(t, etagMatches("", `"a"`))
}

func TestStripWorkspace(t *testing.T) {
	assert.Equal(t, "L", stripWorkspace("dwd:L"))
	assert.Equal(t, "L", stripWorkspace("L"))
	assert.True(t, layerMatches("dwd:L", "L"))
	assert.False(t, layerMatches("dwd:L", "M"))
}

func TestLookupIsCaseInsensitive(t *testing.T) {
	q := url.Values{"ReQuEsT": {"GetMap"}}
	assert.Equal(t, "GetMap", lookup(q, "request"))
	assert.Empty(t, lookup(q, "missing"))
}

// TestUpstreamPathPreserved confirms the fallback relays the client's path, so a
// host-only redirect of the card reaches the same endpoint upstream.
func TestUpstreamPathPreserved(t *testing.T) {
	var gotPath, gotQuery string
	up := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotPath, gotQuery = r.URL.Path, r.URL.RawQuery
		_, _ = w.Write([]byte("ok"))
	}))
	defer up.Close()

	s, err := store.New(t.TempDir(), 2)
	require.NoError(t, err)
	srv, err := New(Config{BBox: masterBox, Size: 4, Layer: wms.DefaultLayer},
		s, up.URL, alwaysWarm{}, slog.New(slog.DiscardHandler), nil)
	require.NoError(t, err)

	rec := httptest.NewRecorder()
	srv.ServeHTTP(rec, httptest.NewRequest(http.MethodGet,
		"/geoserver/dwd/wms?REQUEST=GetCapabilities&SERVICE=WMS", nil))

	assert.Equal(t, "/geoserver/dwd/wms", gotPath)
	assert.True(t, strings.Contains(gotQuery, "GetCapabilities"), "query was %q", gotQuery)
}
