// Package proxy serves radar tiles from the frame store, falling back to the
// upstream service for anything it cannot answer locally.
package proxy

import (
	"log/slog"
	"net/http"
	"net/http/httputil"
	"net/url"
	"strconv"
	"strings"
	"time"

	"github.com/charludo/dwd-proxy/internal/geo"
	"github.com/charludo/dwd-proxy/internal/render"
	"github.com/charludo/dwd-proxy/internal/store"
	"github.com/charludo/dwd-proxy/internal/wms"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

// immutableMaxAge is the lifetime advertised for settled frames. A year is the
// conventional ceiling for `immutable` responses.
const immutableMaxAge = 365 * 24 * time.Hour

// Config parameterises the server.
type Config struct {
	// BBox and Size describe the cached master rasters.
	BBox geo.BBox
	Size int
	// Layer is the WMS layer served from cache; other layers are proxied through.
	Layer string
	// ForecastMaxAge is how long clients may reuse an unsettled (nowcast) frame.
	ForecastMaxAge time.Duration
}

type metrics struct {
	// requests counts tile requests by how they were served.
	requests *prometheus.CounterVec
	// renderSeconds observes the cost of deriving a tile from a master raster.
	renderSeconds prometheus.Histogram
}

// requestResults enumerates every value of the `result` label, so all series
// exist from startup instead of appearing only once first exercised.
var requestResults = []string{
	"hit-settled", "hit-forecast", "not-modified",
	"miss-time", "miss-bbox", "miss-layer", "error", "proxied",
}

func newMetrics(reg prometheus.Registerer) *metrics {
	m := &metrics{
		requests: promauto.With(reg).NewCounterVec(prometheus.CounterOpts{
			Namespace: "dwd_proxy",
			Name:      "requests_total",
			Help:      "Tile requests by how they were served.",
		}, []string{"result"}),
		renderSeconds: promauto.With(reg).NewHistogram(prometheus.HistogramOpts{
			Namespace: "dwd_proxy",
			Name:      "render_seconds",
			Help:      "Time spent deriving a tile from a cached master raster.",
			Buckets:   prometheus.DefBuckets,
		}),
	}
	for _, r := range requestResults {
		m.requests.WithLabelValues(r)
	}
	return m
}

// Warmer reports prefetch readiness.
type Warmer interface{ Warm() bool }

// Server answers WMS GetMap requests from cached frames.
type Server struct {
	cfg     Config
	store   *store.Store
	log     *slog.Logger
	warmer  Warmer
	metrics *metrics

	metricsHTTP  http.Handler
	reverseProxy http.Handler
}

// New constructs a Server. If reg is nil a fresh registry is created.
func New(cfg Config, s *store.Store, upstream string, warmer Warmer, log *slog.Logger, reg *prometheus.Registry) (*Server, error) {
	if reg == nil {
		reg = prometheus.NewRegistry()
	}
	u, err := url.Parse(upstream)
	if err != nil {
		return nil, err
	}
	rp := &httputil.ReverseProxy{
		Rewrite: func(r *httputil.ProxyRequest) {
			r.SetURL(&url.URL{Scheme: u.Scheme, Host: u.Host})
			// Preserve the upstream's own path prefix while keeping whatever
			// path the client asked for beneath it.
			r.Out.Host = u.Host
		},
		ErrorHandler: func(w http.ResponseWriter, _ *http.Request, err error) {
			log.Error("upstream proxy failed", "err", err)
			http.Error(w, "upstream unavailable", http.StatusBadGateway)
		},
	}
	return &Server{
		cfg:          cfg,
		store:        s,
		log:          log,
		warmer:       warmer,
		metrics:      newMetrics(reg),
		metricsHTTP:  promhttp.HandlerFor(reg, promhttp.HandlerOpts{}),
		reverseProxy: rp,
	}, nil
}

func (s *Server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	switch r.URL.Path {
	case "/healthz":
		_, _ = w.Write([]byte("ok"))
		return
	case "/readyz":
		if s.warmer != nil && !s.warmer.Warm() {
			http.Error(w, "warming", http.StatusServiceUnavailable)
			return
		}
		_, _ = w.Write([]byte("ok"))
		return
	case "/metrics":
		s.metricsHTTP.ServeHTTP(w, r)
		return
	}

	if r.Method != http.MethodGet && r.Method != http.MethodHead {
		s.passThrough(w, r, "proxied")
		return
	}
	q := r.URL.Query()
	if !strings.EqualFold(lookup(q, "request"), "GetMap") {
		// GetCapabilities, GetLegendGraphic, wind overlays and anything else we
		// do not model are relayed untouched.
		s.passThrough(w, r, "proxied")
		return
	}
	s.serveMap(w, r, q)
}

func (s *Server) serveMap(w http.ResponseWriter, r *http.Request, q url.Values) {
	g, err := wms.ParseGetMap(q)
	if err != nil {
		s.log.Debug("unparseable GetMap, relaying upstream", "err", err)
		s.passThrough(w, r, "proxied")
		return
	}
	if !layerMatches(g.Layer, s.cfg.Layer) {
		s.passThrough(w, r, "miss-layer")
		return
	}
	if crs := wms.CRS(q); crs != "" && crs != "EPSG:3857" {
		// The master raster is projected; we cannot re-project it here.
		s.passThrough(w, r, "miss-layer")
		return
	}
	if !g.HasTime {
		// "current" is a moving target we cannot pin to a stored frame.
		s.passThrough(w, r, "miss-time")
		return
	}
	if !s.cfg.BBox.Contains(g.BBox) {
		// The client panned outside the prefetched area.
		s.passThrough(w, r, "miss-bbox")
		return
	}
	frame, ok := s.store.Get(g.Time)
	if !ok {
		s.passThrough(w, r, "miss-time")
		return
	}

	img, err := s.store.Image(frame)
	if err != nil {
		s.metrics.requests.WithLabelValues("error").Inc()
		s.log.Error("decoding cached frame failed", "time", wms.FormatTime(g.Time), "err", err)
		s.passThrough(w, r, "proxied")
		return
	}

	start := time.Now()
	tile, err := render.CropScale(img, s.cfg.BBox, g.BBox, g.Width, g.Height)
	if err != nil {
		s.metrics.requests.WithLabelValues("error").Inc()
		s.log.Error("rendering tile failed", "err", err)
		http.Error(w, "cannot render tile", http.StatusBadRequest)
		return
	}
	body, err := render.EncodePNG(tile)
	if err != nil {
		s.metrics.requests.WithLabelValues("error").Inc()
		s.log.Error("encoding tile failed", "err", err)
		http.Error(w, "cannot encode tile", http.StatusInternalServerError)
		return
	}
	s.metrics.renderSeconds.Observe(time.Since(start).Seconds())

	s.writeTile(w, r, frame, body)
}

func (s *Server) writeTile(w http.ResponseWriter, r *http.Request, frame *store.Frame, body []byte) {
	// The tag covers the derived tile, not the master raster, so two different
	// crops of one frame never collide.
	tag := store.ETagFor(body)
	h := w.Header()
	h.Set("Content-Type", "image/png")
	h.Set("ETag", tag)
	// The card fetches cross-origin from the Home Assistant page. This value is
	// constant rather than a reflection of the request's Origin, so the response
	// genuinely does not vary by origin and must NOT advertise "Vary: Origin":
	// CDNs commonly honour only "Vary: Accept-Encoding" and treat any other Vary
	// value as making the response uncacheable, which would defeat the whole
	// point of putting one in front.
	h.Set("Access-Control-Allow-Origin", "*")

	settled := frame.Settled()
	if settled {
		h.Set("Cache-Control", "public, max-age="+strconv.Itoa(int(immutableMaxAge.Seconds()))+", immutable")
	} else {
		maxAge := int(s.cfg.ForecastMaxAge.Seconds())
		if maxAge < 1 {
			maxAge = 1
		}
		h.Set("Cache-Control", "public, max-age="+strconv.Itoa(maxAge))
	}
	h.Set("Last-Modified", frame.FetchedAt.UTC().Format(http.TimeFormat))

	if match := r.Header.Get("If-None-Match"); match != "" && etagMatches(match, tag) {
		s.metrics.requests.WithLabelValues("not-modified").Inc()
		w.WriteHeader(http.StatusNotModified)
		return
	}
	if settled {
		s.metrics.requests.WithLabelValues("hit-settled").Inc()
	} else {
		s.metrics.requests.WithLabelValues("hit-forecast").Inc()
	}

	h.Set("Content-Length", strconv.Itoa(len(body)))
	w.WriteHeader(http.StatusOK)
	if r.Method == http.MethodHead {
		return
	}
	if _, err := w.Write(body); err != nil {
		s.log.Debug("writing tile failed", "err", err)
	}
}

// etagMatches implements the If-None-Match comparison, which accepts a
// comma-separated list, the wildcard, and weak tags.
func etagMatches(header, tag string) bool {
	for part := range strings.SplitSeq(header, ",") {
		candidate := strings.TrimSpace(part)
		if candidate == "*" {
			return true
		}
		if strings.TrimPrefix(candidate, "W/") == tag {
			return true
		}
	}
	return false
}

func (s *Server) passThrough(w http.ResponseWriter, r *http.Request, result string) {
	s.metrics.requests.WithLabelValues(result).Inc()
	s.reverseProxy.ServeHTTP(w, r)
}

// layerMatches compares layer names ignoring the optional workspace prefix, so
// "Radar_wn-product_1x1km_ger" and "dwd:Radar_wn-product_1x1km_ger" are equal.
func layerMatches(got, want string) bool {
	return strings.EqualFold(stripWorkspace(got), stripWorkspace(want))
}

func stripWorkspace(s string) string {
	if _, after, found := strings.Cut(s, ":"); found {
		return after
	}
	return s
}

// lookup does a case-insensitive query parameter lookup, as WMS requires.
func lookup(q url.Values, key string) string {
	for k, vs := range q {
		if strings.EqualFold(k, key) && len(vs) > 0 {
			return vs[0]
		}
	}
	return ""
}
