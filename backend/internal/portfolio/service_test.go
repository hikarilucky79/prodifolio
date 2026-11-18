package portfolio

import (
	"context"
	"errors"
	"io"
	"log/slog"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/hikarilucky79/prodifolio/backend/internal/github"
	"github.com/hikarilucky79/prodifolio/backend/internal/store"
)

type fakeGitHubClient struct {
	user         github.User
	repos        []github.Repo
	langs        map[string]map[string]int64
	commits      map[string]*github.Commit
	events       []github.PublicEvent
	listErr      error
	listCalls    atomic.Int32
	getRepoCalls atomic.Int32
	eventCalls   atomic.Int32
}

func (f *fakeGitHubClient) GetUser(_ context.Context, _ string) (github.User, error) {
	return f.user, nil
}

func (f *fakeGitHubClient) ListRepos(_ context.Context, _ string) ([]github.Repo, error) {
	f.listCalls.Add(1)
	if f.listErr != nil {
		return nil, f.listErr
	}
	return f.repos, nil
}

func (f *fakeGitHubClient) GetRepo(_ context.Context, _, name string) (github.Repo, error) {
	f.getRepoCalls.Add(1)
	for _, r := range f.repos {
		if r.Name == name {
			return r, nil
		}
	}
	return github.Repo{}, github.ErrNotFound
}

func (f *fakeGitHubClient) GetRepoLanguages(_ context.Context, _, name string) (map[string]int64, error) {
	if l, ok := f.langs[name]; ok {
		return l, nil
	}
	return map[string]int64{}, nil
}

func (f *fakeGitHubClient) GetLatestCommit(_ context.Context, _, name string) (*github.Commit, error) {
	return f.commits[name], nil
}

func (f *fakeGitHubClient) ListPublicEvents(_ context.Context, _ string) ([]github.PublicEvent, error) {
	f.eventCalls.Add(1)
	return f.events, nil
}

func TestServiceCachesReposAndFallsBackToStale(t *testing.T) {
	now := time.Date(2026, 11, 12, 12, 0, 0, 0, time.UTC)
	pushed := now.Add(-2 * time.Hour)
	gh := &fakeGitHubClient{
		user: github.User{ID: 1, Login: "hikarilucky79", Name: "Hikari", HTMLURL: "https://github.com/hikarilucky79"},
		repos: []github.Repo{
			{ID: 10, Name: "prodifolio", Description: "Portfolio", Language: "Go", StargazersCount: 7, PushedAt: &pushed, HTMLURL: "https://github.com/hikarilucky79/prodifolio"},
		},
	}
	st := store.NewMemory(func() time.Time { return now })
	svc := NewService("hikarilucky79", gh, st, 5*time.Minute, func() time.Time { return now }, slog.New(slog.NewTextHandler(io.Discard, nil)))

	first, err := svc.ListProjects(context.Background())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if first.Cached || len(first.Projects) != 1 || first.Projects[0].Name != "prodifolio" {
		t.Fatalf("unexpected first response: %+v", first)
	}

	second, err := svc.ListProjects(context.Background())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !second.Cached || gh.listCalls.Load() != 1 {
		t.Fatalf("expected cached response with 1 upstream call, got cached=%v calls=%d", second.Cached, gh.listCalls.Load())
	}

	now = now.Add(6 * time.Minute)
	gh.listErr = errors.New("github temporary failure")
	stale, err := svc.ListProjects(context.Background())
	if err != nil {
		t.Fatalf("expected stale fallback instead of error, got %v", err)
	}
	if !stale.Cached || len(stale.Projects) != 1 || gh.listCalls.Load() != 2 {
		t.Fatalf("expected stale cache after upstream error, got %+v calls=%d", stale, gh.listCalls.Load())
	}
}

