package httpapi

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/hikarilucky79/prodifolio/backend/internal/github"
	"github.com/hikarilucky79/prodifolio/backend/internal/portfolio"
	"github.com/hikarilucky79/prodifolio/backend/internal/ratelimit"
	"github.com/hikarilucky79/prodifolio/backend/internal/store"
)

type stubGitHub struct{}

func (s *stubGitHub) GetUser(_ context.Context, username string) (github.User, error) {
	return github.User{ID: 1, Login: username, Name: "Hikari", HTMLURL: "https://github.com/" + username}, nil
}

func (s *stubGitHub) ListRepos(_ context.Context, _ string) ([]github.Repo, error) {
	t := time.Date(2026, 11, 10, 12, 0, 0, 0, time.UTC)
	return []github.Repo{
		{ID: 101, Name: "KaorCount", Description: "Counter app", Language: "JavaScript", StargazersCount: 2, PushedAt: &t, HTMLURL: "https://github.com/hikarilucky79/KaorCount"},
	}, nil
}

func (s *stubGitHub) GetRepo(_ context.Context, _, name string) (github.Repo, error) {
	if name != "KaorCount" {
		return github.Repo{}, github.ErrNotFound
	}
	t := time.Date(2026, 11, 10, 12, 0, 0, 0, time.UTC)
	return github.Repo{ID: 101, Name: "KaorCount", Description: "Counter app", Language: "JavaScript", StargazersCount: 2, PushedAt: &t, HTMLURL: "https://github.com/hikarilucky79/KaorCount"}, nil
}

func (s *stubGitHub) GetRepoLanguages(_ context.Context, _, _ string) (map[string]int64, error) {
	return map[string]int64{"JavaScript": 4500}, nil
}

func (s *stubGitHub) GetLatestCommit(_ context.Context, _, _ string) (*github.Commit, error) {
	return &github.Commit{SHA: "deadbeef", Message: "init", Author: "Hikari", Date: time.Date(2026, 11, 10, 12, 0, 0, 0, time.UTC)}, nil
}

func (s *stubGitHub) ListPublicEvents(_ context.Context, _ string) ([]github.PublicEvent, error) {
	return []github.PublicEvent{
		{ID: "1", Type: "PushEvent", RepoName: "hikarilucky79/KaorCount", CreatedAt: time.Date(2026, 11, 12, 10, 0, 0, 0, time.UTC), CommitCount: 2},
	}, nil
}

func newTestServer(rateLimit int) http.Handler {
	now := func() time.Time { return time.Date(2026, 11, 12, 12, 0, 0, 0, time.UTC) }
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	st := store.NewMemory(now)
	svc := portfolio.NewService("hikarilucky79", &stubGitHub{}, st, time.Minute, now, logger)
	lim := ratelimit.New(rateLimit, time.Minute, now)
	return NewHandler(svc, st, lim, Options{
		GitHubUsername: "hikarilucky79",
		AllowedOrigins: []string{"https://hikari.dev"},
		Logger:         logger,
		Now:            now,
	})
}

func TestEndpointsAndCORS(t *testing.T) {
	h := newTestServer(5)

	// Health
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	h.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("GET /health status=%d body=%s", rec.Code, rec.Body.String())
	}

	// Projects + CORS
	rec = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodGet, "/projects", nil)
	req.Header.Set("Origin", "https://hikari.dev")
	h.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("GET /projects status=%d", rec.Code)
	}
	if rec.Header().Get("Access-Control-Allow-Origin") != "https://hikari.dev" {
		t.Fatalf("missing CORS header, got %q", rec.Header().Get("Access-Control-Allow-Origin"))
	}

	// Project detail + 404
	rec = httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/projects/KaorCount", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("GET /projects/KaorCount status=%d", rec.Code)
	}

	rec = httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/projects/does-not-exist", nil))
	if rec.Code != http.StatusNotFound {
		t.Fatalf("expected 404 for unknown repo, got %d", rec.Code)
	}

	// Stats
	rec = httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/stats", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("GET /stats status=%d", rec.Code)
	}

	// Preflight
	rec = httptest.NewRecorder()
	optReq := httptest.NewRequest(http.MethodOptions, "/contact", nil)
	optReq.Header.Set("Origin", "https://hikari.dev")
	h.ServeHTTP(rec, optReq)
	if rec.Code != http.StatusNoContent {
		t.Fatalf("OPTIONS status=%d", rec.Code)
	}
}

