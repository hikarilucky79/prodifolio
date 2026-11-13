package store

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net"
	"net/http"
	"net/netip"
	"net/url"
	"sort"
	"strings"
	"sync/atomic"
	"time"
)

const maxRestErrorBytes = 16 * 1024

// SupabaseRestStore persists portfolio and contact data via Supabase's HTTPS Data API (PostgREST).
type SupabaseRestStore struct {
	baseURL               string
	secretKey             string
	httpClient            *http.Client
	logger                *slog.Logger
	warnedMissingCol      atomic.Bool
	warnedMissingRateFunc atomic.Bool
}

type postgrestError struct {
	StatusCode int
	Code       string `json:"code"`
	Message    string `json:"message"`
	Details    string `json:"details"`
	Hint       string `json:"hint"`
}

func (e *postgrestError) Error() string {
	if e.Code != "" && e.Message != "" {
		return fmt.Sprintf("supabase rest status %d (%s): %s", e.StatusCode, e.Code, e.Message)
	}
	if e.Message != "" {
		return fmt.Sprintf("supabase rest status %d: %s", e.StatusCode, e.Message)
	}
	return fmt.Sprintf("supabase rest status %d", e.StatusCode)
}

func (e *postgrestError) hasMissingColumn(col string) bool {
	if e.StatusCode != http.StatusBadRequest {
		return false
	}
	return e.Code == "PGRST204" && strings.Contains(e.Message, col)
}

func (e *postgrestError) hasMissingFunction() bool {
	return e.StatusCode == http.StatusNotFound || e.Code == "PGRST202"
}

// NewSupabaseREST builds a Store backed by Supabase PostgREST using an opaque secret key (sb_secret_...).
func NewSupabaseREST(baseURL, secretKey string, httpClient *http.Client, logger *slog.Logger) (*SupabaseRestStore, error) {
	base := strings.TrimRight(strings.TrimSpace(baseURL), "/")
	key := strings.TrimSpace(secretKey)
	if base == "" {
		return nil, fmt.Errorf("supabase url is empty")
	}
	if key == "" {
		return nil, fmt.Errorf("supabase secret key is empty")
	}
	if httpClient == nil {
		httpClient = &http.Client{Timeout: 10 * time.Second}
	}
	if logger == nil {
		logger = slog.Default()
	}
	return &SupabaseRestStore{
		baseURL:    base,
		secretKey:  key,
		httpClient: httpClient,
		logger:     logger,
	}, nil
}

// SaveContact upserts the sender without overwriting existing names and inserts a new contact message.
func (s *SupabaseRestStore) SaveContact(ctx context.Context, input ContactInput) (ContactReceipt, error) {
	senderID, err := s.ensureContactSender(ctx, input.Email, input.Name)
	if err != nil {
		return ContactReceipt{}, err
	}

	clientIP := normalizeClientIP(input.ClientIP)
	msgPayload := map[string]any{
		"sender_id":   senderID,
		"sender_name": input.Name,
		"message":     input.Message,
		"client_ip":   clientIP,
	}

	row, err := s.insertContactMessage(ctx, msgPayload)
	if err != nil {
		var pgErr *postgrestError
		if errors.As(err, &pgErr) && pgErr.hasMissingColumn("sender_name") {
			if s.warnedMissingCol.CompareAndSwap(false, true) {
				s.logger.Warn("migration 002_security_hardening.sql pending; inserting contact message without sender_name")
			}
			delete(msgPayload, "sender_name")
			row, err = s.insertContactMessage(ctx, msgPayload)
		}
	}
	if err != nil {
		return ContactReceipt{}, fmt.Errorf("insert contact_message: %w", err)
	}

	return ContactReceipt{
		ID:        row.ID,
		Status:    "received",
		CreatedAt: row.CreatedAt.UTC(),
	}, nil
}

