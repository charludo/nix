package render

import (
	"bytes"
	"image"
	"image/color"
	"testing"

	"github.com/charludo/dwd-proxy/internal/geo"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// master is a 4x4 raster over a 0..400 box, each cell a distinct colour, so any
// geometric error shows up as the wrong cell rather than a subtle blend.
func master() (*image.RGBA, geo.BBox) {
	img := image.NewRGBA(image.Rect(0, 0, 4, 4))
	for y := range 4 {
		for x := range 4 {
			img.Set(x, y, color.RGBA{R: uint8(x * 40), G: uint8(y * 40), B: 200, A: 255})
		}
	}
	return img, geo.BBox{MinX: 0, MinY: 0, MaxX: 400, MaxY: 400}
}

func TestCropScaleIdentity(t *testing.T) {
	src, box := master()
	out, err := CropScale(src, box, box, 4, 4)
	require.NoError(t, err)
	for y := range 4 {
		for x := range 4 {
			assert.Equal(t, src.RGBAAt(x, y), out.RGBAAt(x, y), "pixel (%d,%d)", x, y)
		}
	}
}

// TestCropScaleQuadrant pins the y-axis flip: WMS boxes count y upwards from the
// south, images count rows downwards from the north.
func TestCropScaleQuadrant(t *testing.T) {
	src, box := master()

	// North-west quadrant: x 0..200, y 200..400. That is image rows 0..1, cols 0..1.
	nw := geo.BBox{MinX: 0, MinY: 200, MaxX: 200, MaxY: 400}
	out, err := CropScale(src, box, nw, 2, 2)
	require.NoError(t, err)
	assert.Equal(t, src.RGBAAt(0, 0), out.RGBAAt(0, 0))
	assert.Equal(t, src.RGBAAt(1, 1), out.RGBAAt(1, 1))

	// South-east quadrant: x 200..400, y 0..200 -> image rows 2..3, cols 2..3.
	se := geo.BBox{MinX: 200, MinY: 0, MaxX: 400, MaxY: 200}
	out, err = CropScale(src, box, se, 2, 2)
	require.NoError(t, err)
	assert.Equal(t, src.RGBAAt(2, 2), out.RGBAAt(0, 0))
	assert.Equal(t, src.RGBAAt(3, 3), out.RGBAAt(1, 1))
}

// TestCropScaleNearestNeighbour is the load-bearing property: upscaling must
// replicate source colours exactly, never blend two radar classes into a third.
func TestCropScaleNearestNeighbour(t *testing.T) {
	src := image.NewRGBA(image.Rect(0, 0, 2, 1))
	src.Set(0, 0, color.RGBA{R: 0, G: 0, B: 0, A: 255})
	src.Set(1, 0, color.RGBA{R: 255, G: 255, B: 255, A: 255})
	box := geo.BBox{MinX: 0, MinY: 0, MaxX: 200, MaxY: 100}

	out, err := CropScale(src, box, box, 8, 4)
	require.NoError(t, err)

	seen := map[color.RGBA]int{}
	for y := range 4 {
		for x := range 8 {
			seen[out.RGBAAt(x, y)]++
		}
	}
	assert.Len(t, seen, 2, "upscaling must not invent intermediate colours, got %v", seen)
}

// TestCropScaleOutsideSource covers a client panning past the cached area; the
// uncovered part must come back transparent rather than smeared or wrapped.
func TestCropScaleOutsideSource(t *testing.T) {
	src, box := master()
	beyond := geo.BBox{MinX: 400, MinY: 400, MaxX: 800, MaxY: 800}
	out, err := CropScale(src, box, beyond, 4, 4)
	require.NoError(t, err)
	for y := range 4 {
		for x := range 4 {
			assert.Equal(t, uint8(0), out.RGBAAt(x, y).A, "pixel (%d,%d) should be transparent", x, y)
		}
	}
}

func TestCropScaleRejectsBadSize(t *testing.T) {
	src, box := master()
	for _, c := range []struct{ w, h int }{{0, 10}, {10, 0}, {-1, 10}, {MaxDimension + 1, 10}} {
		_, err := CropScale(src, box, box, c.w, c.h)
		assert.Error(t, err, "size %dx%d should be rejected", c.w, c.h)
	}
}

func TestEncodePNGRoundTrip(t *testing.T) {
	src, _ := master()
	data, err := EncodePNG(src)
	require.NoError(t, err)
	assert.Equal(t, []byte{0x89, 'P', 'N', 'G'}, data[:4], "must carry the PNG signature")

	cfg, format, err := image.DecodeConfig(bytesReader(data))
	require.NoError(t, err)
	assert.Equal(t, "png", format)
	assert.Equal(t, 4, cfg.Width)
}

func bytesReader(b []byte) *bytes.Reader { return bytes.NewReader(b) }
