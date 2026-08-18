package store

import (
	"bytes"
	"image"
	"image/color"
	"image/png"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func samplePNG(t *testing.T, shade uint8) []byte {
	t.Helper()
	img := image.NewRGBA(image.Rect(0, 0, 4, 4))
	img.Set(0, 0, color.RGBA{R: shade, A: 255})
	var buf bytes.Buffer
	require.NoError(t, png.Encode(&buf, img))
	return buf.Bytes()
}

// TestSettled pins the rule that decides a frame's cache lifetime. A frame is
// final only once it has been confirmed stable -- crucially NOT merely because
// its valid time has passed, since DWD serves blank and partial frames for past
// valid times while a model run is publishing.
func TestSettled(t *testing.T) {
	valid := time.Date(2026, 8, 18, 5, 20, 0, 0, time.UTC)

	assert.False(t, (&Frame{ValidTime: valid, FetchedAt: valid.Add(time.Hour)}).Settled(),
		"a past valid time alone must not make a frame immutable")
	assert.True(t, (&Frame{ValidTime: valid, FetchedAt: valid.Add(time.Hour), Stable: true}).Settled())
	assert.False(t, (&Frame{ValidTime: valid, FetchedAt: valid.Add(-time.Hour)}).Settled())
}

func TestPutGet(t *testing.T) {
	s, err := New(t.TempDir(), 2)
	require.NoError(t, err)

	valid := time.Date(2026, 8, 18, 5, 20, 0, 0, time.UTC)
	data := samplePNG(t, 10)
	f, err := s.Put(valid, valid.Add(time.Minute), data, true)
	require.NoError(t, err)
	assert.True(t, f.Settled())
	assert.NotEmpty(t, f.ETag)

	got, ok := s.Get(valid)
	require.True(t, ok)
	assert.Equal(t, data, got.PNG)
	assert.True(t, s.Has(valid))
	assert.False(t, s.Has(valid.Add(5*time.Minute)))
}

// TestPutReplaces covers a nowcast frame being re-rendered from a newer model
// run: the payload must change and the old file must not linger.
func TestPutReplaces(t *testing.T) {
	dir := t.TempDir()
	s, err := New(dir, 2)
	require.NoError(t, err)

	valid := time.Now().UTC().Add(time.Hour).Truncate(time.Minute)
	_, err = s.Put(valid, time.Now().UTC(), samplePNG(t, 10), true)
	require.NoError(t, err)
	second := samplePNG(t, 99)
	_, err = s.Put(valid, time.Now().UTC().Add(time.Minute), second, true)
	require.NoError(t, err)

	got, ok := s.Get(valid)
	require.True(t, ok)
	assert.Equal(t, second, got.PNG)
	assert.Equal(t, 1, s.Len())

	entries, err := os.ReadDir(dir)
	require.NoError(t, err)
	assert.Len(t, entries, 1, "the superseded file must be removed")
}

// TestReloadPreservesSettledness verifies the timestamps and the stable flag
// survive a restart, since they are encoded in the filename rather than a
// sidecar. Losing the flag would either re-confirm frames needlessly or, worse,
// promote an unconfirmed frame to immutable.
func TestReloadPreservesSettledness(t *testing.T) {
	dir := t.TempDir()
	s, err := New(dir, 2)
	require.NoError(t, err)

	stable := time.Date(2026, 8, 18, 5, 20, 0, 0, time.UTC)
	_, err = s.Put(stable, stable.Add(time.Minute), samplePNG(t, 1), true)
	require.NoError(t, err)
	unconfirmed := time.Date(2026, 8, 18, 9, 0, 0, 0, time.UTC)
	_, err = s.Put(unconfirmed, unconfirmed.Add(-time.Hour), samplePNG(t, 2), false)
	require.NoError(t, err)

	reopened, err := New(dir, 2)
	require.NoError(t, err)
	assert.Equal(t, 2, reopened.Len())

	a, ok := reopened.Get(stable)
	require.True(t, ok)
	assert.True(t, a.Settled())
	assert.Equal(t, stable.Add(time.Minute), a.FetchedAt)

	b, ok := reopened.Get(unconfirmed)
	require.True(t, ok)
	assert.False(t, b.Settled())
}

func TestLoadSkipsGarbage(t *testing.T) {
	dir := t.TempDir()
	require.NoError(t, os.WriteFile(filepath.Join(dir, "not-a-frame.png"), []byte("x"), 0o600))
	require.NoError(t, os.WriteFile(filepath.Join(dir, "123-abc.png"), []byte("x"), 0o600))
	require.NoError(t, os.WriteFile(filepath.Join(dir, "readme.txt"), []byte("x"), 0o600))

	s, err := New(dir, 2)
	require.NoError(t, err)
	assert.Equal(t, 0, s.Len(), "unparseable filenames must be skipped, not fatal")
}

func TestRetain(t *testing.T) {
	dir := t.TempDir()
	s, err := New(dir, 2)
	require.NoError(t, err)

	base := time.Date(2026, 8, 18, 5, 0, 0, 0, time.UTC)
	keep := map[int64]struct{}{}
	for i := range 4 {
		ts := base.Add(time.Duration(i) * 5 * time.Minute)
		_, err := s.Put(ts, ts.Add(time.Minute), samplePNG(t, uint8(i)), true)
		require.NoError(t, err)
		if i >= 2 {
			keep[ts.Unix()] = struct{}{}
		}
	}
	require.Equal(t, 4, s.Len())

	s.Retain(keep)
	assert.Equal(t, 2, s.Len())
	assert.False(t, s.Has(base))
	assert.True(t, s.Has(base.Add(10*time.Minute)))

	entries, err := os.ReadDir(dir)
	require.NoError(t, err)
	assert.Len(t, entries, 2, "dropped frames must be removed from disk too")
}

func TestImageDecodesAndCaches(t *testing.T) {
	s, err := New(t.TempDir(), 1)
	require.NoError(t, err)

	valid := time.Date(2026, 8, 18, 5, 20, 0, 0, time.UTC)
	f, err := s.Put(valid, valid.Add(time.Minute), samplePNG(t, 42), true)
	require.NoError(t, err)

	img, err := s.Image(f)
	require.NoError(t, err)
	assert.Equal(t, 4, img.Bounds().Dx())

	again, err := s.Image(f)
	require.NoError(t, err)
	assert.Same(t, img, again, "a second call should reuse the decoded raster")
}

// TestDecodedCacheEviction guards the memory bound: a decoded master raster is
// far larger than its encoded form, so only a few may be resident.
func TestDecodedCacheEviction(t *testing.T) {
	s, err := New(t.TempDir(), 1)
	require.NoError(t, err)

	base := time.Date(2026, 8, 18, 5, 0, 0, 0, time.UTC)
	frames := make([]*Frame, 0, 2)
	for i := range 2 {
		ts := base.Add(time.Duration(i) * 5 * time.Minute)
		f, err := s.Put(ts, ts.Add(time.Minute), samplePNG(t, uint8(i+1)), true)
		require.NoError(t, err)
		frames = append(frames, f)
	}

	first, err := s.Image(frames[0])
	require.NoError(t, err)
	_, err = s.Image(frames[1]) // evicts the first
	require.NoError(t, err)

	s.mu.RLock()
	resident := len(s.decoded)
	s.mu.RUnlock()
	assert.Equal(t, 1, resident, "cache must not exceed its capacity")

	refetched, err := s.Image(frames[0])
	require.NoError(t, err)
	assert.NotSame(t, first, refetched, "an evicted frame is decoded afresh")
}

func TestImageRejectsCorruptPayload(t *testing.T) {
	s, err := New(t.TempDir(), 2)
	require.NoError(t, err)
	f := &Frame{ValidTime: time.Now().UTC(), FetchedAt: time.Now().UTC(), PNG: []byte("not a png")}
	_, err = s.Image(f)
	assert.Error(t, err)
}

func TestETagStability(t *testing.T) {
	a := samplePNG(t, 7)
	assert.Equal(t, ETagFor(a), ETagFor(a))
	assert.NotEqual(t, ETagFor(a), ETagFor(samplePNG(t, 8)))
	assert.True(t, bytes.HasPrefix([]byte(ETagFor(a)), []byte(`"`)), "entity tags are quoted")
}
