package portfolio

import (
	"context"
	"errors"
	"log/slog"
	"math"
	"net/mail"
	"regexp"
	"sort"
	"strings"
	"sync"
	"time"
	"unicode/utf8"

	"golang.org/x/sync/singleflight"

	"github.com/hikarilucky79/prodifolio/backend/internal/cache"
	"github.com/hikarilucky79/prodifolio/backend/internal/github"
	"github.com/hikarilucky79/prodifolio/backend/internal/store"
)

var (
	ErrInvalidRepoName = errors.New("invalid repository name")
	repoNamePattern    = regexp.MustCompile(`^[A-Za-z0-9._-]{1,100}$`)
)

type ValidationError struct {
	Message string
	Fields  map[string]string
}

func (e *ValidationError) Error() string {
	return e.Message
}

type Owner struct {
	Username   string `json:"username"`
	Name       string `json:"name"`
	Bio        string `json:"bio"`
	AvatarURL  string `json:"avatar_url"`
	ProfileURL string `json:"profile_url"`
	BlogURL    string `json:"blog_url"`
}

type ProjectSummary struct {
	Name        string     `json:"name"`
	Description string     `json:"description"`
	Languages   []string   `json:"languages"`
	Stars       int        `json:"stars"`
	LastCommit  *time.Time `json:"last_commit,omitempty"`
	URL         string     `json:"url"`
}

type ProjectsResponse struct {
	Owner    Owner            `json:"owner"`
	Projects []ProjectSummary `json:"projects"`
	Cached   bool             `json:"cached"`
}

type ProjectDetail struct {
	Name              string           `json:"name"`
	Description       string           `json:"description"`
	Languages         []string         `json:"languages"`
	LanguageBytes     map[string]int64 `json:"language_bytes"`
	Stars             int              `json:"stars"`
	Forks             int              `json:"forks"`
	DefaultBranch     string           `json:"default_branch"`
	LastCommit        *time.Time       `json:"last_commit,omitempty"`
	LastCommitMessage string           `json:"last_commit_message,omitempty"`
	LastCommitSHA     string           `json:"last_commit_sha,omitempty"`
	URL               string           `json:"url"`
	Homepage          string           `json:"homepage,omitempty"`
}

type LanguageStat struct {
	Name       string  `json:"name"`
	Count      int     `json:"count"`
	Percentage float64 `json:"percentage"`
}

type ActivityPoint struct {
	Date    string `json:"date"`
	Commits int    `json:"commits"`
}

type StatsResponse struct {
	TotalProjects int             `json:"total_projects"`
	TotalStars    int             `json:"total_stars"`
	Languages     []LanguageStat  `json:"languages"`
	Activity      []ActivityPoint `json:"activity"`
	Cached        bool            `json:"cached"`
}

type ContactRequest struct {
	Name    string `json:"name"`
	Email   string `json:"email"`
	Message string `json:"message"`
}

type cachedProjects struct {
	owner     github.User
	repos     []github.Repo
	langBytes map[int64]map[string]int64
}

type Service struct {
	username      string
	gh            github.Client
	store         store.Store
	logger        *slog.Logger
	now           func() time.Time
	projectsCache *cache.Cache[cachedProjects]
	detailCache   *cache.Cache[ProjectDetail]
	notFoundCache *cache.Cache[struct{}]
	eventsCache   *cache.Cache[[]github.PublicEvent]
	projectsGroup singleflight.Group
	detailGroup   singleflight.Group
	eventsGroup   singleflight.Group
}

func NewService(
	username string,
	gh github.Client,
	st store.Store,
	ttl time.Duration,
	now func() time.Time,
	logger *slog.Logger,
) *Service {
	if now == nil {
		now = time.Now
	}
	if logger == nil {
		logger = slog.Default()
	}
	notFoundTTL := ttl
	if notFoundTTL <= 0 || notFoundTTL > 5*time.Minute {
		notFoundTTL = 5 * time.Minute
	}
	return &Service{
		username:      username,
		gh:            gh,
		store:         st,
		logger:        logger,
		now:           now,
		projectsCache: cache.New[cachedProjects](ttl, now),
		detailCache:   cache.New[ProjectDetail](ttl, now),
		notFoundCache: cache.New[struct{}](notFoundTTL, now),
		eventsCache:   cache.New[[]github.PublicEvent](ttl, now),
	}
}