func (s *SupabaseRestStore) ensureContactSender(ctx context.Context, email, name string) (string, error) {
	type idRow struct {
		ID string `json:"id"`
	}

	q := url.Values{}
	q.Set("on_conflict", "email")
	q.Set("select", "id")

	var rows []idRow
	headers := map[string]string{
		"Prefer": "resolution=ignore-duplicates,return=representation",
	}
	payload := []map[string]string{{"email": email, "name": name}}
	if err := s.doJSON(ctx, http.MethodPost, "/rest/v1/contact_senders", q, headers, payload, &rows); err != nil {
		return "", fmt.Errorf("insert contact_sender: %w", err)
	}
	if len(rows) > 0 && rows[0].ID != "" {
		return rows[0].ID, nil
	}

	lookupQ := url.Values{}
	lookupQ.Set("email", "eq."+email)
	lookupQ.Set("select", "id")
	lookupQ.Set("limit", "1")
	if err := s.doJSON(ctx, http.MethodGet, "/rest/v1/contact_senders", lookupQ, nil, nil, &rows); err != nil {
		return "", fmt.Errorf("lookup contact_sender: %w", err)
	}
	if len(rows) == 0 || rows[0].ID == "" {
		return "", fmt.Errorf("lookup contact_sender: no row returned")
	}
	return rows[0].ID, nil
}

type contactMessageRow struct {
	ID        string    `json:"id"`
	CreatedAt time.Time `json:"created_at"`
}

func (s *SupabaseRestStore) insertContactMessage(ctx context.Context, payload map[string]any) (contactMessageRow, error) {
	q := url.Values{}
	q.Set("select", "id,created_at")

	var rows []contactMessageRow
	headers := map[string]string{
		"Prefer": "return=representation",
	}
	if err := s.doJSON(ctx, http.MethodPost, "/rest/v1/contact_messages", q, headers, []map[string]any{payload}, &rows); err != nil {
		return contactMessageRow{}, err
	}
	if len(rows) == 0 {
		return contactMessageRow{}, fmt.Errorf("empty representation returned")
	}
	return rows[0], nil
}

// SyncPortfolio upserts owner, languages, repositories, repository_languages, and commit_activities via PostgREST.
func (s *SupabaseRestStore) SyncPortfolio(ctx context.Context, snapshot PortfolioSnapshot) error {
	nowUTC := time.Now().UTC()

	ownerID, ok, err := s.syncOwner(ctx, snapshot, nowUTC)
	if err != nil {
		return err
	}
	if !ok {
		return nil
	}

	langIDs, err := s.ensureLanguages(ctx, collectLanguageNames(snapshot))
	if err != nil {
		return err
	}

	repoIDByFullName, err := s.syncRepositories(ctx, snapshot, ownerID, langIDs, nowUTC)
	if err != nil {
		return err
	}

	if err := s.syncRepositoryLanguages(ctx, snapshot, langIDs); err != nil {
		return err
	}

	return s.syncCommitActivities(ctx, snapshot, repoIDByFullName)
}

func (s *SupabaseRestStore) syncOwner(ctx context.Context, snapshot PortfolioSnapshot, nowUTC time.Time) (int64, bool, error) {
	if snapshot.Owner.ID == 0 {
		if strings.TrimSpace(snapshot.Owner.Login) == "" {
			return 0, false, nil
		}
		type ownerRow struct {
			ID int64 `json:"id"`
		}
		q := url.Values{}
		q.Set("github_username", "eq."+snapshot.Owner.Login)
		q.Set("select", "id")
		q.Set("limit", "1")
		var rows []ownerRow
		if err := s.doJSON(ctx, http.MethodGet, "/rest/v1/owners", q, nil, nil, &rows); err != nil {
			return 0, false, fmt.Errorf("lookup owner: %w", err)
		}
		if len(rows) == 0 {
			return 0, false, nil
		}
		return rows[0].ID, true, nil
	}

	q := url.Values{}
	q.Set("on_conflict", "id")
	headers := map[string]string{
		"Prefer": "resolution=merge-duplicates,return=minimal",
	}
	payload := []map[string]any{{
		"id":              snapshot.Owner.ID,
		"github_username": snapshot.Owner.Login,
		"display_name":    snapshot.Owner.Name,
		"bio":             snapshot.Owner.Bio,
		"avatar_url":      snapshot.Owner.AvatarURL,
		"profile_url":     snapshot.Owner.HTMLURL,
		"blog_url":        snapshot.Owner.Blog,
		"synced_at":       nowUTC,
	}}
	if err := s.doJSON(ctx, http.MethodPost, "/rest/v1/owners", q, headers, payload, nil); err != nil {
		return 0, false, fmt.Errorf("upsert owner: %w", err)
	}
	return snapshot.Owner.ID, true, nil
}

