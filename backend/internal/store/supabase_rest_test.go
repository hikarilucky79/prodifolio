package store

import (
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"
	"time"

	"github.com/hikarilucky79/prodifolio/backend/internal/github"
)

func TestSupabaseRestSaveContactAndFallbacks(t *testing.T) {
	var senderConflict bool
	var missingCol bool
	var senderPostCalls, senderGetCalls, msgPostCalls atomic.Int32

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if got := r.Header.Get("apikey"); got != "sb_secret_test" {
			t.Fatalf("expected apikey header, got %q", got)
		}
		if got := r.Header.Get("Authorization"); got != "" {
			t.Fatalf("did not expect Authorization header for opaque secret key, got %q", got)
		}
		if got := r.Header.Get("User-Agent"); got != "prodifolio-api/1.0" {
			t.Fatalf("unexpected User-Agent: %q", got)
		}

		body, err := io.ReadAll(r.Body)
		if err != nil {
			t.Fatalf("read body: %v", err)
		}

		switch r.URL.Path {
		case "/rest/v1/contact_senders":
			if r.Method == http.MethodPost {
				senderPostCalls.Add(1)
				if got := r.URL.Query().Get("on_conflict"); got != "email" {
					t.Fatalf("expected on_conflict=email, got %q", got)
				}
				if senderConflict {
					w.WriteHeader(http.StatusOK)
					_, _ = w.Write([]byte(`[]`))
					return
				}
				w.WriteHeader(http.StatusCreated)
				_, _ = w.Write([]byte(`[{"id":"sender-new"}]`))
				return
			}
			if r.Method == http.MethodGet {
				senderGetCalls.Add(1)
				if got := r.URL.Query().Get("email"); got != "eq.alice+tag@example.com" {
					t.Fatalf("expected decoded email filter, got %q", got)
				}
				_, _ = w.Write([]byte(`[{"id":"sender-existing"}]`))
				return
			}
		case "/rest/v1/contact_messages":
			msgPostCalls.Add(1)
			var rows []map[string]any
			if err := json.Unmarshal(body, &rows); err != nil || len(rows) != 1 {
				t.Fatalf("unexpected contact_messages body: %s (%v)", body, err)
			}
			if missingCol {
				if _, hasSenderName := rows[0]["sender_name"]; hasSenderName {
					w.WriteHeader(http.StatusBadRequest)
					_, _ = w.Write([]byte(`{"code":"PGRST204","message":"Could not find the 'sender_name' column of 'contact_messages' in the schema cache"}`))
					return
				}
			}
			w.WriteHeader(http.StatusCreated)
			_, _ = w.Write([]byte(`[{"id":"msg-1","created_at":"2026-11-13T18:00:00Z"}]`))
			return
		default:
			t.Fatalf("unexpected request path: %s", r.URL.Path)
		}
	}))
	defer srv.Close()

	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	st, err := NewSupabaseREST(srv.URL, "sb_secret_test", srv.Client(), logger)
	if err != nil {
		t.Fatalf("NewSupabaseREST: %v", err)
	}
	if st.Mode() != "supabase" {
		t.Fatalf("expected Mode=supabase, got %q", st.Mode())
	}

	receipt, err := st.SaveContact(context.Background(), ContactInput{
		Name:     "Alice",
		Email:    "alice@example.com",
		Message:  "Hello portfolio",
		ClientIP: "unknown",
	})
	if err != nil {
		t.Fatalf("SaveContact new sender: %v", err)
	}
	if receipt.ID != "msg-1" || receipt.Status != "received" {
		t.Fatalf("unexpected receipt: %+v", receipt)
	}
	if senderGetCalls.Load() != 0 {
		t.Fatalf("did not expect fallback GET for new sender, got %d", senderGetCalls.Load())
	}

	senderConflict = true
	missingCol = true
	receipt, err = st.SaveContact(context.Background(), ContactInput{
		Name:     "Alice Impersonator",
		Email:    "alice+tag@example.com",
		Message:  "Second message",
		ClientIP: "203.0.113.5:54321",
	})
	if err != nil {
		t.Fatalf("SaveContact conflict + PGRST204 fallback: %v", err)
	}
	if senderGetCalls.Load() != 1 {
		t.Fatalf("expected 1 fallback GET for existing sender, got %d", senderGetCalls.Load())
	}
	if msgPostCalls.Load() != 3 {
		t.Fatalf("expected initial insert + 2 attempts on PGRST204 retry, got %d", msgPostCalls.Load())
	}
}

