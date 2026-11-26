package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

type Config struct {
	Port               string
	IsProduction       bool
	GitHubUsername     string
	GitHubToken        string
	GitHubBaseURL      string
	CacheTTL           time.Duration
	CORSAllowedOrigins []string
	ContactRateLimit   int
	ContactRateWindow  time.Duration
	TrustProxy         bool
	DBURL              string
	SupabaseURL        string
	SupabaseSecretKey  string
}

func Load() (Config, error) {
	ttl, err := parseDuration("CACHE_TTL", 15*time.Minute)
	if err != nil {
		return Config{}, err
	}
	rateWindow, err := parseDuration("CONTACT_RATE_WINDOW", time.Minute)
	if err != nil {
		return Config{}, err
	}
	rateLimit, err := parsePositiveInt("CONTACT_RATE_LIMIT", 5)
	if err != nil {
		return Config{}, err
	}
	trustProxy, err := parseBool("TRUST_PROXY", false)
	if err != nil {
		return Config{}, err
	}

	dbURL := firstNonEmptyEnv("TIDB_DB_URL", "DATABASE_URL", "SUPABASE_DB_URL")

	supabaseURL := strings.TrimRight(strings.TrimSpace(os.Getenv("SUPABASE_URL")), "/")
	supabaseSecretKey := strings.TrimSpace(os.Getenv("SUPABASE_SECRET_KEY"))
	if supabaseSecretKey == "" {
		supabaseSecretKey = strings.TrimSpace(os.Getenv("SUPABASE_SERVICE_ROLE_KEY"))
	}
	if dbURL == "" && ((supabaseURL == "") != (supabaseSecretKey == "")) {
		return Config{}, fmt.Errorf("SUPABASE_URL and SUPABASE_SECRET_KEY must both be set when using Supabase REST storage")
	}
	if supabaseURL != "" && !strings.HasPrefix(supabaseURL, "http://") && !strings.HasPrefix(supabaseURL, "https://") {
		return Config{}, fmt.Errorf("invalid SUPABASE_URL: must start with http:// or https://")
	}

	isProduction := strings.TrimSpace(os.Getenv("VERCEL")) == "1" ||
		strings.EqualFold(strings.TrimSpace(os.Getenv("VERCEL_ENV")), "production") ||
		strings.EqualFold(strings.TrimSpace(os.Getenv("APP_ENV")), "production")

	return Config{
		Port:               envOr("PORT", "8080"),
		IsProduction:       isProduction,
		GitHubUsername:     envOr("GITHUB_USERNAME", "hikarilucky79"),
		GitHubToken:        strings.TrimSpace(os.Getenv("GITHUB_TOKEN")),
		GitHubBaseURL:      strings.TrimRight(envOr("GITHUB_API_URL", "https://api.github.com"), "/"),
		CacheTTL:           ttl,
		CORSAllowedOrigins: parseCSV(os.Getenv("CORS_ALLOWED_ORIGINS")),
		ContactRateLimit:   rateLimit,
		ContactRateWindow:  rateWindow,
		TrustProxy:         trustProxy,
		DBURL:              dbURL,
		SupabaseURL:        supabaseURL,
		SupabaseSecretKey:  supabaseSecretKey,
	}, nil
}

func firstNonEmptyEnv(keys ...string) string {
	for _, k := range keys {
		if v := strings.TrimSpace(os.Getenv(k)); v != "" {
			return v
		}
	}
	return ""
}

func envOr(key, fallback string) string {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		return v
	}
	return fallback
}

func parseDuration(key string, fallback time.Duration) (time.Duration, error) {
	raw := strings.TrimSpace(os.Getenv(key))
	if raw == "" {
		return fallback, nil
	}
	d, err := time.ParseDuration(raw)
	if err != nil || d <= 0 {
		return 0, fmt.Errorf("invalid %s=%q: must be a positive duration", key, raw)
	}
	return d, nil
}

func parsePositiveInt(key string, fallback int) (int, error) {
	raw := strings.TrimSpace(os.Getenv(key))
	if raw == "" {
		return fallback, nil
	}
	n, err := strconv.Atoi(raw)
	if err != nil || n <= 0 {
		return 0, fmt.Errorf("invalid %s=%q: must be a positive integer", key, raw)
	}
	return n, nil
}

func parseBool(key string, fallback bool) (bool, error) {
	raw := strings.TrimSpace(os.Getenv(key))
	if raw == "" {
		return fallback, nil
	}
	b, err := strconv.ParseBool(raw)
	if err != nil {
		return false, fmt.Errorf("invalid %s=%q: must be boolean", key, raw)
	}
	return b, nil
}

func parseCSV(raw string) []string {
	parts := strings.Split(raw, ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		if trimmed := strings.TrimSpace(p); trimmed != "" {
			out = append(out, trimmed)
		}
	}
	if len(out) == 0 {
		return nil
	}
	return out
}