func collectLanguageNames(snapshot PortfolioSnapshot) []string {
	seen := make(map[string]struct{})
	for _, repo := range snapshot.Repos {
		if repo.ID == 0 {
			continue
		}
		if name := strings.TrimSpace(repo.Language); name != "" {
			seen[name] = struct{}{}
		}
		for langName := range snapshot.Languages[repo.ID] {
			if name := strings.TrimSpace(langName); name != "" {
				seen[name] = struct{}{}
			}
		}
	}
	names := make([]string, 0, len(seen))
	for name := range seen {
		names = append(names, name)
	}
	sort.Strings(names)
	return names
}

func (s *SupabaseRestStore) ensureLanguages(ctx context.Context, names []string) (map[string]int64, error) {
	langIDs := make(map[string]int64, len(names))
	if len(names) == 0 {
		return langIDs, nil
	}

	if err := s.fetchLanguagesInto(ctx, langIDs); err != nil {
		return nil, err
	}

	var missing []map[string]string
	for _, name := range names {
		if _, ok := langIDs[name]; !ok {
			missing = append(missing, map[string]string{"name": name})
		}
	}
	if len(missing) == 0 {
		return langIDs, nil
	}

	type langRow struct {
		ID   int64  `json:"id"`
		Name string `json:"name"`
	}
	q := url.Values{}
	q.Set("on_conflict", "name")
	q.Set("select", "id,name")
	headers := map[string]string{
		"Prefer": "resolution=ignore-duplicates,return=representation",
	}
	var inserted []langRow
	if err := s.doJSON(ctx, http.MethodPost, "/rest/v1/languages", q, headers, missing, &inserted); err != nil {
		return nil, fmt.Errorf("insert languages: %w", err)
	}
	for _, row := range inserted {
		langIDs[row.Name] = row.ID
	}

	for _, name := range names {
		if _, ok := langIDs[name]; !ok {
			if err := s.fetchLanguagesInto(ctx, langIDs); err != nil {
				return nil, err
			}
			break
		}
	}
	return langIDs, nil
}

func (s *SupabaseRestStore) fetchLanguagesInto(ctx context.Context, out map[string]int64) error {
	type langRow struct {
		ID   int64  `json:"id"`
		Name string `json:"name"`
	}
	q := url.Values{}
	q.Set("select", "id,name")
	q.Set("limit", "1000")
	var rows []langRow
	if err := s.doJSON(ctx, http.MethodGet, "/rest/v1/languages", q, nil, nil, &rows); err != nil {
		return fmt.Errorf("fetch languages: %w", err)
	}
	for _, row := range rows {
		out[row.Name] = row.ID
	}
	return nil
}

type repoUpsertRow struct {
	ID                int64      `json:"id"`
	OwnerID           int64      `json:"owner_id"`
	Name              string     `json:"name"`
	Description       string     `json:"description"`
	HTMLURL           string     `json:"html_url"`
	HomepageURL       string     `json:"homepage_url"`
	DefaultBranch     string     `json:"default_branch"`
	StarsCount        int        `json:"stars_count"`
	ForksCount        int        `json:"forks_count"`
	PrimaryLanguageID *int64     `json:"primary_language_id"`
	IsFork            bool       `json:"is_fork"`
	LastCommitAt      *time.Time `json:"last_commit_at"`
	SyncedAt          time.Time  `json:"synced_at"`
}

func (s *SupabaseRestStore) syncRepositories(
	ctx context.Context,
	snapshot PortfolioSnapshot,
	ownerID int64,
	langIDs map[string]int64,
	nowUTC time.Time,
) (map[string]int64, error) {
	repoIDByFullName := make(map[string]int64, len(snapshot.Repos))
	rows := make([]repoUpsertRow, 0, len(snapshot.Repos))
	seenIDs := make(map[int64]struct{}, len(snapshot.Repos))

	for _, repo := range snapshot.Repos {
		if repo.ID == 0 {
			continue
		}
		repoIDByFullName[strings.ToLower(snapshot.Owner.Login+"/"+repo.Name)] = repo.ID
		if _, dup := seenIDs[repo.ID]; dup {
			continue
		}
		seenIDs[repo.ID] = struct{}{}

		branch := repo.DefaultBranch
		if branch == "" {
			branch = "main"
		}
		var primaryLangID *int64
		if name := strings.TrimSpace(repo.Language); name != "" {
			if id, ok := langIDs[name]; ok {
				idCopy := id
				primaryLangID = &idCopy
			}
		}

		rows = append(rows, repoUpsertRow{
			ID:                repo.ID,
			OwnerID:           ownerID,
			Name:              repo.Name,
			Description:       repo.Description,
			HTMLURL:           repo.HTMLURL,
			HomepageURL:       repo.Homepage,
			DefaultBranch:     branch,
			StarsCount:        repo.StargazersCount,
			ForksCount:        repo.ForksCount,
			PrimaryLanguageID: primaryLangID,
			IsFork:            repo.Fork,
			LastCommitAt:      repo.PushedAt,
			SyncedAt:          nowUTC,
		})
	}

	if len(rows) == 0 {
		return repoIDByFullName, nil
	}

	q := url.Values{}
	q.Set("on_conflict", "id")
	headers := map[string]string{
		"Prefer": "resolution=merge-duplicates,return=minimal",
	}
	if err := s.doJSON(ctx, http.MethodPost, "/rest/v1/repositories", q, headers, rows, nil); err != nil {
		return nil, fmt.Errorf("upsert repositories: %w", err)
	}
	return repoIDByFullName, nil
}