func TestServiceStatsAndProjectDetail(t *testing.T) {
	now := time.Date(2026, 11, 12, 12, 0, 0, 0, time.UTC)
	gh := &fakeGitHubClient{
		user: github.User{ID: 1, Login: "hikarilucky79"},
		repos: []github.Repo{
			{ID: 1, Name: "api-go", Language: "Go", StargazersCount: 4, HTMLURL: "https://github.com/hikarilucky79/api-go"},
			{ID: 2, Name: "ui-flutter", Language: "Dart", StargazersCount: 6, HTMLURL: "https://github.com/hikarilucky79/ui-flutter"},
			{ID: 3, Name: "cli-go", Language: "Go", StargazersCount: 2, HTMLURL: "https://github.com/hikarilucky79/cli-go"},
		},
		langs: map[string]map[string]int64{
			"api-go": {"Go": 8000, "Shell": 400},
		},
		commits: map[string]*github.Commit{
			"api-go": {SHA: "abc123", Message: "feat: add cache\n\ndetails", Author: "Hikari", Date: now.Add(-time.Hour)},
		},
		events: []github.PublicEvent{
			{ID: "e1", Type: "PushEvent", RepoName: "hikarilucky79/api-go", CreatedAt: now.Add(-24 * time.Hour), CommitCount: 3},
			{ID: "e2", Type: "PushEvent", RepoName: "hikarilucky79/ui-flutter", CreatedAt: now, CommitCount: 2},
			{ID: "e3", Type: "WatchEvent", RepoName: "other/repo", CreatedAt: now, CommitCount: 0},
		},
	}
	svc := NewService("hikarilucky79", gh, store.NewMemory(nil), 5*time.Minute, func() time.Time { return now }, slog.New(slog.NewTextHandler(io.Discard, nil)))

	detail, err := svc.GetProject(context.Background(), "api-go")
	if err != nil {
		t.Fatalf("unexpected GetProject error: %v", err)
	}
	if len(detail.Languages) != 2 || detail.Languages[0] != "Go" || detail.LastCommitMessage != "feat: add cache" {
		t.Fatalf("unexpected project detail: %+v", detail)
	}

	if _, err := svc.GetProject(context.Background(), "../secret"); !errors.Is(err, ErrInvalidRepoName) {
		t.Fatalf("expected ErrInvalidRepoName, got %v", err)
	}

	stats, err := svc.GetStats(context.Background())
	if err != nil {
		t.Fatalf("unexpected GetStats error: %v", err)
	}
	if stats.TotalProjects != 3 || stats.TotalStars != 12 {
		t.Fatalf("unexpected totals: %+v", stats)
	}
	if len(stats.Languages) != 2 || stats.Languages[0].Name != "Go" || stats.Languages[0].Count != 2 {
		t.Fatalf("unexpected language breakdown: %+v", stats.Languages)
	}
	if len(stats.Activity) != 14 {
		t.Fatalf("expected 14-day activity window, got %d", len(stats.Activity))
	}
	if stats.Activity[12].Commits != 3 || stats.Activity[13].Commits != 2 {
		t.Fatalf("unexpected recent activity counts: %+v", stats.Activity[12:])
	}
}

func TestSubmitContactValidation(t *testing.T) {
	now := time.Date(2026, 11, 12, 12, 0, 0, 0, time.UTC)
	st := store.NewMemory(func() time.Time { return now })
	svc := NewService("hikarilucky79", &fakeGitHubClient{}, st, time.Minute, func() time.Time { return now }, slog.New(slog.NewTextHandler(io.Discard, nil)))

	_, err := svc.SubmitContact(context.Background(), ContactRequest{
		Name:    "A",
		Email:   "invalid-email",
		Message: "short",
	}, "127.0.0.1")
	var valErr *ValidationError
	if !errors.As(err, &valErr) {
		t.Fatalf("expected ValidationError, got %v", err)
	}
	if len(valErr.Fields) != 3 {
		t.Fatalf("expected 3 validation field errors, got %+v", valErr.Fields)
	}

	receipt, err := svc.SubmitContact(context.Background(), ContactRequest{
		Name:    "  Hikari  ",
		Email:   "  HIKARI@EXAMPLE.COM ",
		Message: "Olá, gostei bastante do seu portfólio prodifolio!",
	}, "127.0.0.1")
	if err != nil {
		t.Fatalf("expected valid contact to succeed, got %v", err)
	}
	if receipt.Status != "received" || st.MessagesCount() != 1 {
		t.Fatalf("unexpected receipt=%+v count=%d", receipt, st.MessagesCount())
	}
}

