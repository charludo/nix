// Package prefetch keeps the frame store populated ahead of client demand.
package prefetch

import (
	"bytes"
	"context"
	"errors"
	"log/slog"
	"sync"
	"time"

	"github.com/charludo/dwd-proxy/internal/geo"
	"github.com/charludo/dwd-proxy/internal/store"
	"github.com/charludo/dwd-proxy/internal/wms"
)

// confirmDelay is how long after its nominal time a frame must have aged before
// it may be confirmed immutable, however byte-stable it looks. It exists to
// outlast DWD's publish lag, which has been measured at two to three minutes.
const confirmDelay = 10 * time.Minute

// Config parameterises the prefetcher.
type Config struct {
	// BBox is the master raster extent, shared by every cached frame.
	BBox geo.BBox
	// Size is the master raster edge length in pixels.
	Size int
	// Past and Forecast bound the frame window either side of now.
	Past, Forecast time.Duration
	// Interval is how often the window is reconciled.
	Interval time.Duration
	// RequestGap paces upstream requests so a cold start does not burst.
	RequestGap time.Duration
}

// Prefetcher fetches and refreshes master rasters in the background.
type Prefetcher struct {
	cfg    Config
	client *wms.Client
	store  *store.Store
	log    *slog.Logger

	mu sync.Mutex
	// lastRun is the model run the stored forecast frames were rendered from.
	lastRun time.Time
	// info is the most recent layer metadata from GetCapabilities.
	info wms.LayerInfo
	// haveInfo guards against acting on a zero LayerInfo before the first poll.
	haveInfo bool
	// warm reports whether at least one reconcile has finished.
	warm bool
}

// New returns a Prefetcher.
func New(cfg Config, client *wms.Client, s *store.Store, log *slog.Logger) *Prefetcher {
	if cfg.Interval <= 0 {
		cfg.Interval = time.Minute
	}
	return &Prefetcher{cfg: cfg, client: client, store: s, log: log}
}

// Warm reports whether the first reconcile pass has completed.
func (p *Prefetcher) Warm() bool {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.warm
}

// Run reconciles the frame window until ctx is cancelled.
func (p *Prefetcher) Run(ctx context.Context) {
	t := time.NewTicker(p.cfg.Interval)
	defer t.Stop()
	p.reconcile(ctx)
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			p.reconcile(ctx)
		}
	}
}

func (p *Prefetcher) reconcile(ctx context.Context) {
	info, err := p.client.Capabilities(ctx)
	if err != nil {
		// Capabilities is only needed to clamp the window and spot new model
		// runs. If it fails we fall back to the last known metadata rather than
		// stalling; a cold start with no metadata simply retries next tick.
		p.log.Warn("capabilities poll failed", "err", err)
		p.mu.Lock()
		info, ok := p.info, p.haveInfo
		p.mu.Unlock()
		if !ok {
			return
		}
		p.apply(ctx, info)
		return
	}

	p.mu.Lock()
	p.info, p.haveInfo = info, true
	p.mu.Unlock()
	p.apply(ctx, info)
}