func TestSupabaseRestSyncPortfolioAndPing(t *testing.T) {
	var seenPaths []string
	var repoRows []repoUpsertRow
	var commitRows []commitActivityInsertRow

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		seenPaths = append(seenPaths, r.Method+" "+r.URL.Path)
		body, _ := io.ReadAll(r.Body)

		switch r.Method + " " + r.URL.Path {
		case "GET /rest/v1/owners":
			_, _ = w.Write([]byte(`[]`))
		case "POST /rest/v1/owners":
			w.WriteHeader(http.StatusCreated)
		case "GET /rest/v1/languages":
			_, _ = w.Write([]byte(`[{"id":1,"name":"Go"}]`))
		case "POST /rest/v1/languages":
			_, _ = w.Write([]byte(`[{"id":2,"name":"Dart"}]`))
		case "POST /rest/v1/repositories":
			if err := json.Unmarshal(body, &repoRows); err != nil {
				t.Fatalf("decode repo rows: %v", err)
			}
			w.WriteHeader(http.StatusCreated)
		case "POST /rest/v1/repository_languages":
			w.WriteHeader(http.StatusCreated)
		case "POST /rest/v1/commit_activities":
			if err := json.Unmarshal(body, &commitRows); err != nil {
				t.Fatalf("decode commit rows: %v", err)
			}
			w.WriteHeader(http.StatusCreated)
		default:
			t.Fatalf("unexpected request: %s %s", r.Method, r.URL.Path)
		}
	}))
	defer srv.Close()

	st, err := NewSupabaseREST(srv.URL, "sb_secret_test", srv.Client(), slog.New(slog.NewTextHandler(io.Discard, nil)))
	if err != nil {
		t.Fatalf("NewSupabaseREST: %v", err)
	}
	if err := st.Ping(context.Background()); err != nil {
		t.Fatalf("Ping: %v", err)
	}

	pushed := time.Date(2026, 11, 10, 12, 0, 0, 0, time.UTC)
	snapshot := PortfolioSnapshot{
		Owner: github.User{
			ID:        42,
			Login:     "hikarilucky79",
			Name:      "Hikari",
			AvatarURL: "https://avatars.githubusercontent.com/u/42",
			HTMLURL:   "https://github.com/hikarilucky79",
		},
		Repos: []github.Repo{
			{ID: 101, Name: "api", Language: "Go", PushedAt: &pushed},
			{ID: 101, Name: "api", Language: "Go", PushedAt: &pushed}, // duplicate skipped cleanly
			{ID: 102, Name: "notes", Language: ""},
		},
		Languages: map[int64]map[string]int64{
			101: {"Go": 1200, "Dart": 300},
		},
		Events: []github.PublicEvent{
			{Type: "PushEvent", RepoName: "hikarilucky79/api", HeadSHA: "abc123", CommitCount: 2, CreatedAt: pushed},
			{Type: "PushEvent", RepoName: "hikarilucky79/api", HeadSHA: "abc123", CommitCount: 2, CreatedAt: pushed}, // dup
			{Type: "WatchEvent", RepoName: "hikarilucky79/api", HeadSHA: "def456", CommitCount: 1, CreatedAt: pushed},
			{Type: "PushEvent", RepoName: "someone/other", HeadSHA: "ghi789", CommitCount: 1, CreatedAt: pushed},
		},
	}

	if err := st.SyncPortfolio(context.Background(), snapshot); err != nil {
		t.Fatalf("SyncPortfolio: %v", err)
	}
	if len(repoRows) != 2 {
		t.Fatalf("expected 2 deduplicated repo rows, got %d", len(repoRows))
	}
	if repoRows[0].PrimaryLanguageID == nil || *repoRows[0].PrimaryLanguageID != 1 {
		t.Fatalf("expected repo 101 PrimaryLanguageID=1, got %v", repoRows[0].PrimaryLanguageID)
	}
	if repoRows[1].PrimaryLanguageID != nil {
		t.Fatalf("expected repo 102 PrimaryLanguageID=nil, got %v", repoRows[1].PrimaryLanguageID)
	}
	if len(commitRows) != 1 || commitRows[0].CommitSHA != "abc123" {
		t.Fatalf("expected 1 valid commit activity row, got %+v", commitRows)
	}
	if len(seenPaths) == 0 {
		t.Fatal("expected REST calls during SyncPortfolio")
	}
}

func TestSupabaseRestAllowRateLimit(t *testing.T) {
	mode := "allow"
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/rest/v1/rpc/check_rate_limit" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		switch mode {
		case "allow":
			_, _ = w.Write([]byte(`[{"allowed":true,"retry_after_secs":0}]`))
		case "block":
			_, _ = w.Write([]byte(`[{"allowed":false,"retry_after_secs":42.5}]`))
		case "missing":
			w.WriteHeader(http.StatusNotFound)
			_, _ = w.Write([]byte(`{"code":"PGRST202","message":"Could not find the function public.check_rate_limit"}`))
		}
	}))
	defer srv.Close()

	st, err := NewSupabaseREST(srv.URL, "sb_secret_test", srv.Client(), slog.New(slog.NewTextHandler(io.Discard, nil)))
	if err != nil {
		t.Fatalf("NewSupabaseREST: %v", err)
	}

	allowed, retryAfter, err := st.AllowRateLimit(context.Background(), "ip:1.2.3.4", 5, time.Minute)
	if err != nil || !allowed || retryAfter != 0 {
		t.Fatalf("unexpected allow result: allowed=%v retryAfter=%v err=%v", allowed, retryAfter, err)
	}

	mode = "block"
	allowed, retryAfter, err = st.AllowRateLimit(context.Background(), "ip:1.2.3.4", 5, time.Minute)
	if err != nil || allowed || retryAfter != 42500*time.Millisecond {
		t.Fatalf("unexpected block result: allowed=%v retryAfter=%v err=%v", allowed, retryAfter, err)
	}

	mode = "missing"
	if _, _, err := st.AllowRateLimit(context.Background(), "ip:1.2.3.4", 5, time.Minute); err == nil {
		t.Fatal("expected error when check_rate_limit RPC is missing")
	}
}
