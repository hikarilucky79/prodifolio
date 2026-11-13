package cache

import (
	"testing"
	"time"
)

func TestCacheExpiration(t *testing.T) {
	now := time.Date(2026, 11, 12, 12, 0, 0, 0, time.UTC)
	c := New[string](5*time.Minute, func() time.Time { return now })

	c.Set("projects", "cached-value")

	if got, ok := c.Get("projects"); !ok || got != "cached-value" {
		t.Fatalf("expected cache hit, got ok=%v val=%q", ok, got)
	}

	now = now.Add(4*time.Minute + 59*time.Second)
	if _, ok := c.Get("projects"); !ok {
		t.Fatal("expected cache hit before TTL expiry")
	}

	now = now.Add(1 * time.Second)
	if _, ok := c.Get("projects"); ok {
		t.Fatal("expected cache miss at TTL expiry")
	}

	if got, ok := c.GetStale("projects"); !ok || got != "cached-value" {
		t.Fatalf("expected stale cache hit, got ok=%v val=%q", ok, got)
	}

	c.Delete("projects")
	if _, ok := c.GetStale("projects"); ok {
		t.Fatal("expected cache entry to be deleted")
	}
}