func (s *Service) ListProjects(ctx context.Context) (ProjectsResponse, error) {
	data, cached, err := s.loadProjects(ctx)
	if err != nil {
		return ProjectsResponse{}, err
	}

	items := make([]ProjectSummary, 0, len(data.repos))
	for _, repo := range data.repos {
		langs := significantLanguages(data.langBytes[repo.ID], repo.Language)
		items = append(items, ProjectSummary{
			Name:        repo.Name,
			Description: repo.Description,
			Languages:   langs,
			Stars:       repo.StargazersCount,
			LastCommit:  repo.PushedAt,
			URL:         repo.HTMLURL,
		})
	}

	displayName := data.owner.Name
	if displayName == "" {
		displayName = data.owner.Login
	}
	if displayName == "" {
		displayName = s.username
	}
	profileURL := data.owner.HTMLURL
	if profileURL == "" {
		profileURL = "https://github.com/" + s.username
	}

	return ProjectsResponse{
		Owner: Owner{
			Username:   s.username,
			Name:       displayName,
			Bio:        data.owner.Bio,
			AvatarURL:  data.owner.AvatarURL,
			ProfileURL: profileURL,
			BlogURL:    data.owner.Blog,
		},
		Projects: items,
		Cached:   cached,
	}, nil
}

func (s *Service) GetProject(ctx context.Context, name string) (ProjectDetail, error) {
	name = strings.TrimSpace(name)
	if name == "." || name == ".." || !repoNamePattern.MatchString(name) {
		return ProjectDetail{}, ErrInvalidRepoName
	}

	cacheKey := strings.ToLower(name)
	if detail, ok := s.detailCache.Get(cacheKey); ok {
		return detail, nil
	}
	if _, missed := s.notFoundCache.Get(cacheKey); missed {
		return ProjectDetail{}, github.ErrNotFound
	}

	val, err, _ := s.detailGroup.Do(cacheKey, func() (any, error) {
		if detail, ok := s.detailCache.Get(cacheKey); ok {
			return detail, nil
		}
		if _, missed := s.notFoundCache.Get(cacheKey); missed {
			return ProjectDetail{}, github.ErrNotFound
		}

		fetchCtx, cancel := context.WithTimeout(context.WithoutCancel(ctx), 15*time.Second)
		defer cancel()

		canonicalName := name
		if projectsData, _, projErr := s.loadProjects(fetchCtx); projErr == nil {
			matched := false
			for _, candidate := range projectsData.repos {
				if strings.EqualFold(candidate.Name, name) {
					canonicalName = candidate.Name
					matched = true
					break
				}
			}
			// ListRepos requests per_page=100; if fewer than 100 repos exist and none match, avoid upstream 404 quota drain.
			if !matched && len(projectsData.repos) < 100 {
				s.notFoundCache.Set(cacheKey, struct{}{})
				return ProjectDetail{}, github.ErrNotFound
			}
		}

		repo, err := s.gh.GetRepo(fetchCtx, s.username, canonicalName)
		if err != nil {
			if errors.Is(err, github.ErrNotFound) {
				s.notFoundCache.Set(cacheKey, struct{}{})
				return ProjectDetail{}, err
			}
			if stale, ok := s.detailCache.GetStale(cacheKey); ok {
				s.logger.Warn("serving stale project detail after github error", "repo", canonicalName, "error", err)
				return stale, nil
			}
			return ProjectDetail{}, err
		}

		langBytes, err := s.gh.GetRepoLanguages(fetchCtx, s.username, repo.Name)
		if err != nil {
			s.logger.Warn("failed to load repo languages", "repo", repo.Name, "error", err)
			langBytes = map[string]int64{}
		}

		latestCommit, err := s.gh.GetLatestCommit(fetchCtx, s.username, repo.Name)
		if err != nil {
			s.logger.Warn("failed to load latest commit", "repo", repo.Name, "error", err)
		}

		langs := sortLanguagesByBytes(langBytes, repo.Language)
		lastCommitTime := repo.PushedAt
		var commitMsg, commitSHA string
		if latestCommit != nil {
			commitMsg = firstLine(latestCommit.Message)
			commitSHA = latestCommit.SHA
			if !latestCommit.Date.IsZero() {
				t := latestCommit.Date.UTC()
				lastCommitTime = &t
			}
		}

		branch := repo.DefaultBranch
		if branch == "" {
			branch = "main"
		}

		detail := ProjectDetail{
			Name:              repo.Name,
			Description:       repo.Description,
			Languages:         langs,
			LanguageBytes:     langBytes,
			Stars:             repo.StargazersCount,
			Forks:             repo.ForksCount,
			DefaultBranch:     branch,
			LastCommit:        lastCommitTime,
			LastCommitMessage: commitMsg,
			LastCommitSHA:     commitSHA,
			URL:               repo.HTMLURL,
			Homepage:          repo.Homepage,
		}

		s.notFoundCache.Delete(cacheKey)
		s.detailCache.Set(cacheKey, detail)
		if s.store != nil && repo.ID > 0 && len(langBytes) > 0 {
			syncCtx, syncCancel := context.WithTimeout(fetchCtx, 3*time.Second)
			err := s.store.SyncPortfolio(syncCtx, store.PortfolioSnapshot{
				Owner: github.User{
					ID:      0, // detail sync only adds language bytes when owner already exists
					Login:   s.username,
					HTMLURL: "https://github.com/" + s.username,
				},
				Repos:     []github.Repo{repo},
				Languages: map[int64]map[string]int64{repo.ID: langBytes},
			})
			syncCancel()
			if err != nil {
				s.logger.Warn("failed to persist repo detail snapshot", "repo", repo.Name, "error", err)
			}
		}
		return detail, nil
	})
	if err != nil {
		return ProjectDetail{}, err
	}
	return val.(ProjectDetail), nil
}