func TestContactValidationAndRateLimit(t *testing.T) {
	h := newTestServer(2)

	// Bad JSON
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/contact", bytes.NewBufferString("{bad"))
	req.RemoteAddr = "203.0.113.10:1234"
	h.ServeHTTP(rec, req)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rec.Code)
	}

	// Validation error -> 422 JSON with error code & message
	rec = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodPost, "/contact", bytes.NewBufferString(`{"name":"H","email":"bad","message":"short"}`))
	req.RemoteAddr = "203.0.113.10:1234"
	h.ServeHTTP(rec, req)
	if rec.Code != http.StatusUnprocessableEntity {
		t.Fatalf("expected 422, got %d", rec.Code)
	}
	var errPayload apiErrorBody
	if err := json.Unmarshal(rec.Body.Bytes(), &errPayload); err != nil {
		t.Fatalf("invalid error JSON: %v", err)
	}
	if errPayload.Error.Code != "VALIDATION_ERROR" || errPayload.Error.Message == "" {
		t.Fatalf("unexpected error payload: %+v", errPayload)
	}

	// 3rd request from same IP hits rate limit (limit=2)
	rec = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodPost, "/contact", bytes.NewBufferString(`{"name":"Hikari","email":"hikari@example.com","message":"Mensagem válida para contato."}`))
	req.RemoteAddr = "203.0.113.10:1234"
	h.ServeHTTP(rec, req)
	if rec.Code != http.StatusTooManyRequests {
		t.Fatalf("expected 429 rate limited, got %d body=%s", rec.Code, rec.Body.String())
	}
	if rec.Header().Get("Retry-After") == "" {
		t.Fatal("expected Retry-After header on 429")
	}

	// Valid request from a fresh IP returns 201 Created
	rec = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodPost, "/contact", bytes.NewBufferString(`{"name":"Hikari","email":"hikari@example.com","message":"Mensagem válida para contato."}`))
	req.RemoteAddr = "203.0.113.11:1234"
	h.ServeHTTP(rec, req)
	if rec.Code != http.StatusCreated {
		t.Fatalf("expected 201 created, got %d body=%s", rec.Code, rec.Body.String())
	}

	// Unknown JSON fields are rejected
	rec = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodPost, "/contact", bytes.NewBufferString(`{"name":"Hikari","email":"other@example.com","message":"Mensagem válida para contato.","extra":"bad"}`))
	req.RemoteAddr = "203.0.113.12:1234"
	h.ServeHTTP(rec, req)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 on unknown field, got %d", rec.Code)
	}

	// Per-email rate limiting blocks rotating IPs targeting the same email (limit=2; first hit was 203.0.113.11)
	rec = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodPost, "/contact", bytes.NewBufferString(`{"name":"Hikari","email":"hikari@example.com","message":"Segunda mensagem válida."}`))
	req.RemoteAddr = "203.0.113.13:1234"
	h.ServeHTTP(rec, req)
	if rec.Code != http.StatusCreated {
		t.Fatalf("expected 201 on 2nd email send, got %d", rec.Code)
	}

	rec = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodPost, "/contact", bytes.NewBufferString(`{"name":"Hikari","email":"hikari@example.com","message":"Terceira mensagem válida."}`))
	req.RemoteAddr = "203.0.113.14:1234"
	h.ServeHTTP(rec, req)
	if rec.Code != http.StatusTooManyRequests {
		t.Fatalf("expected 429 on 3rd email send across rotating IPs, got %d", rec.Code)
	}
}

type stubRateLimitStore struct {
	*store.MemoryStore
	allowResult bool
	calls       int
}

func (s *stubRateLimitStore) AllowRateLimit(_ context.Context, _ string, _ int, _ time.Duration) (bool, time.Duration, error) {
	s.calls++
	if !s.allowResult {
		return false, 30 * time.Second, nil
	}
	return true, 0, nil
}