func TestUnknownProjectAvoidsUpstreamAndSingleflightCoalesces(t *testing.T) {
	now := time.Date(2026, 11, 12, 12, 0, 0, 0, time.UTC)
	gh := &fakeGitHubClient{
		user: github.User{ID: 1, Login: "hikarilucky79"},
		repos: []github.Repo{
			{ID: 1, Name: "api-go", Language: "Go", HTMLURL: "https://github.com/hikarilucky79/api-go"},
		},
	}
	svc := NewService("hikarilucky79", gh, store.NewMemory(nil), 5*time.Minute, func() time.Time { return now }, slog.New(slog.NewTextHandler(io.Discard, nil)))

	// Unknown repo names should fail via cached repo index without calling GetRepo on GitHub.
	for _, probe := range []string{"missing-1", "missing-2", "missing-1"} {
		if _, err := svc.GetProject(context.Background(), probe); !errors.Is(err, github.ErrNotFound) {
			t.Fatalf("expected ErrNotFound for %s, got %v", probe, err)
		}
	}
	if calls := gh.getRepoCalls.Load(); calls != 0 {
		t.Fatalf("expected 0 GetRepo calls for unknown repos, got %d", calls)
	}

	// Concurrent cold misses should coalesce into a single ListRepos call.
	freshGH := &fakeGitHubClient{
		user:  github.User{ID: 1, Login: "hikarilucky79"},
		repos: []github.Repo{{ID: 1, Name: "api-go"}},
	}
	freshSvc := NewService("hikarilucky79", freshGH, store.NewMemory(nil), 5*time.Minute, func() time.Time { return now }, slog.New(slog.NewTextHandler(io.Discard, nil)))

	var wg sync.WaitGroup
	for i := 0; i < 10; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if _, err := freshSvc.ListProjects(context.Background()); err != nil {
				t.Errorf("concurrent ListProjects failed: %v", err)
			}
		}()
	}
	wg.Wait()
	if calls := freshGH.listCalls.Load(); calls != 1 {
		t.Fatalf("expected 1 coalesced ListRepos call, got %d", calls)
	}
}

func TestServiceFiltersProfileRepoAndEnrichesSignificantLanguages(t *testing.T) {
	now := time.Date(2026, 11, 18, 12, 0, 0, 0, time.UTC)
	gh := &fakeGitHubClient{
		user: github.User{ID: 1, Login: "hikarilucky79"},
		repos: []github.Repo{
			{ID: 10, Name: "hikarilucky79", Description: "Profile README", HTMLURL: "https://github.com/hikarilucky79/hikarilucky79"},
			{ID: 11, Name: "KaorCount", Language: "JavaScript", StargazersCount: 2, HTMLURL: "https://github.com/hikarilucky79/KaorCount"},
			{ID: 12, Name: "keyra", Language: "Dart", StargazersCount: 1, HTMLURL: "https://github.com/hikarilucky79/keyra"},
		},
		langs: map[string]map[string]int64{
			"KaorCount": {"JavaScript": 487986, "Python": 348360, "Shell": 4972},
			"keyra":     {"Dart": 193423, "Rust": 158545, "C": 1939},
		},
	}
	svc := NewService("hikarilucky79", gh, store.NewMemory(nil), 5*time.Minute, func() time.Time { return now }, slog.New(slog.NewTextHandler(io.Discard, nil)))

	list, err := svc.ListProjects(context.Background())
	if err != nil {
		t.Fatalf("unexpected ListProjects error: %v", err)
	}
	if len(list.Projects) != 2 {
		t.Fatalf("expected profile repo filtered out leaving 2 projects, got %d (%+v)", len(list.Projects), list.Projects)
	}
	if list.Projects[0].Name != "KaorCount" || len(list.Projects[0].Languages) != 2 || list.Projects[0].Languages[0] != "JavaScript" || list.Projects[0].Languages[1] != "Python" {
		t.Fatalf("unexpected KaorCount languages: %+v", list.Projects[0].Languages)
	}
	if list.Projects[1].Name != "keyra" || len(list.Projects[1].Languages) != 2 || list.Projects[1].Languages[0] != "Dart" || list.Projects[1].Languages[1] != "Rust" {
		t.Fatalf("unexpected keyra languages: %+v", list.Projects[1].Languages)
	}

	if _, err := svc.GetProject(context.Background(), "hikarilucky79"); !errors.Is(err, github.ErrNotFound) {
		t.Fatalf("expected ErrNotFound for filtered profile repo, got %v", err)
	}

	stats, err := svc.GetStats(context.Background())
	if err != nil {
		t.Fatalf("unexpected GetStats error: %v", err)
	}
	if stats.TotalProjects != 2 || stats.TotalStars != 3 || len(stats.Languages) != 4 {
		t.Fatalf("unexpected stats after filtering & multi-lang enrichment: %+v", stats)
	}
}
