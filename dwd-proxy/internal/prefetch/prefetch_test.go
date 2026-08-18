package prefetch

import (
	"bytes"
	"image"
	"image/color"
	"image/png"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"net/url"
	"sync"
	"testing"
	"time"

	"github.com/charludo/dwd-proxy/internal/geo"
	"github.com/charludo/dwd-proxy/internal/store"
	"github.com/charludo/dwd-proxy/internal/wms"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func testPNG(t *testing.T) []byte {
	t.Helper()
	var buf bytes.Buffer
	require.NoError(t, png.Encode(&buf, image.NewRGBA(image.Rect(0, 0, 2, 2))))
	return buf.Bytes()
}

// fakeUpstream serves capabilities and PNG frames, recording which TIMEs were requested.
type fakeUpstream struct {
	mu        sync.Mutex
	reqTimes  []string
	refTime   time.Time
	start     time.Time
	end       time.Time
	frameBody []byte
}

func (f *fakeUpstream) handler() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		q := r.URL.Query()
		if q.Get("REQUEST") == "GetCapabilities" {
			f.mu.Lock()
			doc := `<WMS_Capabilities><Capability><Layer><Layer><Name>Radar_wn-product_1x1km_ger</Name>` +
				`<Dimension name="time" units="ISO8601">` +
				wms.FormatTime(f.start) + `/` + wms.FormatTime(f.end) + `/PT5M</Dimension>` +
				`<Dimension name="REFERENCE_TIME" default="` + wms.FormatTime(f.refTime) + `"/>` +
				`</Layer></Layer></Capability></WMS_Capabilities>`
			f.mu.Unlock()
			w.Header().Set("Content-Type", "text/xml")
			_, _ = w.Write([]byte(doc))
			return
		}
		f.mu.Lock()
		f.reqTimes = append(f.reqTimes, q.Get("TIME"))
		body := f.frameBody
		f.mu.Unlock()
		w.Header().Set("Content-Type", "image/png")
		_, _ = w.Write(body)
	}
}

func (f *fakeUpstream) times() []string {
	f.mu.Lock()
	defer f.mu.Unlock()
	return append([]string(nil), f.reqTimes...)
}

func (f *fakeUpstream) reset() {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.reqTimes = nil
}

func newFixture(t *testing.T) (*Prefetcher, *store.Store, *fakeUpstream) {
	t.Helper()
	now := time.Now().UTC()
	fake := &fakeUpstream{
		refTime:   now.Truncate(5 * time.Minute),
		start:     now.Add(-24 * time.Hour),
		end:       now.Add(2 * time.Hour),
		frameBody: testPNG(t),
	}
	srv := httptest.NewServer(fake.handler())
	t.Cleanup(srv.Close)

	s, err := store.New(t.TempDir(), 2)
	require.NoError(t, err)

	p := New(Config{
		BBox:     geo.BBox{MinX: 0, MinY: 0, MaxX: 100, MaxY: 100},
		Size:     256,
		Past:     15 * time.Minute,
		Forecast: 15 * time.Minute,
		Interval: time.Hour,
	}, wms.NewClient(srv.URL, wms.DefaultLayer, srv.Client()), s, slog.New(slog.DiscardHandler))
	return p, s, fake
}

func TestReconcileFillsWindow(t *testing.T) {
	p, s, fake := newFixture(t)
	p.reconcile(t.Context())

	// A 15-minute window either side of now on a 5-minute grid is 7 frames.
	assert.Equal(t, 7, s.Len())
	assert.Len(t, fake.times(), 7)
	assert.True(t, p.Warm())
}

// TestNoRefetchWithoutANewRun keeps the proxy quiet between runs: an unconfirmed
// frame can only be confirmed by comparing across runs, so re-examining it
// before the next run lands would be wasted upstream traffic.
func TestNoRefetchWithoutANewRun(t *testing.T) {
	p, _, fake := newFixture(t)
	p.reconcile(t.Context())
	fake.reset()

	p.reconcile(t.Context())
	assert.Empty(t, fake.times(), "no new model run, so nothing should be re-examined")
}

