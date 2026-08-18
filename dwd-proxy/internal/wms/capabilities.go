package wms

import (
	"context"
	"encoding/xml"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

// LayerInfo describes the time dimensions of one WMS layer.
type LayerInfo struct {
	// Start and End bound the advertised valid-time extent. Asking for a TIME
	// outside this window yields a ServiceException, so the prefetcher clamps to it.
	Start, End time.Time
	// Interval is the step of the time dimension.
	Interval time.Duration
	// ReferenceTime is the default model run. It advances when DWD publishes a
	// new nowcast, which is the signal that forecast frames need refetching.
	ReferenceTime time.Time
}

type capDimension struct {
	Name    string `xml:"name,attr"`
	Default string `xml:"default,attr"`
	Value   string `xml:",chardata"`
}

type capLayer struct {
	Name       string         `xml:"Name"`
	Dimensions []capDimension `xml:"Dimension"`
	Layers     []capLayer     `xml:"Layer"`
}

type capabilities struct {
	XMLName xml.Name `xml:"WMS_Capabilities"`
	Layer   capLayer `xml:"Capability>Layer"`
}

// maxCapabilitiesBytes bounds the capabilities document we will read.
const maxCapabilitiesBytes = 64 << 20

// Capabilities fetches GetCapabilities and returns the time metadata for the
// client's layer.
func (c *Client) Capabilities(ctx context.Context) (LayerInfo, error) {
	q := url.Values{
		"SERVICE": {"WMS"},
		"VERSION": {"1.3.0"},
		"REQUEST": {"GetCapabilities"},
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.endpoint+"?"+q.Encode(), nil)
	if err != nil {
		return LayerInfo{}, fmt.Errorf("building capabilities request: %w", err)
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return LayerInfo{}, fmt.Errorf("fetching capabilities: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return LayerInfo{}, fmt.Errorf("capabilities returned status %d", resp.StatusCode)
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, maxCapabilitiesBytes))
	if err != nil {
		return LayerInfo{}, fmt.Errorf("reading capabilities: %w", err)
	}
	return parseCapabilities(body, c.layer)
}

func parseCapabilities(body []byte, layer string) (LayerInfo, error) {
	var caps capabilities
	if err := xml.Unmarshal(body, &caps); err != nil {
		return LayerInfo{}, fmt.Errorf("parsing capabilities: %w", err)
	}
	// Capabilities names layers without the workspace prefix that GetMap accepts.
	want := layer
	if _, after, found := strings.Cut(layer, ":"); found {
		want = after
	}
	found := findLayer(&caps.Layer, want)
	if found == nil {
		return LayerInfo{}, fmt.Errorf("layer %q not found in capabilities", layer)
	}
	return layerInfo(found)
}

func findLayer(l *capLayer, name string) *capLayer {
	if l.Name == name {
		return l
	}
	for i := range l.Layers {
		if got := findLayer(&l.Layers[i], name); got != nil {
			return got
		}
	}
	return nil
}

func layerInfo(l *capLayer) (LayerInfo, error) {
	var info LayerInfo
	var haveTime bool
	for _, d := range l.Dimensions {
		switch strings.ToLower(d.Name) {
		case "time":
			start, end, step, err := parseExtent(strings.TrimSpace(d.Value))
			if err != nil {
				return LayerInfo{}, fmt.Errorf("time dimension: %w", err)
			}
			info.Start, info.End, info.Interval = start, end, step
			haveTime = true
		case "reference_time":
			// The default attribute names the current model run; the body lists
			// every retained run, which we do not need.
			if t, err := ParseTime(strings.TrimSpace(d.Default)); err == nil {
				info.ReferenceTime = t
			}
		}
	}
	if !haveTime {
		return LayerInfo{}, fmt.Errorf("layer has no time dimension")
	}
	return info, nil
}

// parseExtent reads an ISO-8601 extent, which WMS may express either as a
// "start/end/period" interval or as an explicit comma-separated list of instants.
func parseExtent(v string) (start, end time.Time, step time.Duration, err error) {
	if v == "" {
		return start, end, 0, fmt.Errorf("empty extent")
	}
	if parts := strings.Split(v, "/"); len(parts) == 3 {
		if start, err = ParseTime(parts[0]); err != nil {
			return start, end, 0, fmt.Errorf("extent start: %w", err)
		}
		if end, err = ParseTime(parts[1]); err != nil {
			return start, end, 0, fmt.Errorf("extent end: %w", err)
		}
		if step, err = parseISODuration(parts[2]); err != nil {
			return start, end, 0, fmt.Errorf("extent period: %w", err)
		}
		return start, end, step, nil
	}

	values := strings.Split(v, ",")
	first, err := ParseTime(strings.TrimSpace(values[0]))
	if err != nil {
		return start, end, 0, fmt.Errorf("extent list: %w", err)
	}
	last, err := ParseTime(strings.TrimSpace(values[len(values)-1]))
	if err != nil {
		return start, end, 0, fmt.Errorf("extent list: %w", err)
	}
	return first, last, FrameInterval, nil
}

// parseISODuration handles the PnDTnHnMnS subset that time dimensions use.
func parseISODuration(s string) (time.Duration, error) {
	s = strings.TrimSpace(s)
	if !strings.HasPrefix(s, "P") {
		return 0, fmt.Errorf("duration %q: missing P designator", s)
	}
	date, timePart, _ := strings.Cut(s[1:], "T")

	var total time.Duration
	consume := func(part string, units map[byte]time.Duration) error {
		var num strings.Builder
		for i := range len(part) {
			ch := part[i]
			if ch >= '0' && ch <= '9' {
				num.WriteByte(ch)
				continue
			}
			unit, ok := units[ch]
			if !ok {
				return fmt.Errorf("duration %q: unsupported designator %q", s, string(ch))
			}
			if num.Len() == 0 {
				return fmt.Errorf("duration %q: designator %q without a value", s, string(ch))
			}
			var n int
			if _, err := fmt.Sscanf(num.String(), "%d", &n); err != nil {
				return fmt.Errorf("duration %q: %w", s, err)
			}
			total += time.Duration(n) * unit
			num.Reset()
		}
		if num.Len() > 0 {
			return fmt.Errorf("duration %q: trailing value without a designator", s)
		}
		return nil
	}

	if err := consume(date, map[byte]time.Duration{
		'D': 24 * time.Hour,
		'W': 7 * 24 * time.Hour,
	}); err != nil {
		return 0, err
	}
	if err := consume(timePart, map[byte]time.Duration{
		'H': time.Hour,
		'M': time.Minute,
		'S': time.Second,
	}); err != nil {
		return 0, err
	}
	if total <= 0 {
		return 0, fmt.Errorf("duration %q: not positive", s)
	}
	return total, nil
}
