package cache

import (
	"sync"
	"time"
)

type entry[T any] struct {
	value     T
	expiresAt time.Time
}

// Cache is a thread-safe in-memory TTL cache with an injectable clock for tests.
// shortcut: concurrent cold misses can duplicate upstream fetches; add singleflight if traffic grows.
type Cache[T any] struct {
	mu    sync.RWMutex
	ttl   time.Duration
	now   func() time.Time
	items map[string]entry[T]
}

func New[T any](ttl time.Duration, now func() time.Time) *Cache[T] {
	if now == nil {
		now = time.Now
	}
	return &Cache[T]{
		ttl:   ttl,
		now:   now,
		items: make(map[string]entry[T]),
	}
}

func (c *Cache[T]) Get(key string) (T, bool) {
	c.mu.RLock()
	item, ok := c.items[key]
	c.mu.RUnlock()
	if !ok || !c.now().Before(item.expiresAt) {
		var zero T
		return zero, false
	}
	return item.value, true
}

func (c *Cache[T]) GetStale(key string) (T, bool) {
	c.mu.RLock()
	item, ok := c.items[key]
	c.mu.RUnlock()
	if !ok {
		var zero T
		return zero, false
	}
	return item.value, true
}

func (c *Cache[T]) Set(key string, value T) {
	c.mu.Lock()
	c.items[key] = entry[T]{
		value:     value,
		expiresAt: c.now().Add(c.ttl),
	}
	c.mu.Unlock()
}

func (c *Cache[T]) Delete(key string) {
	c.mu.Lock()
	delete(c.items, key)
	c.mu.Unlock()
}