// TestFirstFetchIsNeverImmediatelyFinal is the core regression guard. DWD answers
// with HTTP 200 and a well-formed but blank or partial PNG while it is publishing
// a run, for past valid times as much as future ones. A single observation is
// therefore never enough to promote a frame to a one-year immutable lifetime.
func TestFirstFetchIsNeverImmediatelyFinal(t *testing.T) {
	p, s, _ := newFixture(t)
	p.reconcile(t.Context())

	require.Positive(t, s.Len())
	for _, ts := range s.Times() {
		f, ok := s.Get(ts)
		require.True(t, ok)
		assert.False(t, f.Settled(),
			"frame %s was promoted to immutable on its first fetch", ts)
	}
}

// TestFrameBecomesFinalOnceStableAcrossRuns is the other half: a frame that comes
// back identical after a new run has landed is genuinely done, and is promoted --
// but only once it has aged past confirmDelay.
func TestFrameBecomesFinalOnceStableAcrossRuns(t *testing.T) {
	p, s, fake := newFixture(t)
	p.reconcile(t.Context())

	fake.mu.Lock()
	fake.refTime = fake.refTime.Add(5 * time.Minute)
	fake.mu.Unlock()
	p.reconcile(t.Context())

	now := time.Now().UTC()
	var confirmed, withheld int
	require.Positive(t, s.Len())
	for _, ts := range s.Times() {
		f, ok := s.Get(ts)
		require.True(t, ok)
		switch age := now.Sub(ts); {
		case age >= clearlyOldEnough:
			assert.True(t, f.Settled(),
				"frame %s is %s old and byte-stable, so it should be final", ts, age)
			confirmed++
		case age >= 0 && age <= clearlyTooRecent:
			assert.False(t, f.Settled(),
				"frame %s is only %s old and must not be final", ts, age)
			withheld++
		}
	}
	require.Positive(t, confirmed, "fixture must span frames old enough to confirm")
	require.Positive(t, withheld, "fixture must span frames too young to confirm")

	// Confirmed frames drop out of the refetch set entirely; the rest stay in.
	fake.reset()
	fake.mu.Lock()
	fake.refTime = fake.refTime.Add(5 * time.Minute)
	fake.mu.Unlock()
	p.reconcile(t.Context())
	for _, ts := range fake.times() {
		parsed, err := wms.ParseTime(ts)
		require.NoError(t, err)
		assert.Less(t, now.Sub(parsed), clearlyOldEnough,
			"confirmed frame %s must never be refetched", ts)
	}
}

// TestPublishLagDuplicateIsNotFrozen is the regression guard for the case the
// delay exists for. DWD briefly serves the previous frame's raster under the
// newest timestamp, so two fetches inside that window agree with each other.
// Without the age requirement that agreement would promote a known-wrong frame
// to a one-year immutable lifetime.
func TestPublishLagDuplicateIsNotFrozen(t *testing.T) {
	p, s, fake := newFixture(t)

	// Two reconciles a model run apart, both returning byte-identical payloads --
	// exactly what a stale duplicate looks like from the prefetcher's side.
	p.reconcile(t.Context())
	fake.mu.Lock()
	fake.refTime = fake.refTime.Add(5 * time.Minute)
	fake.mu.Unlock()
	p.reconcile(t.Context())

	now := time.Now().UTC()
	var checked int
	for _, ts := range s.Times() {
		age := now.Sub(ts)
		if age < 0 || age > clearlyTooRecent {
			continue // either a forecast, or old enough that confirming is legitimate
		}
		f, ok := s.Get(ts)
		require.True(t, ok)
		assert.False(t, f.Settled(),
			"frame %s is only %s old and was frozen immutable inside the publish-lag window", ts, age)
		checked++
	}
	assert.Positive(t, checked, "fixture must contain frames inside the lag window")
}

