package ratelimit

import (
	"fmt"
	"net/http/httptest"
	"testing"
	"time"
)

func TestLimiterPerIPAndWindowReset(t *testing.T) {
	now := time.Date(2026, 11, 12, 12, 0, 0, 0, time.UTC)
	lim := New(2, time.Minute, func() time.Time { return now })

	if ok, _ := lim.Allow("10.0.0.1"); !ok {
		t.Fatal("1st request should be allowed")
	}
	if ok, _ := lim.Allow("10.0.0.1"); !ok {
		t.Fatal("2nd request should be allowed")
	}
	if ok, retryAfter := lim.Allow("10.0.0.1"); ok || retryAfter != time.Minute {
		t.Fatalf("3rd request should be blocked with retryAfter=1m, got ok=%v retry=%v", ok, retryAfter)
	}

	if ok, _ := lim.Allow("10.0.0.2"); !ok {
		t.Fatal("different IP should have independent bucket")
	}

	now = now.Add(time.Minute)
	if ok, _ := lim.Allow("10.0.0.1"); !ok {
		t.Fatal("bucket should reset after window")
	}
}

func TestClientIPTrustProxy(t *testing.T) {
	req := httptest.NewRequest("POST", "/contact", nil)
	req.RemoteAddr = "198.51.100.10:54321"
	req.Header.Set("X-Forwarded-For", "203.0.113.9, 10.0.0.1")

	if got := ClientIP(req, false); got != "198.51.100.10" {
		t.Fatalf("expected RemoteAddr when trustProxy=false, got %q", got)
	}
	if got := ClientIP(req, true); got != "203.0.113.9" {
		t.Fatalf("expected X-Forwarded-For when trustProxy=true, got %q", got)
	}

	// Client-spoofed leftmost IP should be ignored in favor of the rightmost public hop.
	spoofReq := httptest.NewRequest("POST", "/contact", nil)
	spoofReq.RemoteAddr = "10.0.0.2:1234"
	spoofReq.Header.Set("X-Forwarded-For", "198.51.100.1, 203.0.113.50")
	if got := ClientIP(spoofReq, true); got != "203.0.113.50" {
		t.Fatalf("expected rightmost public hop 203.0.113.50, got %q", got)
	}

	// Edge headers take precedence over X-Forwarded-For when present.
	edgeReq := httptest.NewRequest("POST", "/contact", nil)
	edgeReq.Header.Set("X-Vercel-Forwarded-For", "203.0.113.77")
	edgeReq.Header.Set("X-Forwarded-For", "198.51.100.1")
	if got := ClientIP(edgeReq, true); got != "203.0.113.77" {
		t.Fatalf("expected X-Vercel-Forwarded-For 203.0.113.77, got %q", got)
	}
}

func TestLimiterCapsBucketsInMemory(t *testing.T) {
	now := time.Date(2026, 11, 12, 12, 0, 0, 0, time.UTC)
	lim := New(5, time.Minute, func() time.Time { return now })

	for i := 0; i < maxBuckets+50; i++ {
		if ok, _ := lim.Allow(fmt.Sprintf("key-%d", i)); !ok {
			t.Fatalf("unexpected block for fresh key %d", i)
		}
	}
	if len(lim.buckets) > maxBuckets {
		t.Fatalf("expected buckets capped at %d, got %d", maxBuckets, len(lim.buckets))
	}
}
