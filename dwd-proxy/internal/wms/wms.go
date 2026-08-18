// Package wms speaks the subset of OGC WMS 1.3.0 that the DWD radar service uses.
package wms

import (
	"context"
	"encoding/xml"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"github.com/charludo/dwd-proxy/internal/geo"
)

// DefaultUpstream is the DWD GeoServer endpoint.
const DefaultUpstream = "https://maps.dwd.de/geoserver/dwd/wms"

// DefaultLayer is the radar composite carrying both analysis and nowcast frames.
const DefaultLayer = "dwd:Radar_wn-product_1x1km_ger"

// FrameInterval is the cadence of the radar product's time dimension.
const FrameInterval = 5 * time.Minute

// TimeLayout is how the card formats the TIME parameter: an ISO-8601 instant
// truncated to whole seconds. Capabilities advertises milliseconds, but
// GeoServer accepts either.
const TimeLayout = "2006-01-02T15:04:05Z"

// GetMap is the subset of GetMap parameters that identifies a rendered tile.
type GetMap struct {
	Layer         string
	BBox          geo.BBox
	Width, Height int
	Time          time.Time
	// HasTime distinguishes an absent TIME (meaning "current") from a parsed one.
	HasTime bool
}

// ParseGetMap extracts GetMap parameters from a query string.
//
// WMS parameter names are case-insensitive, so the query is normalised first.
func ParseGetMap(q url.Values) (GetMap, error) {
	v := lowerKeys(q)
	if !strings.EqualFold(v.Get("request"), "GetMap") {
		return GetMap{}, fmt.Errorf("not a GetMap request")
	}
	g := GetMap{Layer: v.Get("layers")}

	bbox, err := geo.ParseBBox(v.Get("bbox"))
	if err != nil {
		return GetMap{}, err
	}
	g.BBox = bbox

	if g.Width, err = strconv.Atoi(v.Get("width")); err != nil {
		return GetMap{}, fmt.Errorf("width: %w", err)
	}
	if g.Height, err = strconv.Atoi(v.Get("height")); err != nil {
		return GetMap{}, fmt.Errorf("height: %w", err)
	}

	if ts := v.Get("time"); ts != "" && !strings.EqualFold(ts, "current") {
		t, err := ParseTime(ts)
		if err != nil {
			return GetMap{}, err
		}
		g.Time, g.HasTime = t, true
	}
	return g, nil
}

// CRS returns the coordinate reference system named by the request, normalised
// to upper case. WMS 1.3.0 calls it CRS; 1.1.1 called it SRS.
func CRS(q url.Values) string {
	v := lowerKeys(q)
	if c := v.Get("crs"); c != "" {
		return strings.ToUpper(c)
	}
	return strings.ToUpper(v.Get("srs"))
}

// ParseTime accepts the ISO-8601 spellings GeoServer emits and the card sends.
func ParseTime(s string) (time.Time, error) {
	for _, layout := range []string{TimeLayout, "2006-01-02T15:04:05.000Z", time.RFC3339} {
		if t, err := time.Parse(layout, s); err == nil {
			return t.UTC(), nil
		}
	}
	return time.Time{}, fmt.Errorf("time %q: unrecognised ISO-8601 instant", s)
}

// FormatTime renders t the way the upstream service expects it.
func FormatTime(t time.Time) string { return t.UTC().Format(TimeLayout) }

func lowerKeys(q url.Values) url.Values {
	out := make(url.Values, len(q))
	for k, vs := range q {
		out[strings.ToLower(k)] = vs
	}
	return out
}

// Client talks to an upstream WMS service.
type Client struct {
	endpoint string
	layer    string
	http     *http.Client
}

// NewClient returns a Client for the given endpoint and layer.
func NewClient(endpoint, layer string, hc *http.Client) *Client {
	return &Client{endpoint: endpoint, layer: layer, http: hc}
}

// Endpoint returns the upstream URL this client fetches from.
func (c *Client) Endpoint() string { return c.endpoint }

// MapURL builds the GetMap URL for one master raster.
func (c *Client) MapURL(b geo.BBox, size int, t time.Time) string {
	q := url.Values{
		"SERVICE":     {"WMS"},
		"VERSION":     {"1.3.0"},
		"REQUEST":     {"GetMap"},
		"LAYERS":      {c.layer},
		"STYLES":      {""},
		"FORMAT":      {"image/png"},
		"TRANSPARENT": {"true"},
		"CRS":         {"EPSG:3857"},
		"BBOX":        {b.String()},
		"WIDTH":       {strconv.Itoa(size)},
		"HEIGHT":      {strconv.Itoa(size)},
		"TIME":        {FormatTime(t)},
	}
	return c.endpoint + "?" + q.Encode()
}

// pngMagic is the 8-byte PNG signature.
var pngMagic = []byte{0x89, 'P', 'N', 'G', '\r', '\n', 0x1a, '\n'}

// ServiceError is an OGC ServiceExceptionReport returned by the upstream service.
type ServiceError struct {
	Code    string
	Locator string
	Message string
}

func (e *ServiceError) Error() string {
	return fmt.Sprintf("wms service exception (code=%q locator=%q): %s", e.Code, e.Locator, e.Message)
}

// maxImageBytes bounds how much we will read from a single GetMap response.
const maxImageBytes = 32 << 20

// FetchMap retrieves one rendered PNG.
//
// GeoServer reports errors such as an out-of-range TIME as a ServiceException
// document served with HTTP 200, so the status code alone says nothing about
// success. Anything that is not literally a PNG is treated as a failure, which
// keeps an XML error document from being cached and replayed as if it were a
// radar frame.
func (c *Client) FetchMap(ctx context.Context, b geo.BBox, size int, t time.Time) ([]byte, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.MapURL(b, size, t), nil)
	if err != nil {
		return nil, fmt.Errorf("building request: %w", err)
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("fetching map: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(io.LimitReader(resp.Body, maxImageBytes))
	if err != nil {
		return nil, fmt.Errorf("reading map body: %w", err)
	}
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("upstream returned status %d", resp.StatusCode)
	}
	if svcErr := parseServiceException(body); svcErr != nil {
		return nil, svcErr
	}
	if len(body) < len(pngMagic) || string(body[:len(pngMagic)]) != string(pngMagic) {
		return nil, fmt.Errorf("upstream returned %q, not a PNG", resp.Header.Get("Content-Type"))
	}
	return body, nil
}

type serviceExceptionReport struct {
	XMLName    xml.Name `xml:"ServiceExceptionReport"`
	Exceptions []struct {
		Code    string `xml:"code,attr"`
		Locator string `xml:"locator,attr"`
		Message string `xml:",chardata"`
	} `xml:"ServiceException"`
}

func parseServiceException(body []byte) *ServiceError {
	if !strings.Contains(string(peek(body, 512)), "ServiceExceptionReport") {
		return nil
	}
	var r serviceExceptionReport
	if err := xml.Unmarshal(body, &r); err != nil || len(r.Exceptions) == 0 {
		return &ServiceError{Message: "malformed service exception report"}
	}
	e := r.Exceptions[0]
	return &ServiceError{Code: e.Code, Locator: e.Locator, Message: strings.TrimSpace(e.Message)}
}

func peek(b []byte, n int) []byte {
	if len(b) < n {
		return b
	}
	return b[:n]
}