// TestChangedFrameStaysUnconfirmed covers the case the guard exists for: the
// payload differed between runs, so the earlier capture was not final and the
// frame must stay short-lived rather than be promoted.
func TestChangedFrameStaysUnconfirmed(t *testing.T) {
	p, s, fake := newFixture(t)
	p.reconcile(t.Context())

	// Simulate DWD finishing its publish: the same valid times now render with
	// different content than the blank-ish frames captured mid-run.
	var other bytes.Buffer
	img := image.NewRGBA(image.Rect(0, 0, 2, 2))
	img.Set(0, 0, color.RGBA{R: 255, A: 255})
	require.NoError(t, png.Encode(&other, img))

	fake.mu.Lock()
	fake.frameBody = other.Bytes()
	fake.refTime = fake.refTime.Add(5 * time.Minute)
	fake.mu.Unlock()

	p.reconcile(t.Context())

	for _, ts := range s.Times() {
		f, ok := s.Get(ts)
		require.True(t, ok)
		assert.False(t, f.Settled(), "frame %s changed and must not be final", ts)
		assert.Equal(t, other.Bytes(), f.PNG, "frame %s must hold the newer payload", ts)
	}
}

// TestWindowClampedToExtent covers the ServiceException trap: asking for a TIME
// past the advertised extent is an error, so the window must stop at the edge.
func TestWindowClampedToExtent(t *testing.T) {
	p, _, fake := newFixture(t)
	now := time.Now().UTC()

	fake.mu.Lock()
	fake.end = now.Add(5 * time.Minute) // much shorter than the 15-minute forecast window
	fake.mu.Unlock()

	p.reconcile(t.Context())

	limit := now.Add(5 * time.Minute)
	for _, ts := range fake.times() {
		parsed, err := wms.ParseTime(ts)
		require.NoError(t, err)
		assert.False(t, parsed.After(limit), "requested %s beyond advertised extent %s", ts, limit)
	}
}

func TestWindowIsNewestFirst(t *testing.T) {
	p, _, _ := newFixture(t)
	now := time.Date(2026, 8, 18, 5, 22, 0, 0, time.UTC)
	got := p.window(now, wms.LayerInfo{
		Start:    now.Add(-24 * time.Hour),
		End:      now.Add(2 * time.Hour),
		Interval: 5 * time.Minute,
	})
	require.NotEmpty(t, got)
	for i := 1; i < len(got); i++ {
		assert.True(t, got[i].Before(got[i-1]), "window must run newest to oldest")
	}
	// Snapped onto the 5-minute grid the service publishes on.
	for _, ts := range got {
		assert.Zero(t, ts.Unix()%int64((5*time.Minute).Seconds()))
	}
}

// TestReconcileSurvivesCapabilitiesOutage verifies the prefetcher keeps using the
// last known metadata rather than stalling when the capabilities poll fails.
func TestReconcileSurvivesCapabilitiesOutage(t *testing.T) {
	now := time.Now().UTC()
	var failCaps bool
	var mu sync.Mutex
	body := testPNG(t)

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Query().Get("REQUEST") == "GetCapabilities" {
			mu.Lock()
			fail := failCaps
			mu.Unlock()
			if fail {
				http.Error(w, "boom", http.StatusInternalServerError)
				return
			}
			doc := `<WMS_Capabilities><Capability><Layer><Layer><Name>Radar_wn-product_1x1km_ger</Name>` +
				`<Dimension name="time" units="ISO8601">` +
				wms.FormatTime(now.Add(-time.Hour)) + `/` + wms.FormatTime(now.Add(time.Hour)) + `/PT5M</Dimension>` +
				`</Layer></Layer></Capability></WMS_Capabilities>`
			_, _ = w.Write([]byte(doc))
			return
		}
		w.Header().Set("Content-Type", "image/png")
		_, _ = w.Write(body)
	}))
	defer srv.Close()

	s, err := store.New(t.TempDir(), 2)
	require.NoError(t, err)
	p := New(Config{
		BBox: geo.BBox{MinX: 0, MinY: 0, MaxX: 100, MaxY: 100}, Size: 256,
		Past: 10 * time.Minute, Forecast: 0, Interval: time.Hour,
	}, wms.NewClient(srv.URL, wms.DefaultLayer, srv.Client()), s, slog.New(slog.DiscardHandler))

	p.reconcile(t.Context())
	seeded := s.Len()
	require.Positive(t, seeded)

	mu.Lock()
	failCaps = true
	mu.Unlock()

	p.reconcile(t.Context())
	assert.Equal(t, seeded, s.Len(), "frames should survive a capabilities outage")
}

