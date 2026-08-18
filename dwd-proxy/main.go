// Command dwd-proxy is a caching proxy for the DWD radar WMS service.
//
// It prefetches a wide area around a fixed centre point as one master raster
// per time step, then derives every tile a client asks for by cropping and
// scaling those rasters. Requests it cannot answer locally are relayed to the
// upstream service unchanged.
package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

	"github.com/charludo/dwd-proxy/internal/geo"
	"github.com/charludo/dwd-proxy/internal/prefetch"
	"github.com/charludo/dwd-proxy/internal/proxy"
	"github.com/charludo/dwd-proxy/internal/store"
	"github.com/charludo/dwd-proxy/internal/wms"
	"github.com/prometheus/client_golang/prometheus"
)

var version = "0.0.0-dev"

func main() {
	if err := run(); err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}
}

func run() error {
	var (
		addr     = flag.String("addr", ":8080", "listen address")
		stateDir = flag.String("state-dir", "/var/lib/dwd-proxy", "directory for cached frames")

		lat      = flag.Float64("lat", 0, "latitude of the area centre, in degrees (required)")
		lon      = flag.Float64("lon", 0, "longitude of the area centre, in degrees (required)")
		radiusKm = flag.Float64("radius-km", 250, "ground radius around the centre to prefetch")
		size     = flag.Int("master-size", 2048, "edge length in pixels of each cached master raster")

		past     = flag.Duration("past", 2*time.Hour, "how far back to keep frames")
		forecast = flag.Duration("forecast", 2*time.Hour, "how far ahead to keep forecast frames")

		interval   = flag.Duration("interval", time.Minute, "how often the frame window is reconciled")
		requestGap = flag.Duration("request-gap", 250*time.Millisecond, "pause between upstream frame fetches")

		forecastMaxAge = flag.Duration("forecast-max-age", 5*time.Minute, "how long clients may reuse a forecast frame")

		upstream = flag.String("upstream", wms.DefaultUpstream, "upstream WMS endpoint")
		layer    = flag.String("layer", wms.DefaultLayer, "WMS layer to cache")
		timeout  = flag.Duration("upstream-timeout", 60*time.Second, "per-request upstream timeout")

		decodedCache = flag.Int("decoded-cache", 8, "number of decoded master rasters to keep in memory")

		showVersion = flag.Bool("version", false, "print the version and exit")
	)
	flag.Parse()

	if *showVersion {
		fmt.Println(version)
		return nil
	}
	if err := validate(*lat, *lon, *radiusKm, *size); err != nil {
		return err
	}

	log := slog.New(slog.NewTextHandler(os.Stderr, nil))

	bbox := geo.SquareAround(*lon, *lat, *radiusKm*1000)
	log.Info("dwd-proxy starting",
		"version", version, "addr", *addr,
		"lat", *lat, "lon", *lon, "radiusKm", *radiusKm,
		"masterSize", *size, "layer", *layer,
		// Ground resolution of the cached raster. The source product is a 1 km
		// grid, so anything below that means no detail is lost to the cache.
		"metresPerPixel", fmt.Sprintf("%.0f", (*radiusKm*2000)/float64(*size)),
	)

	frames, err := store.New(filepath.Join(*stateDir, "frames"), *decodedCache)
	if err != nil {
		return fmt.Errorf("opening frame store: %w", err)
	}
	log.Info("frame store opened", "dir", *stateDir, "restored", frames.Len())

	client := wms.NewClient(*upstream, *layer, &http.Client{Timeout: *timeout})

	pf := prefetch.New(prefetch.Config{
		BBox:       bbox,
		Size:       *size,
		Past:       *past,
		Forecast:   *forecast,
		Interval:   *interval,
		RequestGap: *requestGap,
	}, client, frames, log)

	srv, err := proxy.New(proxy.Config{
		BBox:           bbox,
		Size:           *size,
		Layer:          *layer,
		ForecastMaxAge: *forecastMaxAge,
	}, frames, *upstream, pf, log, prometheus.NewRegistry())
	if err != nil {
		return fmt.Errorf("building server: %w", err)
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	go pf.Run(ctx)

	httpSrv := &http.Server{
		Addr:              *addr,
		Handler:           srv,
		ReadHeaderTimeout: 10 * time.Second,
	}
	errCh := make(chan error, 1)
	go func() { errCh <- httpSrv.ListenAndServe() }()

	select {
	case err := <-errCh:
		if !errors.Is(err, http.ErrServerClosed) {
			return err
		}
	case <-ctx.Done():
		log.Info("shutdown signal received")
		shutdownCtx, cancel := context.WithTimeout(context.WithoutCancel(ctx), 10*time.Second)
		defer cancel()
		if err := httpSrv.Shutdown(shutdownCtx); err != nil {
			log.Error("graceful shutdown failed", "err", err)
		}
	}
	return nil
}

func validate(lat, lon, radiusKm float64, size int) error {
	// A zero centre is almost certainly an unset flag rather than a deliberate
	// point in the Gulf of Guinea, and it is far outside the radar coverage.
	if lat == 0 && lon == 0 {
		return errors.New("-lat and -lon are required")
	}
	if lat < -85 || lat > 85 {
		return fmt.Errorf("-lat %v out of range (-85..85)", lat)
	}
	if lon < -180 || lon > 180 {
		return fmt.Errorf("-lon %v out of range (-180..180)", lon)
	}
	if radiusKm <= 0 {
		return fmt.Errorf("-radius-km must be positive, got %v", radiusKm)
	}
	if size < 256 || size > 8192 {
		return fmt.Errorf("-master-size %d out of range (256..8192)", size)
	}
	return nil
}