func (s *Service) GetStats(ctx context.Context) (StatsResponse, error) {
	projectsData, projectsCached, err := s.loadProjects(ctx)
	if err != nil {
		return StatsResponse{}, err
	}
	events, eventsCached, err := s.loadEvents(ctx)
	if err != nil {
		// Keep stats available with empty activity if only /events fails.
		s.logger.Warn("failed to load github events for stats", "error", err)
		events = nil
	}

	totalStars := 0
	langCounts := make(map[string]int)
	totalLangTags := 0
	for _, repo := range projectsData.repos {
		totalStars += repo.StargazersCount
		for _, lang := range significantLanguages(projectsData.langBytes[repo.ID], repo.Language) {
			langCounts[lang]++
			totalLangTags++
		}
	}

	languages := make([]LanguageStat, 0, len(langCounts))
	for name, count := range langCounts {
		pct := 0.0
		if totalLangTags > 0 {
			pct = math.Round((float64(count)/float64(totalLangTags))*1000) / 10
		}
		languages = append(languages, LanguageStat{
			Name:       name,
			Count:      count,
			Percentage: pct,
		})
	}
	sort.Slice(languages, func(i, j int) bool {
		if languages[i].Count != languages[j].Count {
			return languages[i].Count > languages[j].Count
		}
		return languages[i].Name < languages[j].Name
	})

	const days = 14
	today := s.now().UTC()
	startDay := time.Date(today.Year(), today.Month(), today.Day(), 0, 0, 0, 0, time.UTC).AddDate(0, 0, -(days - 1))
	daily := make(map[string]int, days)
	for _, ev := range events {
		if ev.Type != "PushEvent" || ev.CommitCount <= 0 {
			continue
		}
		dayKey := ev.CreatedAt.UTC().Format("2006-01-02")
		daily[dayKey] += ev.CommitCount
	}

	activity := make([]ActivityPoint, 0, days)
	for i := 0; i < days; i++ {
		dayKey := startDay.AddDate(0, 0, i).Format("2006-01-02")
		activity = append(activity, ActivityPoint{
			Date:    dayKey,
			Commits: daily[dayKey],
		})
	}

	return StatsResponse{
		TotalProjects: len(projectsData.repos),
		TotalStars:    totalStars,
		Languages:     languages,
		Activity:      activity,
		Cached:        projectsCached && eventsCached,
	}, nil
}

