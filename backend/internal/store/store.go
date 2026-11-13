package store

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"sync"
	"time"

	"github.com/hikarilucky79/prodifolio/backend/internal/github"
)

type ContactInput struct {
	Name     string
	Email    string
	Message  string
	ClientIP string
}

type ContactReceipt struct {
	ID        string    `json:"id"`
	Status    string    `json:"status"`
	CreatedAt time.Time `json:"created_at"`
}

type PortfolioSnapshot struct {
	Owner     github.User
	Repos     []github.Repo
	Languages map[int64]map[string]int64
	Events    []github.PublicEvent
}

type Store interface {
	SaveContact(ctx context.Context, input ContactInput) (ContactReceipt, error)
	SyncPortfolio(ctx context.Context, snapshot PortfolioSnapshot) error
	Ping(ctx context.Context) error
	Close() error
	Mode() string
}

// RateLimitStore provides shared atomic rate limiting across instances when backed by Postgres.
type RateLimitStore interface {
	AllowRateLimit(ctx context.Context, key string, limit int, window time.Duration) (bool, time.Duration, error)
}

const maxMemoryMessages = 500

// MemoryStore provides an in-memory fallback when SUPABASE_DB_URL is omitted in tests/local dev.
type MemoryStore struct {
	mu       sync.Mutex
	now      func() time.Time
	senders  map[string]string
	messages []ContactInput
}

func NewMemory(now func() time.Time) *MemoryStore {
	if now == nil {
		now = time.Now
	}
	return &MemoryStore{
		now:     now,
		senders: make(map[string]string),
	}
}

func (m *MemoryStore) SaveContact(_ context.Context, input ContactInput) (ContactReceipt, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if _, exists := m.senders[input.Email]; !exists {
		if len(m.senders) >= maxMemoryMessages {
			clear(m.senders)
		}
		m.senders[input.Email] = input.Name
	}
	if len(m.messages) >= maxMemoryMessages {
		copy(m.messages, m.messages[1:])
		m.messages = m.messages[:maxMemoryMessages-1]
	}
	m.messages = append(m.messages, input)

	return ContactReceipt{
		ID:        randomID(),
		Status:    "received",
		CreatedAt: m.now().UTC(),
	}, nil
}

func (m *MemoryStore) SyncPortfolio(_ context.Context, _ PortfolioSnapshot) error {
	return nil
}

func (m *MemoryStore) Ping(_ context.Context) error {
	return nil
}

func (m *MemoryStore) Close() error {
	return nil
}

func (m *MemoryStore) Mode() string {
	return "memory"
}

func (m *MemoryStore) MessagesCount() int {
	m.mu.Lock()
	defer m.mu.Unlock()
	return len(m.messages)
}

func randomID() string {
	var b [16]byte
	if _, err := rand.Read(b[:]); err != nil {
		return time.Now().UTC().Format("20060102150405.000000000")
	}
	return hex.EncodeToString(b[:])
}