type repoLanguageUpsertRow struct {
	RepositoryID int64 `json:"repository_id"`
	LanguageID   int64 `json:"language_id"`
	BytesCount   int64 `json:"bytes_count"`
}

func (s *SupabaseRestStore) syncRepositoryLanguages(ctx context.Context, snapshot PortfolioSnapshot, langIDs map[string]int64) error {
	type pairKey struct {
		repoID int64
		langID int64
	}
	seen := make(map[pairKey]struct{})
	var rows []repoLanguageUpsertRow

	for _, repo := range snapshot.Repos {
		if repo.ID == 0 {
			continue
		}
		for langName, bytesCount := range snapshot.Languages[repo.ID] {
			langID, ok := langIDs[strings.TrimSpace(langName)]
			if !ok {
				continue
			}
			key := pairKey{repoID: repo.ID, langID: langID}
			if _, dup := seen[key]; dup {
				continue
			}
			seen[key] = struct{}{}
			rows = append(rows, repoLanguageUpsertRow{
				RepositoryID: repo.ID,
				LanguageID:   langID,
				BytesCount:   bytesCount,
			})
		}
	}

	if len(rows) == 0 {
		return nil
	}

	q := url.Values{}
	q.Set("on_conflict", "repository_id,language_id")
	headers := map[string]string{
		"Prefer": "resolution=merge-duplicates,return=minimal",
	}
	if err := s.doJSON(ctx, http.MethodPost, "/rest/v1/repository_languages", q, headers, rows, nil); err != nil {
		return fmt.Errorf("upsert repository_languages: %w", err)
	}
	return nil
}

type commitActivityInsertRow struct {
	RepositoryID int64     `json:"repository_id"`
	CommitSHA    string    `json:"commit_sha"`
	CommitCount  int       `json:"commit_count"`
	CommittedAt  time.Time `json:"committed_at"`
}

func (s *SupabaseRestStore) syncCommitActivities(
	ctx context.Context,
	snapshot PortfolioSnapshot,
	repoIDByFullName map[string]int64,
) error {
	type commitKey struct {
		repoID int64
		sha    string
	}
	seen := make(map[commitKey]struct{})
	var rows []commitActivityInsertRow

	for _, ev := range snapshot.Events {
		if ev.Type != "PushEvent" || ev.HeadSHA == "" || ev.CommitCount <= 0 {
			continue
		}
		repoID, ok := repoIDByFullName[strings.ToLower(ev.RepoName)]
		if !ok {
			continue
		}
		key := commitKey{repoID: repoID, sha: ev.HeadSHA}
		if _, dup := seen[key]; dup {
			continue
		}
		seen[key] = struct{}{}
		rows = append(rows, commitActivityInsertRow{
			RepositoryID: repoID,
			CommitSHA:    ev.HeadSHA,
			CommitCount:  ev.CommitCount,
			CommittedAt:  ev.CreatedAt,
		})
	}

	if len(rows) == 0 {
		return nil
	}

	q := url.Values{}
	q.Set("on_conflict", "repository_id,commit_sha")
	headers := map[string]string{
		"Prefer": "resolution=ignore-duplicates,return=minimal",
	}
	if err := s.doJSON(ctx, http.MethodPost, "/rest/v1/commit_activities", q, headers, rows, nil); err != nil {
		return fmt.Errorf("insert commit_activities: %w", err)
	}
	return nil
}