func (s *Service) SubmitContact(ctx context.Context, req ContactRequest, clientIP string) (store.ContactReceipt, error) {
	name := strings.TrimSpace(req.Name)
	email := strings.ToLower(strings.TrimSpace(req.Email))
	message := strings.TrimSpace(req.Message)

	fields := make(map[string]string)
	if nLen := utf8.RuneCountInString(name); nLen < 2 || nLen > 100 {
		fields["name"] = "must be between 2 and 100 characters"
	}
	if !isValidEmail(email) {
		fields["email"] = "must be a valid email address"
	}
	if mLen := utf8.RuneCountInString(message); mLen < 10 || mLen > 2000 {
		fields["message"] = "must be between 10 and 2000 characters"
	}

	if len(fields) > 0 {
		return store.ContactReceipt{}, &ValidationError{
			Message: "invalid contact input",
			Fields:  fields,
		}
	}

	return s.store.SaveContact(ctx, store.ContactInput{
		Name:     name,
		Email:    email,
		Message:  message,
		ClientIP: clientIP,
	})
}

func (s *Service) loadProjects(ctx context.Context) (cachedProjects, bool, error) {
	if cached, ok := s.projectsCache.Get("projects"); ok {
		return cached, true, nil
	}

	type projectsResult struct {
		data   cachedProjects
		cached bool
	}

	val, err, _ := s.projectsGroup.Do("projects", func() (any, error) {
		if cached, ok := s.projectsCache.Get("projects"); ok {
			return projectsResult{data: cached, cached: true}, nil
		}

		fetchCtx, cancel := context.WithTimeout(context.WithoutCancel(ctx), 15*time.Second)
		defer cancel()

		rawRepos, err := s.gh.ListRepos(fetchCtx, s.username)
		if err != nil {
			if stale, ok := s.projectsCache.GetStale("projects"); ok {
				s.logger.Warn("serving stale projects after github error", "error", err)
				return projectsResult{data: stale, cached: true}, nil
			}
			return projectsResult{}, err
		}

		repos := make([]github.Repo, 0, len(rawRepos))
		for _, r := range rawRepos {
			if strings.EqualFold(strings.TrimSpace(r.Name), strings.TrimSpace(s.username)) {
				continue
			}
			repos = append(repos, r)
		}

		langBytes := make(map[int64]map[string]int64, len(repos))
		maxLangRepos := len(repos)
		if maxLangRepos > 12 {
			maxLangRepos = 12
		}
		var (
			wg sync.WaitGroup
			mu sync.Mutex
		)
		for _, repo := range repos[:maxLangRepos] {
			r := repo
			wg.Add(1)
			go func() {
				defer wg.Done()
				lb, langErr := s.gh.GetRepoLanguages(fetchCtx, s.username, r.Name)
				if langErr != nil {
					s.logger.Warn("failed to load repo languages during list", "repo", r.Name, "error", langErr)
					return
				}
				if len(lb) > 0 && r.ID > 0 {
					mu.Lock()
					langBytes[r.ID] = lb
					mu.Unlock()
				}
			}()
		}
		wg.Wait()

		user, err := s.gh.GetUser(fetchCtx, s.username)
		if err != nil {
			s.logger.Warn("failed to load github user profile", "error", err)
			user = github.User{Login: s.username, HTMLURL: "https://github.com/" + s.username}
		}

		data := cachedProjects{owner: user, repos: repos, langBytes: langBytes}
		s.projectsCache.Set("projects", data)

		if s.store != nil {
			syncCtx, syncCancel := context.WithTimeout(fetchCtx, 3*time.Second)
			err := s.store.SyncPortfolio(syncCtx, store.PortfolioSnapshot{
				Owner:     user,
				Repos:     repos,
				Languages: langBytes,
			})
			syncCancel()
			if err != nil {
				s.logger.Warn("failed to persist portfolio snapshot", "error", err)
			}
		}

		return projectsResult{data: data, cached: false}, nil
	})
	if err != nil {
		return cachedProjects{}, false, err
	}
	res := val.(projectsResult)
	return res.data, res.cached, nil
}

