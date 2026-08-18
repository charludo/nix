// Package store keeps the master radar rasters, in memory and on disk.
package store

import (
	"bytes"
	"fmt"
	"image"
	"image/png"
	"io/fs"
	"log/slog"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"
)

// Frame is one cached master raster.
type Frame struct {
	// ValidTime is the instant the radar image depicts.
	ValidTime time.Time
	// FetchedAt is when we retrieved it.
	FetchedAt time.Time
	// PNG is the encoded master raster.
	PNG []byte
	// ETag identifies this exact payload.
	ETag string
	// Stable records that two fetches at least one model run apart returned
	// identical bytes. See [Frame.Settled].
	Stable bool
}

// Settled reports whether the frame is final and may be cached indefinitely.
//
// It is tempting to treat any frame whose valid time has passed as final, on the
// grounds that radar which has already fallen cannot change. That is wrong in
// practice: while DWD is publishing a model run, the service answers with
// HTTP 200 and a well-formed PNG that is partially or even entirely blank, for
// valid times both past and future. Trusting the first response would pin that
// artefact behind a one-year immutable lifetime.
//
// A frame is therefore only final once it has been observed twice, at least one
// model run apart, with identical bytes. Everything else is served with a short
// lifetime and refetched when the next run lands.
func (f *Frame) Settled() bool { return f.Stable }

// Store is a bounded, disk-backed collection of frames keyed by valid time.
//
// Encoded PNGs are held for every frame; decoded images are kept only for the
// most recently used ones, since a decoded 2048x2048 RGBA raster costs 16 MiB
// against roughly 380 KiB encoded.
type Store struct {
	dir        string
	decodedCap int

	mu      sync.RWMutex
	frames  map[int64]*Frame
	decoded map[int64]image.Image
	// lru orders decoded keys, least recently used first.
	lru []int64
}

// New opens or creates a store at dir and loads any frames left by a previous run.
func New(dir string, decodedCap int) (*Store, error) {
	if decodedCap < 1 {
		decodedCap = 1
	}
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return nil, fmt.Errorf("creating store dir: %w", err)
	}
	s := &Store{
		dir:        dir,
		decodedCap: decodedCap,
		frames:     map[int64]*Frame{},
		decoded:    map[int64]image.Image{},
	}
	if err := s.loadAll(); err != nil {
		return nil, err
	}
	return s, nil
}

// Get returns the frame for the given valid time.
func (s *Store) Get(validTime time.Time) (*Frame, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	f, ok := s.frames[validTime.UTC().Unix()]
	return f, ok
}

// Has reports whether a frame for validTime is present.
func (s *Store) Has(validTime time.Time) bool {
	_, ok := s.Get(validTime)
	return ok
}

// Image returns the decoded raster for a frame, decoding and caching on demand.
func (s *Store) Image(f *Frame) (image.Image, error) {
	key := f.ValidTime.UTC().Unix()

	s.mu.RLock()
	img, ok := s.decoded[key]
	s.mu.RUnlock()
	if ok {
		s.touch(key)
		return img, nil
	}

	// Decode outside the lock: it is slow enough that holding the write lock
	// would serialise every concurrent tile request behind it.
	img, err := png.Decode(bytes.NewReader(f.PNG))
	if err != nil {
		return nil, fmt.Errorf("decoding frame %s: %w", f.ValidTime.Format(time.RFC3339), err)
	}

	s.mu.Lock()
	defer s.mu.Unlock()
	// A concurrent decode of the same frame may have won the race; prefer its
	// result so both callers share one buffer.
	if existing, ok := s.decoded[key]; ok {
		return existing, nil
	}
	s.decoded[key] = img
	s.lru = append(s.lru, key)
	s.evictLocked()
	return img, nil
}

func (s *Store) touch(key int64) {
	s.mu.Lock()
	defer s.mu.Unlock()
	for i, k := range s.lru {
		if k == key {
			s.lru = append(s.lru[:i], s.lru[i+1:]...)
			s.lru = append(s.lru, key)
			return
		}
	}
}

func (s *Store) evictLocked() {
	for len(s.lru) > s.decodedCap {
		oldest := s.lru[0]
		s.lru = s.lru[1:]
		delete(s.decoded, oldest)
	}
}

// Put stores a frame, replacing any previous version of the same valid time.
func (s *Store) Put(validTime, fetchedAt time.Time, data []byte, stable bool) (*Frame, error) {
	f := &Frame{
		ValidTime: validTime.UTC(),
		FetchedAt: fetchedAt.UTC(),
		PNG:       data,
		ETag:      etag(data),
		Stable:    stable,
	}
	key := f.ValidTime.Unix()

	s.mu.Lock()
	defer s.mu.Unlock()
	if err := s.writeDisk(f); err != nil {
		return nil, err
	}
	s.frames[key] = f
	// The payload changed, so any decoded copy is stale.
	delete(s.decoded, key)
	return f, nil
}