func TestSecurityHeadersProductionGuardsAndSharedRateLimit(t *testing.T) {
	now := func() time.Time { return time.Date(2026, 11, 12, 12, 0, 0, 0, time.UTC) }
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	mem := store.NewMemory(now)
	svc := portfolio.NewService("hikarilucky79", &stubGitHub{}, mem, time.Minute, now, logger)

	// Production with MemoryStore degrades /health and refuses POST /contact rather than dropping leads.
	prodMemHandler := NewHandler(svc, mem, ratelimit.New(5, time.Minute, now), Options{
		GitHubUsername:      "hikarilucky79",
		RequireDBForContact: true,
		Logger:              logger,
		Now:                 now,
	})

	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	req.Header.Set("Origin", "https://evil.example")
	prodMemHandler.ServeHTTP(rec, req)
	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("expected 503 degraded health in prod without DB, got %d", rec.Code)
	}
	if rec.Header().Get("X-Content-Type-Options") != "nosniff" || rec.Header().Get("X-Frame-Options") != "DENY" {
		t.Fatalf("missing security headers on /health: %v", rec.Header())
	}
	if rec.Header().Get("Access-Control-Allow-Origin") != "" {
		t.Fatalf("expected empty CORS origin when AllowedOrigins is nil, got %q", rec.Header().Get("Access-Control-Allow-Origin"))
	}

	rec = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodPost, "/contact", bytes.NewBufferString(`{"name":"Hikari","email":"hikari@example.com","message":"Mensagem válida para teste."}`))
	prodMemHandler.ServeHTTP(rec, req)
	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("expected 503 STORAGE_UNAVAILABLE in prod without DB, got %d", rec.Code)
	}

	// Shared RateLimitStore takes precedence when implemented by the store.
	shared := &stubRateLimitStore{MemoryStore: mem, allowResult: false}
	sharedHandler := NewHandler(svc, shared, ratelimit.New(5, time.Minute, now), Options{
		GitHubUsername: "hikarilucky79",
		Logger:         logger,
		Now:            now,
	})
	rec = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodPost, "/contact", bytes.NewBufferString(`{"name":"Hikari","email":"hikari@example.com","message":"Mensagem válida para teste."}`))
	req.RemoteAddr = "203.0.113.55:1234"
	sharedHandler.ServeHTTP(rec, req)
	if rec.Code != http.StatusTooManyRequests || shared.calls != 1 {
		t.Fatalf("expected 429 from shared RateLimitStore, got status=%d calls=%d", rec.Code, shared.calls)
	}
}

func TestCORSAlwaysEmitsVaryOriginWhenRestricted(t *testing.T) {
	now := func() time.Time { return time.Date(2026, 11, 13, 18, 0, 0, 0, time.UTC) }
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	mem := store.NewMemory(now)
	svc := portfolio.NewService("hikarilucky79", &stubGitHub{}, mem, time.Minute, now, logger)

	h := NewHandler(svc, mem, ratelimit.New(5, time.Minute, now), Options{
		GitHubUsername: "hikarilucky79",
		AllowedOrigins: []string{"https://prodifolio.vercel.app"},
		Logger:         logger,
		Now:            now,
	})

	// Request without Origin (e.g. curl/crawler) must still carry Vary: Origin on cacheable GET routes.
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/projects", nil)
	h.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
	if rec.Header().Get("Vary") != "Origin" {
		t.Fatalf("expected Vary: Origin without Origin header, got %q", rec.Header().Get("Vary"))
	}
	if got := rec.Header().Get("Access-Control-Allow-Origin"); got != "" {
		t.Fatalf("expected empty Access-Control-Allow-Origin without Origin, got %q", got)
	}

	// Disallowed Origin keeps Vary: Origin without Access-Control-Allow-Origin.
	rec = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodGet, "/projects", nil)
	req.Header.Set("Origin", "https://evil.example")
	h.ServeHTTP(rec, req)
	if rec.Header().Get("Vary") != "Origin" {
		t.Fatalf("expected Vary: Origin for disallowed origin, got %q", rec.Header().Get("Vary"))
	}
	if got := rec.Header().Get("Access-Control-Allow-Origin"); got != "" {
		t.Fatalf("expected empty Access-Control-Allow-Origin for disallowed origin, got %q", got)
	}

	// Allowed Origin receives both Vary: Origin and Access-Control-Allow-Origin.
	rec = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodGet, "/projects", nil)
	req.Header.Set("Origin", "https://prodifolio.vercel.app")
	h.ServeHTTP(rec, req)
	if rec.Header().Get("Vary") != "Origin" {
		t.Fatalf("expected Vary: Origin for allowed origin, got %q", rec.Header().Get("Vary"))
	}
	if got := rec.Header().Get("Access-Control-Allow-Origin"); got != "https://prodifolio.vercel.app" {
		t.Fatalf("expected allowed origin header, got %q", got)
	}
}