// TestColdStartWithoutCapabilities confirms a first run with no metadata retries
// rather than issuing unbounded frame requests.
func TestColdStartWithoutCapabilities(t *testing.T) {
	var frameHits int
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Query().Get("REQUEST") == "GetCapabilities" {
			http.Error(w, "down", http.StatusBadGateway)
			return
		}
		frameHits++
		w.WriteHeader(http.StatusOK)
	}))
	defer srv.Close()

	s, err := store.New(t.TempDir(), 2)
	require.NoError(t, err)
	p := New(Config{
		BBox: geo.BBox{MinX: 0, MinY: 0, MaxX: 100, MaxY: 100}, Size: 256,
		Past: 10 * time.Minute, Interval: time.Hour,
	}, wms.NewClient(srv.URL, wms.DefaultLayer, srv.Client()), s, slog.New(slog.DiscardHandler))

	p.reconcile(t.Context())
	assert.Equal(t, 0, frameHits)
	assert.False(t, p.Warm())
}

// TestServiceExceptionNotCached is the regression guard for DWD returning an XML
// error document with HTTP 200.
func TestServiceExceptionNotCached(t *testing.T) {
	now := time.Now().UTC()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Query().Get("REQUEST") == "GetCapabilities" {
			doc := `<WMS_Capabilities><Capability><Layer><Layer><Name>Radar_wn-product_1x1km_ger</Name>` +
				`<Dimension name="time" units="ISO8601">` +
				wms.FormatTime(now.Add(-time.Hour)) + `/` + wms.FormatTime(now.Add(time.Hour)) + `/PT5M</Dimension>` +
				`</Layer></Layer></Capability></WMS_Capabilities>`
			_, _ = w.Write([]byte(doc))
			return
		}
		w.Header().Set("Content-Type", "text/xml")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`<ServiceExceptionReport><ServiceException code="InvalidDimensionValue" locator="time">nope</ServiceException></ServiceExceptionReport>`))
	}))
	defer srv.Close()

	s, err := store.New(t.TempDir(), 2)
	require.NoError(t, err)
	p := New(Config{
		BBox: geo.BBox{MinX: 0, MinY: 0, MaxX: 100, MaxY: 100}, Size: 256,
		Past: 10 * time.Minute, Interval: time.Hour,
	}, wms.NewClient(srv.URL, wms.DefaultLayer, srv.Client()), s, slog.New(slog.DiscardHandler))

	p.reconcile(t.Context())
	assert.Equal(t, 0, s.Len(), "error documents must never be stored as frames")
}

// TestRetainDropsFramesLeavingTheWindow covers pruning as the window slides.
func TestRetainDropsFramesLeavingTheWindow(t *testing.T) {
	p, s, _ := newFixture(t)
	stale := time.Now().UTC().Add(-6 * time.Hour).Truncate(5 * time.Minute)
	_, err := s.Put(stale, time.Now().UTC(), testPNG(t), true)
	require.NoError(t, err)
	require.True(t, s.Has(stale))

	p.reconcile(t.Context())
	assert.False(t, s.Has(stale), "frames outside the window must be pruned")
}

func TestMapURLShape(t *testing.T) {
	c := wms.NewClient("https://example.invalid/wms", wms.DefaultLayer, http.DefaultClient)
	raw := c.MapURL(geo.BBox{MinX: 1, MinY: 2, MaxX: 3, MaxY: 4}, 512,
		time.Date(2026, 8, 18, 5, 20, 0, 0, time.UTC))
	u, err := url.Parse(raw)
	require.NoError(t, err)
	q := u.Query()
	assert.Equal(t, "GetMap", q.Get("REQUEST"))
	assert.Equal(t, "1.3.0", q.Get("VERSION"))
	assert.Equal(t, "true", q.Get("TRANSPARENT"))
	assert.Equal(t, "image/png", q.Get("FORMAT"))
	assert.Equal(t, "512", q.Get("HEIGHT"))
}

// Age bands used by the confirmation tests. They are deliberately literal rather
// than derived from confirmDelay: a test that computes its own threshold from
// the constant it is meant to police passes no matter what that constant is.
// The gap between them straddles the 10-minute boundary so neither band lands on
// it as the fixture's frame grid shifts with wall-clock time.
const (
	clearlyOldEnough = 12 * time.Minute
	clearlyTooRecent = 8 * time.Minute
)