// AllowRateLimit enforces an atomic sliding-bucket limit via the check_rate_limit SQL RPC.
func (s *SupabaseRestStore) AllowRateLimit(ctx context.Context, key string, limit int, window time.Duration) (bool, time.Duration, error) {
	if limit <= 0 || window <= 0 {
		return true, 0, nil
	}

	type rpcResult struct {
		Allowed        bool    `json:"allowed"`
		RetryAfterSecs float64 `json:"retry_after_secs"`
	}
	var rows []rpcResult
	payload := map[string]any{
		"p_key":         key,
		"p_limit":       limit,
		"p_window_secs": window.Seconds(),
	}
	if err := s.doJSON(ctx, http.MethodPost, "/rest/v1/rpc/check_rate_limit", nil, nil, payload, &rows); err != nil {
		var pgErr *postgrestError
		if errors.As(err, &pgErr) && pgErr.hasMissingFunction() {
			if s.warnedMissingRateFunc.CompareAndSwap(false, true) {
				s.logger.Warn("migration 002_security_hardening.sql pending; check_rate_limit RPC missing, falling back to local rate limiter")
			}
		}
		return false, 0, err
	}
	if len(rows) == 0 {
		return false, 0, fmt.Errorf("check_rate_limit returned empty result")
	}

	if rows[0].Allowed {
		return true, 0, nil
	}
	retryAfter := time.Duration(rows[0].RetryAfterSecs * float64(time.Second))
	if retryAfter < 0 {
		retryAfter = 0
	}
	return false, retryAfter, nil
}

// Ping verifies connectivity and secret key validity against PostgREST.
func (s *SupabaseRestStore) Ping(ctx context.Context) error {
	q := url.Values{}
	q.Set("select", "id")
	q.Set("limit", "1")
	return s.doJSON(ctx, http.MethodGet, "/rest/v1/owners", q, nil, nil, nil)
}

// Close satisfies the Store interface; HTTP clients hold no persistent session to tear down.
func (s *SupabaseRestStore) Close() error {
	return nil
}

// Mode identifies the active persistence backend in health responses and logs.
func (s *SupabaseRestStore) Mode() string {
	return "supabase"
}

func (s *SupabaseRestStore) doJSON(
	ctx context.Context,
	method, path string,
	query url.Values,
	headers map[string]string,
	body any,
	out any,
) error {
	fullURL := s.baseURL + path
	if len(query) > 0 {
		fullURL += "?" + query.Encode()
	}

	var reqBody io.Reader
	if body != nil {
		raw, err := json.Marshal(body)
		if err != nil {
			return fmt.Errorf("marshal request body: %w", err)
		}
		reqBody = bytes.NewReader(raw)
	}

	req, err := http.NewRequestWithContext(ctx, method, fullURL, reqBody)
	if err != nil {
		return fmt.Errorf("build request: %w", err)
	}

	// Opaque sb_secret_* keys must be sent only via apikey (not Bearer JWT) with a non-browser User-Agent.
	req.Header.Set("apikey", s.secretKey)
	req.Header.Set("User-Agent", "prodifolio-api/1.0")
	req.Header.Set("Accept", "application/json")
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	for k, v := range headers {
		req.Header.Set(k, v)
	}

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("execute request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return decodePostgrestError(resp.StatusCode, resp.Body)
	}

	if out == nil {
		_, _ = io.Copy(io.Discard, io.LimitReader(resp.Body, maxRestErrorBytes))
		return nil
	}

	if err := json.NewDecoder(resp.Body).Decode(out); err != nil {
		return fmt.Errorf("decode response: %w", err)
	}
	return nil
}

func decodePostgrestError(statusCode int, body io.Reader) error {
	raw, err := io.ReadAll(io.LimitReader(body, maxRestErrorBytes))
	if err != nil {
		return &postgrestError{StatusCode: statusCode, Message: "failed to read error body"}
	}
	pgErr := &postgrestError{StatusCode: statusCode}
	if json.Unmarshal(raw, pgErr) == nil && (pgErr.Message != "" || pgErr.Code != "") {
		return pgErr
	}
	msg := strings.TrimSpace(string(raw))
	if len(msg) > 256 {
		msg = msg[:256]
	}
	pgErr.Message = msg
	return pgErr
}

func normalizeClientIP(raw string) string {
	trimmed := strings.TrimSpace(raw)
	if addr, err := netip.ParseAddr(trimmed); err == nil {
		return addr.Unmap().String()
	}
	if host, _, err := net.SplitHostPort(trimmed); err == nil {
		if addr, err := netip.ParseAddr(host); err == nil {
			return addr.Unmap().String()
		}
	}
	return "0.0.0.0"
}