// Retain drops every frame whose valid time is not in keep, from memory and disk.
func (s *Store) Retain(keep map[int64]struct{}) {
	s.mu.Lock()
	defer s.mu.Unlock()
	for key, f := range s.frames {
		if _, ok := keep[key]; ok {
			continue
		}
		if err := os.Remove(s.path(f)); err != nil && !os.IsNotExist(err) {
			slog.Warn("removing expired frame failed", "path", s.path(f), "err", err)
		}
		delete(s.frames, key)
		delete(s.decoded, key)
	}
	s.lru = filterKeys(s.lru, s.decoded)
}

func filterKeys(keys []int64, present map[int64]image.Image) []int64 {
	out := keys[:0]
	for _, k := range keys {
		if _, ok := present[k]; ok {
			out = append(out, k)
		}
	}
	return out
}

// Len returns the number of stored frames.
func (s *Store) Len() int {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return len(s.frames)
}

// Times returns the valid times of all stored frames, unordered.
func (s *Store) Times() []time.Time {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := make([]time.Time, 0, len(s.frames))
	for _, f := range s.frames {
		out = append(out, f.ValidTime)
	}
	return out
}

// path returns the on-disk location of a frame. The timestamps and the stable
// flag live in the filename so a frame's status survives a restart without a
// sidecar file.
func (s *Store) path(f *Frame) string {
	stable := 0
	if f.Stable {
		stable = 1
	}
	return filepath.Join(s.dir, fmt.Sprintf("%d-%d-%d.png", f.ValidTime.Unix(), f.FetchedAt.Unix(), stable))
}

func (s *Store) writeDisk(f *Frame) error {
	// Frames are replaced in place when a new model run lands, so clear any
	// older file for this valid time; its name differs by the fetch timestamp.
	s.removeExistingLocked(f.ValidTime.Unix())

	tmp, err := os.CreateTemp(s.dir, "tmp-*")
	if err != nil {
		return fmt.Errorf("creating temp frame: %w", err)
	}
	defer os.Remove(tmp.Name())
	if _, err := tmp.Write(f.PNG); err != nil {
		tmp.Close()
		return fmt.Errorf("writing frame: %w", err)
	}
	if err := tmp.Close(); err != nil {
		return fmt.Errorf("closing frame: %w", err)
	}
	if err := os.Rename(tmp.Name(), s.path(f)); err != nil {
		return fmt.Errorf("installing frame: %w", err)
	}
	return nil
}

func (s *Store) removeExistingLocked(validUnix int64) {
	old, ok := s.frames[validUnix]
	if !ok {
		return
	}
	if err := os.Remove(s.path(old)); err != nil && !os.IsNotExist(err) {
		slog.Warn("replacing frame: removing previous file failed", "path", s.path(old), "err", err)
	}
}

func (s *Store) loadAll() error {
	entries, err := os.ReadDir(s.dir)
	if err != nil {
		return fmt.Errorf("reading store dir: %w", err)
	}
	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".png") {
			continue
		}
		f, err := s.loadFrame(e)
		if err != nil {
			slog.Warn("skipping unreadable cached frame", "name", e.Name(), "err", err)
			continue
		}
		s.frames[f.ValidTime.Unix()] = f
	}
	return nil
}

func (s *Store) loadFrame(e fs.DirEntry) (*Frame, error) {
	parts := strings.Split(strings.TrimSuffix(e.Name(), ".png"), "-")
	if len(parts) != 3 {
		return nil, fmt.Errorf("malformed frame filename")
	}
	valid, err := strconv.ParseInt(parts[0], 10, 64)
	if err != nil {
		return nil, fmt.Errorf("valid time in filename: %w", err)
	}
	fetched, err := strconv.ParseInt(parts[1], 10, 64)
	if err != nil {
		return nil, fmt.Errorf("fetch time in filename: %w", err)
	}
	stable, err := strconv.ParseBool(parts[2])
	if err != nil {
		return nil, fmt.Errorf("stable flag in filename: %w", err)
	}
	data, err := os.ReadFile(filepath.Join(s.dir, e.Name()))
	if err != nil {
		return nil, err
	}
	return &Frame{
		ValidTime: time.Unix(valid, 0).UTC(),
		FetchedAt: time.Unix(fetched, 0).UTC(),
		PNG:       data,
		ETag:      etag(data),
		Stable:    stable,
	}, nil
}