func (p *Prefetcher) apply(ctx context.Context, info wms.LayerInfo) {
	now := time.Now().UTC()
	wanted := p.window(now, info)

	// Every frame we hold that is not yet confirmed stable is re-examined when a
	// new run lands, whether it depicts the past or the future: a frame captured
	// while DWD was mid-publish can be blank or partial regardless of its valid
	// time, and only a second look reveals that.
	//
	// With no REFERENCE_TIME to go on we cannot tell runs apart, so fall back to
	// re-examining on every tick. That is more upstream traffic than necessary,
	// but it never leaves a bad frame in place.
	p.mu.Lock()
	newRun := info.ReferenceTime.IsZero() || info.ReferenceTime.After(p.lastRun)
	if newRun && !info.ReferenceTime.IsZero() {
		p.lastRun = info.ReferenceTime
	}
	p.mu.Unlock()
	if newRun && !info.ReferenceTime.IsZero() {
		p.log.Info("new model run published", "referenceTime", info.ReferenceTime)
	}

	keep := make(map[int64]struct{}, len(wanted))
	for _, t := range wanted {
		keep[t.Unix()] = struct{}{}
	}
	p.store.Retain(keep)

	var fetched, refreshed, confirmed int
	for _, t := range wanted {
		if ctx.Err() != nil {
			return
		}
		existing, have := p.store.Get(t)
		switch {
		case !have:
		case existing.Stable:
			continue // confirmed final, never refetched
		case newRun:
			refreshed++
		default:
			continue // unconfirmed, but no new run to compare against yet
		}

		if err := p.fetch(ctx, t); err != nil {
			if errors.Is(err, context.Canceled) || errors.Is(err, context.DeadlineExceeded) {
				return
			}
			p.log.Warn("frame fetch failed", "time", wms.FormatTime(t), "err", err)
			continue
		}
		if !have {
			fetched++
		} else if now, ok := p.store.Get(t); ok && now.Stable {
			confirmed++
		}
		p.pace(ctx)
	}

	p.mu.Lock()
	p.warm = true
	p.mu.Unlock()

	if fetched > 0 || refreshed > 0 {
		p.log.Info("frame window reconciled",
			"new", fetched, "refreshed", refreshed, "confirmed", confirmed, "total", p.store.Len())
	}
}

func (p *Prefetcher) fetch(ctx context.Context, t time.Time) error {
	data, err := p.client.FetchMap(ctx, p.cfg.BBox, p.cfg.Size, t)
	if err != nil {
		return err
	}
	// Two identical payloads seen a model run apart mean DWD has finished
	// publishing this frame, so it can be promoted to immutable. Callers only
	// reach this path for frames that are not already stable, so the comparison
	// is always against an earlier, unconfirmed fetch.
	//
	// Byte-stability alone is not enough. For a minute or two after a frame's
	// nominal time, DWD serves the *previous* frame's raster under the new
	// timestamp -- with GetCapabilities already advertising the new one. Two
	// fetches landing inside that window would agree with each other and freeze
	// a duplicate as immutable for a year, with no way to invalidate it short of
	// wiping the state directory. Requiring the frame to have aged past
	// confirmDelay puts that window well out of reach.
	now := time.Now().UTC()
	stable := false
	if prev, ok := p.store.Get(t); ok && bytes.Equal(prev.PNG, data) && now.Sub(t) >= confirmDelay {
		stable = true
	}
	_, err = p.store.Put(t, now, data, stable)
	return err
}

func (p *Prefetcher) pace(ctx context.Context) {
	if p.cfg.RequestGap <= 0 {
		return
	}
	select {
	case <-ctx.Done():
	case <-time.After(p.cfg.RequestGap):
	}
}

// window returns the frame times to hold, newest first so that a cold start
// fills in the frames a client is most likely to ask for before the older tail.
func (p *Prefetcher) window(now time.Time, info wms.LayerInfo) []time.Time {
	step := info.Interval
	if step <= 0 {
		step = wms.FrameInterval
	}

	// Snap to the interval grid the service publishes on.
	last := now.Add(p.cfg.Forecast).Truncate(step)
	first := now.Add(-p.cfg.Past).Truncate(step)

	// Requesting a TIME outside the advertised extent is a ServiceException, so
	// clamp rather than let the tail of the window fail every tick.
	if !info.End.IsZero() && last.After(info.End) {
		last = info.End.Truncate(step)
	}
	if !info.Start.IsZero() && first.Before(info.Start) {
		first = info.Start.Truncate(step)
		if first.Before(info.Start) {
			first = first.Add(step)
		}
	}

	var out []time.Time
	for t := last; !t.Before(first); t = t.Add(-step) {
		out = append(out, t.UTC())
	}
	return out
}
