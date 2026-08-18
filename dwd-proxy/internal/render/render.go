// Package render derives a client-sized tile from a cached master raster.
package render

import (
	"bytes"
	"fmt"
	"image"
	"image/draw"
	"image/png"

	"github.com/charludo/dwd-proxy/internal/geo"
)

// MaxDimension caps the output size we are willing to render, so a hostile or
// buggy client cannot ask us to allocate an arbitrarily large image.
const MaxDimension = 4096

// CropScale resamples the region of src covered by dst into a width x height image.
//
// Sampling is nearest-neighbour by design. The radar product is categorical:
// every colour encodes a specific reflectivity class, and the card runs a
// palette-sensitive mask filter over the pixels it gets back. Interpolating
// would invent colours that sit between two classes and belong to neither,
// which that filter cannot classify.
func CropScale(src image.Image, srcBox, dst geo.BBox, width, height int) (*image.RGBA, error) {
	if width <= 0 || height <= 0 || width > MaxDimension || height > MaxDimension {
		return nil, fmt.Errorf("output size %dx%d out of range (1..%d)", width, height, MaxDimension)
	}
	if !srcBox.Valid() || !dst.Valid() {
		return nil, fmt.Errorf("invalid bounding box")
	}

	// Work against a concrete RGBA buffer so the inner loop is a slice index
	// rather than a per-pixel interface call through image.Image.At.
	rgba := asRGBA(src)
	sb := rgba.Bounds()
	srcW, srcH := sb.Dx(), sb.Dy()
	if srcW == 0 || srcH == 0 {
		return nil, fmt.Errorf("source image is empty")
	}

	out := image.NewRGBA(image.Rect(0, 0, width, height))

	// Projected metres per output pixel.
	dxPerPx := dst.Width() / float64(width)
	dyPerPx := dst.Height() / float64(height)
	// Source pixels per projected metre.
	sxPerM := float64(srcW) / srcBox.Width()
	syPerM := float64(srcH) / srcBox.Height()

	for j := range height {
		// Row 0 is the northern edge, so y counts down from MaxY.
		y := dst.MaxY - (float64(j)+0.5)*dyPerPx
		sy := int((srcBox.MaxY - y) * syPerM)
		if sy < 0 || sy >= srcH {
			continue // leaves the row fully transparent
		}
		srcRow := rgba.Pix[sy*rgba.Stride:]
		dstRow := out.Pix[j*out.Stride:]
		for i := range width {
			x := dst.MinX + (float64(i)+0.5)*dxPerPx
			sx := int((x - srcBox.MinX) * sxPerM)
			if sx < 0 || sx >= srcW {
				continue
			}
			copy(dstRow[i*4:i*4+4], srcRow[sx*4:sx*4+4])
		}
	}
	return out, nil
}

// asRGBA returns src as *image.RGBA, converting only when necessary.
func asRGBA(src image.Image) *image.RGBA {
	if r, ok := src.(*image.RGBA); ok {
		return r
	}
	b := src.Bounds()
	r := image.NewRGBA(image.Rect(0, 0, b.Dx(), b.Dy()))
	draw.Draw(r, r.Bounds(), src, b.Min, draw.Src)
	return r
}

// EncodePNG encodes img with fast compression.
//
// These images are re-derived on demand and served over a LAN, so spending CPU
// to shave bytes off the wire is the wrong trade.
func EncodePNG(img image.Image) ([]byte, error) {
	var buf bytes.Buffer
	enc := png.Encoder{CompressionLevel: png.BestSpeed}
	if err := enc.Encode(&buf, img); err != nil {
		return nil, fmt.Errorf("encoding png: %w", err)
	}
	return buf.Bytes(), nil
}