func (s *Service) loadEvents(ctx context.Context) ([]github.PublicEvent, bool, error) {
	if cached, ok := s.eventsCache.Get("events"); ok {
		return cached, true, nil
	}

	type eventsResult struct {
		events []github.PublicEvent
		cached bool
	}

	val, err, _ := s.eventsGroup.Do("events", func() (any, error) {
		if cached, ok := s.eventsCache.Get("events"); ok {
			return eventsResult{events: cached, cached: true}, nil
		}

		fetchCtx, cancel := context.WithTimeout(context.WithoutCancel(ctx), 15*time.Second)
		defer cancel()

		events, err := s.gh.ListPublicEvents(fetchCtx, s.username)
		if err != nil {
			if stale, ok := s.eventsCache.GetStale("events"); ok {
				return eventsResult{events: stale, cached: true}, nil
			}
			return eventsResult{}, err
		}
		s.eventsCache.Set("events", events)

		if s.store != nil {
			if proj, ok := s.projectsCache.GetStale("projects"); ok {
				syncCtx, syncCancel := context.WithTimeout(fetchCtx, 3*time.Second)
				err := s.store.SyncPortfolio(syncCtx, store.PortfolioSnapshot{
					Owner:  proj.owner,
					Repos:  proj.repos,
					Events: events,
				})
				syncCancel()
				if err != nil {
					s.logger.Warn("failed to persist commit activity snapshot", "error", err)
				}
			}
		}

		return eventsResult{events: events, cached: false}, nil
	})
	if err != nil {
		return nil, false, err
	}
	res := val.(eventsResult)
	return res.events, res.cached, nil
}

func significantLanguages(langBytes map[string]int64, primary string) []string {
	if len(langBytes) == 0 {
		if primary == "" {
			return []string{}
		}
		return []string{primary}
	}
	type pair struct {
		name  string
		bytes int64
	}
	var total int64
	pairs := make([]pair, 0, len(langBytes))
	for k, v := range langBytes {
		if v <= 0 {
			continue
		}
		total += v
		pairs = append(pairs, pair{name: k, bytes: v})
	}
	sort.Slice(pairs, func(i, j int) bool {
		if pairs[i].bytes != pairs[j].bytes {
			return pairs[i].bytes > pairs[j].bytes
		}
		return pairs[i].name < pairs[j].name
	})
	out := make([]string, 0, len(pairs))
	for _, p := range pairs {
		if total > 0 && p.bytes*100 >= total*15 {
			out = append(out, p.name)
		}
	}
	if len(out) == 0 && primary != "" {
		return []string{primary}
	}
	return out
}

func sortLanguagesByBytes(langBytes map[string]int64, primary string) []string {
	if len(langBytes) == 0 {
		if primary == "" {
			return []string{}
		}
		return []string{primary}
	}
	type pair struct {
		name  string
		bytes int64
	}
	pairs := make([]pair, 0, len(langBytes))
	for k, v := range langBytes {
		pairs = append(pairs, pair{name: k, bytes: v})
	}
	sort.Slice(pairs, func(i, j int) bool {
		if pairs[i].bytes != pairs[j].bytes {
			return pairs[i].bytes > pairs[j].bytes
		}
		return pairs[i].name < pairs[j].name
	})
	out := make([]string, 0, len(pairs))
	for _, p := range pairs {
		out = append(out, p.name)
	}
	return out
}

func firstLine(s string) string {
	s = strings.TrimSpace(s)
	if idx := strings.IndexAny(s, "\r\n"); idx >= 0 {
		return s[:idx]
	}
	return s
}

func isValidEmail(email string) bool {
	if email == "" || len(email) > 254 || strings.ContainsAny(email, " \t\r\n") {
		return false
	}
	addr, err := mail.ParseAddress(email)
	if err != nil || addr.Address != email {
		return false
	}
	at := strings.LastIndexByte(email, '@')
	if at <= 0 || at == len(email)-1 {
		return false
	}
	domain := email[at+1:]
	return strings.Contains(domain, ".") && !strings.HasPrefix(domain, ".") && !strings.HasSuffix(domain, ".")
}
