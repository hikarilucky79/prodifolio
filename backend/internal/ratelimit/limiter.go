package ratelimit

import (
	"net"
	"net/http"
	"net/netip"
	"strings"
	"sync"
	"time"
)

const maxBuckets = 4096

type bucket struct {
	count   int
	resetAt time.Time
}

// Limiter enforces fixed-window per-key request limits in process memory.
type Limiter struct {
	limit   int
	window  time.Duration
	now     func() time.Time
	mu      sync.Mutex
	buckets map[string]bucket
}

func New(limit int, window time.Duration, now func() time.Time) *Limiter {
	if now == nil {
		now = time.Now
	}
	return &Limiter{
		limit:   limit,
		window:  window,
		now:     now,
		buckets: make(map[string]bucket),
	}
}

func (l *Limiter) Limit() int {
	return l.limit
}

func (l *Limiter) Window() time.Duration {
	return l.window
}

func (l *Limiter) Allow(key string) (bool, time.Duration) {
	now := l.now()
	l.mu.Lock()
	defer l.mu.Unlock()

	if len(l.buckets) > 1024 {
		for k, b := range l.buckets {
			if !now.Before(b.resetAt) {
				delete(l.buckets, k)
			}
		}
	}

	b, ok := l.buckets[key]
	if !ok && len(l.buckets) >= maxBuckets {
		// Evict expired or oldest-expiring bucket so random key floods stay bounded in memory.
		var oldestKey string
		var oldestReset time.Time
		first := true
		for k, existing := range l.buckets {
			if first || existing.resetAt.Before(oldestReset) {
				oldestKey = k
				oldestReset = existing.resetAt
				first = false
			}
		}
		if oldestKey != "" {
			delete(l.buckets, oldestKey)
		}
	}

	if !ok || !now.Before(b.resetAt) {
		l.buckets[key] = bucket{count: 1, resetAt: now.Add(l.window)}
		return true, 0
	}
	if b.count >= l.limit {
		return false, b.resetAt.Sub(now)
	}
	b.count++
	l.buckets[key] = b
	return true, 0
}

// ClientIP returns a normalized IPv4/IPv6 address, honoring proxy headers only when trusted.
func ClientIP(r *http.Request, trustProxy bool) string {
	if trustProxy {
		for _, header := range []string{"X-Vercel-Forwarded-For", "X-Real-IP"} {
			if val := strings.TrimSpace(r.Header.Get(header)); val != "" {
				if addr, err := netip.ParseAddr(val); err == nil {
					return addr.Unmap().String()
				}
			}
		}
		if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
			if ip, ok := rightmostClientIP(xff); ok {
				return ip
			}
		}
	}

	host, _, err := net.SplitHostPort(strings.TrimSpace(r.RemoteAddr))
	if err != nil {
		host = strings.TrimSpace(r.RemoteAddr)
	}
	if addr, err := netip.ParseAddr(host); err == nil {
		return addr.Unmap().String()
	}
	return "127.0.0.1"
}

// rightmostClientIP selects the rightmost public hop in X-Forwarded-For (or the rightmost valid IP
// if all hops are private) so client-prepended headers cannot spoof the client IP behind appending proxies.
func rightmostClientIP(xff string) (string, bool) {
	parts := strings.Split(xff, ",")
	var fallback string
	for i := len(parts) - 1; i >= 0; i-- {
		raw := strings.TrimSpace(parts[i])
		if raw == "" {
			continue
		}
		addr, err := netip.ParseAddr(raw)
		if err != nil {
			continue
		}
		addr = addr.Unmap()
		if fallback == "" {
			fallback = addr.String()
		}
		if isPublicIP(addr) {
			return addr.String(), true
		}
	}
	if fallback != "" {
		return fallback, true
	}
	return "", false
}

func isPublicIP(addr netip.Addr) bool {
	return addr.IsValid() &&
		!addr.IsLoopback() &&
		!addr.IsPrivate() &&
		!addr.IsLinkLocalUnicast() &&
		!addr.IsLinkLocalMulticast() &&
		!addr.IsMulticast() &&
		!addr.IsUnspecified()
}
