package github

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"time"
)

var (
	ErrNotFound    = errors.New("github resource not found")
	ErrRateLimited = errors.New("github api rate limit exceeded")
)

type User struct {
	ID        int64  `json:"id"`
	Login     string `json:"login"`
	Name      string `json:"name"`
	Bio       string `json:"bio"`
	AvatarURL string `json:"avatar_url"`
	HTMLURL   string `json:"html_url"`
	Blog      string `json:"blog"`
}

type Repo struct {
	ID              int64      `json:"id"`
	Name            string     `json:"name"`
	Description     string     `json:"description"`
	HTMLURL         string     `json:"html_url"`
	Homepage        string     `json:"homepage"`
	DefaultBranch   string     `json:"default_branch"`
	Language        string     `json:"language"`
	StargazersCount int        `json:"stargazers_count"`
	ForksCount      int        `json:"forks_count"`
	Fork            bool       `json:"fork"`
	PushedAt        *time.Time `json:"pushed_at"`
	UpdatedAt       time.Time  `json:"updated_at"`
}

type Commit struct {
	SHA     string
	Message string
	Author  string
	Date    time.Time
}

type PublicEvent struct {
	ID          string
	Type        string
	RepoID      int64
	RepoName    string
	CreatedAt   time.Time
	HeadSHA     string
	CommitCount int
}

type Client interface {
	GetUser(ctx context.Context, username string) (User, error)
	ListRepos(ctx context.Context, username string) ([]Repo, error)
	GetRepo(ctx context.Context, username, name string) (Repo, error)
	GetRepoLanguages(ctx context.Context, username, name string) (map[string]int64, error)
	GetLatestCommit(ctx context.Context, username, name string) (*Commit, error)
	ListPublicEvents(ctx context.Context, username string) ([]PublicEvent, error)
}

type HTTPClient struct {
	baseURL    string
	token      string
	httpClient *http.Client
}

func NewHTTPClient(baseURL, token string, httpClient *http.Client) *HTTPClient {
	if baseURL == "" {
		baseURL = "https://api.github.com"
	}
	if httpClient == nil {
		httpClient = &http.Client{Timeout: 10 * time.Second}
	}
	return &HTTPClient{
		baseURL:    baseURL,
		token:      token,
		httpClient: httpClient,
	}
}

func (c *HTTPClient) GetUser(ctx context.Context, username string) (User, error) {
	var user User
	endpoint := fmt.Sprintf("%s/users/%s", c.baseURL, url.PathEscape(username))
	if err := c.getJSON(ctx, endpoint, &user); err != nil {
		return User{}, err
	}
	return user, nil
}

func (c *HTTPClient) ListRepos(ctx context.Context, username string) ([]Repo, error) {
	var repos []Repo
	endpoint := fmt.Sprintf("%s/users/%s/repos?per_page=100&sort=pushed", c.baseURL, url.PathEscape(username))
	if err := c.getJSON(ctx, endpoint, &repos); err != nil {
		return nil, err
	}
	return repos, nil
}

func (c *HTTPClient) GetRepo(ctx context.Context, username, name string) (Repo, error) {
	var repo Repo
	endpoint := fmt.Sprintf("%s/repos/%s/%s", c.baseURL, url.PathEscape(username), url.PathEscape(name))
	if err := c.getJSON(ctx, endpoint, &repo); err != nil {
		return Repo{}, err
	}
	return repo, nil
}

func (c *HTTPClient) GetRepoLanguages(ctx context.Context, username, name string) (map[string]int64, error) {
	langs := make(map[string]int64)
	endpoint := fmt.Sprintf("%s/repos/%s/%s/languages", c.baseURL, url.PathEscape(username), url.PathEscape(name))
	if err := c.getJSON(ctx, endpoint, &langs); err != nil {
		return nil, err
	}
	return langs, nil
}

func (c *HTTPClient) GetLatestCommit(ctx context.Context, username, name string) (*Commit, error) {
	type apiCommit struct {
		SHA    string `json:"sha"`
		Commit struct {
			Message string `json:"message"`
			Author  struct {
				Name string    `json:"name"`
				Date time.Time `json:"date"`
			} `json:"author"`
		} `json:"commit"`
	}
	var commits []apiCommit
	endpoint := fmt.Sprintf("%s/repos/%s/%s/commits?per_page=1", c.baseURL, url.PathEscape(username), url.PathEscape(name))
	err := c.getJSON(ctx, endpoint, &commits)
	if err != nil {
		// Empty GitHub repos return 409 Conflict for /commits.
		if errors.Is(err, errEmptyRepository) {
			return nil, nil
		}
		return nil, err
	}
	if len(commits) == 0 {
		return nil, nil
	}
	return &Commit{
		SHA:     commits[0].SHA,
		Message: commits[0].Commit.Message,
		Author:  commits[0].Commit.Author.Name,
		Date:    commits[0].Commit.Author.Date,
	}, nil
}

func (c *HTTPClient) ListPublicEvents(ctx context.Context, username string) ([]PublicEvent, error) {
	type apiEvent struct {
		ID        string    `json:"id"`
		Type      string    `json:"type"`
		CreatedAt time.Time `json:"created_at"`
		Repo      struct {
			ID   int64  `json:"id"`
			Name string `json:"name"`
		} `json:"repo"`
		Payload struct {
			Size    int    `json:"size"`
			Head    string `json:"head"`
			Commits []struct {
				SHA string `json:"sha"`
			} `json:"commits"`
		} `json:"payload"`
	}

	var raw []apiEvent
	endpoint := fmt.Sprintf("%s/users/%s/events/public?per_page=100", c.baseURL, url.PathEscape(username))
	if err := c.getJSON(ctx, endpoint, &raw); err != nil {
		return nil, err
	}

	events := make([]PublicEvent, 0, len(raw))
	for _, ev := range raw {
		count := ev.Payload.Size
		if count <= 0 {
			count = len(ev.Payload.Commits)
		}
		// Current GitHub PushEvent payloads may omit size/commits and only send head SHA.
		if count <= 0 && ev.Type == "PushEvent" && ev.Payload.Head != "" {
			count = 1
		}
		events = append(events, PublicEvent{
			ID:          ev.ID,
			Type:        ev.Type,
			RepoID:      ev.Repo.ID,
			RepoName:    ev.Repo.Name,
			CreatedAt:   ev.CreatedAt,
			HeadSHA:     ev.Payload.Head,
			CommitCount: count,
		})
	}
	return events, nil
}

var errEmptyRepository = errors.New("empty repository")

func (c *HTTPClient) getJSON(ctx context.Context, endpoint string, target any) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return err
	}
	req.Header.Set("Accept", "application/vnd.github+json")
	req.Header.Set("User-Agent", "prodifolio-api")
	req.Header.Set("X-GitHub-Api-Version", "2022-11-28")
	if c.token != "" {
		req.Header.Set("Authorization", "Bearer "+c.token)
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusNotFound {
		return ErrNotFound
	}
	if resp.StatusCode == http.StatusConflict {
		return errEmptyRepository
	}
	if resp.StatusCode == http.StatusTooManyRequests ||
		(resp.StatusCode == http.StatusForbidden && resp.Header.Get("X-RateLimit-Remaining") == "0") {
		return ErrRateLimited
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 512))
		return fmt.Errorf("github status %d: %s", resp.StatusCode, string(body))
	}

	return json.NewDecoder(io.LimitReader(resp.Body, 4<<20)).Decode(target)
}
