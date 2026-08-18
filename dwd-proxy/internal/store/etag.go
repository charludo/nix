package store

import (
	"crypto/sha256"
	"encoding/base64"
)

// etag derives a strong entity tag from a payload.
func etag(data []byte) string {
	sum := sha256.Sum256(data)
	return `"` + base64.RawURLEncoding.EncodeToString(sum[:16]) + `"`
}

// ETagFor exposes the entity-tag derivation for payloads derived from a frame.
func ETagFor(data []byte) string { return etag(data) }
