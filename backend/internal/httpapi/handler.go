package httpapi

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"math"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/hikarilucky79/prodifolio/backend/internal/github"
	"github.com/hikarilucky79/prodifolio/backend/internal/portfolio"
	"github.com/hikarilucky79/prodifolio/backend/internal/ratelimit"
	"github.com/hikarilucky79/prodifolio/backend/internal/store"
)

type Options struct {
	GitHubUsername      string
	AllowedOrigins      []string
	TrustProxy          bool
	RequireDBForContact bool
	ReadLimiter         *ratelimit.Limiter
	Logger              *slog.Logger
	Now                 func() time.Time
}

type apiErrorBody struct {
	Error apiError `json:"error"`
}

type apiError struct {
	Code    string            `json:"code"`
	Message string            `json:"message"`
	Fields  map[string]string `json:"fields,omitempty"`
}

func NewHandler(svc *portfolio.Service, st store.Store, limiter *ratelimit.Limiter, opts Options) http.Handler {
	if opts.Logger == nil {
		opts.Logger = slog.Default()
	}
	if opts.Now == nil {
		opts.Now = time.Now
	}

	mux := http.NewServeMux()
	h := &handler{
		svc:     svc,
		store:   st,
		limiter: limiter,
		opts:    opts,
	}

	mux.HandleFunc("GET /health", h.handleHealth)
	mux.HandleFunc("GET /projects", h.handleListProjects)
	mux.HandleFunc("GET /projects/{name}", h.handleGetProject)
	mux.HandleFunc("GET /stats", h.handleStats)
	mux.HandleFunc("POST /contact", h.handleContact)

	return h.withLogging(h.withSecurityHeaders(h.withCORS(mux)))
}

type handler struct {
	svc     *portfolio.Service
	store   store.Store
	limiter *ratelimit.Limiter
	opts    Options
}

func (h *handler) handleHealth(w http.ResponseWriter, r *http.Request) {
	status := "ok"
	code := http.StatusOK
	dbMode := "memory"
	var warning string

	if h.store != nil {
		dbMode = h.store.Mode()
		pingCtx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
		defer cancel()
		if err := h.store.Ping(pingCtx); err != nil {
			h.opts.Logger.Error("database health check failed", "error", err)
			status = "degraded"
			code = http.StatusServiceUnavailable
		}
	}

	if h.opts.RequireDBForContact && dbMode == "memory" {
		status = "degraded"
		code = http.StatusServiceUnavailable
		warning = "supabase storage is not configured"
	}

	payload := map[string]any{
		"status":      status,
		"github_user": h.opts.GitHubUsername,
		"database":    dbMode,
		"timestamp":   h.opts.Now().UTC().Format(time.RFC3339),
	}
	if warning != "" {
		payload["warning"] = warning
	}

	w.Header().Set("Cache-Control", "no-store")
	writeJSON(w, code, payload)
}

func (h *handler) handleListProjects(w http.ResponseWriter, r *http.Request) {
	if !h.checkReadRateLimit(w, r) {
		return
	}
	resp, err := h.svc.ListProjects(r.Context())
	if err != nil {
		h.writeUpstreamError(w, err)
		return
	}
	w.Header().Set("Cache-Control", "public, max-age=60, s-maxage=300")
	writeJSON(w, http.StatusOK, resp)
}

func (h *handler) handleGetProject(w http.ResponseWriter, r *http.Request) {
	if !h.checkReadRateLimit(w, r) {
		return
	}
	name := r.PathValue("name")
	detail, err := h.svc.GetProject(r.Context(), name)
	if err != nil {
		h.writeUpstreamError(w, err)
		return
	}
	w.Header().Set("Cache-Control", "public, max-age=60, s-maxage=300")
	writeJSON(w, http.StatusOK, detail)
}

func (h *handler) handleStats(w http.ResponseWriter, r *http.Request) {
	if !h.checkReadRateLimit(w, r) {
		return
	}
	stats, err := h.svc.GetStats(r.Context())
	if err != nil {
		h.writeUpstreamError(w, err)
		return
	}
	w.Header().Set("Cache-Control", "public, max-age=60, s-maxage=300")
	writeJSON(w, http.StatusOK, stats)
}

func (h *handler) handleContact(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Cache-Control", "no-store")

	if h.opts.RequireDBForContact && (h.store == nil || h.store.Mode() == "memory") {
		writeError(w, http.StatusServiceUnavailable, "STORAGE_UNAVAILABLE", "contact storage is not configured", nil)
		return
	}

	ip := ratelimit.ClientIP(r, h.opts.TrustProxy)
	if allowed, retryAfter := h.allowContactRateLimit(r.Context(), "contact:ip:"+ip); !allowed {
		writeRateLimited(w, retryAfter, "too many contact requests, please try again later")
		return
	}

	r.Body = http.MaxBytesReader(w, r.Body, 16<<10)
	var req portfolio.ContactRequest
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_JSON", "request body must be valid JSON", nil)
		return
	}
	var extra any
	if err := dec.Decode(&extra); err != io.EOF {
		writeError(w, http.StatusBadRequest, "INVALID_JSON", "request body must contain a single JSON object", nil)
		return
	}

	if email := strings.ToLower(strings.TrimSpace(req.Email)); email != "" {
		sum := sha256.Sum256([]byte(email))
		emailKey := "contact:email:" + hex.EncodeToString(sum[:])
		if allowed, retryAfter := h.allowContactRateLimit(r.Context(), emailKey); !allowed {
			writeRateLimited(w, retryAfter, "too many contact requests for this email, please try again later")
			return
		}
	}

	receipt, err := h.svc.SubmitContact(r.Context(), req, ip)
	if err != nil {
		var valErr *portfolio.ValidationError
		if errors.As(err, &valErr) {
			writeError(w, http.StatusUnprocessableEntity, "VALIDATION_ERROR", valErr.Message, valErr.Fields)
			return
		}
		h.opts.Logger.Error("failed to store contact message", "error", err)
		writeError(w, http.StatusInternalServerError, "STORE_ERROR", "failed to save contact message", nil)
		return
	}

	writeJSON(w, http.StatusCreated, receipt)
}

func (h *handler) checkReadRateLimit(w http.ResponseWriter, r *http.Request) bool {
	if h.opts.ReadLimiter == nil {
		return true
	}
	ip := ratelimit.ClientIP(r, h.opts.TrustProxy)
	if allowed, retryAfter := h.opts.ReadLimiter.Allow("read:" + ip); !allowed {
		writeRateLimited(w, retryAfter, "too many requests, please try again soon")
		return false
	}
	return true
}

func (h *handler) allowContactRateLimit(ctx context.Context, bucketKey string) (bool, time.Duration) {
	if h.limiter == nil {
		return true, 0
	}
	if rls, ok := h.store.(store.RateLimitStore); ok {
		rlCtx, cancel := context.WithTimeout(ctx, 2*time.Second)
		allowed, retryAfter, err := rls.AllowRateLimit(rlCtx, bucketKey, h.limiter.Limit(), h.limiter.Window())
		cancel()
		if err == nil {
			return allowed, retryAfter
		}
		h.opts.Logger.Warn("shared rate limit lookup failed, falling back to local limiter", "error", err)
	}
	return h.limiter.Allow(bucketKey)
}

func writeRateLimited(w http.ResponseWriter, retryAfter time.Duration, message string) {
	secs := int(math.Ceil(retryAfter.Seconds()))
	if secs < 1 {
		secs = 1
	}
	w.Header().Set("Retry-After", strconv.Itoa(secs))
	writeError(w, http.StatusTooManyRequests, "RATE_LIMITED", message, nil)
}

func (h *handler) writeUpstreamError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, portfolio.ErrInvalidRepoName):
		writeError(w, http.StatusBadRequest, "INVALID_PROJECT_NAME", "repository name contains invalid characters", nil)
	case errors.Is(err, github.ErrNotFound):
		writeError(w, http.StatusNotFound, "NOT_FOUND", "repository not found", nil)
	case errors.Is(err, github.ErrRateLimited):
		writeError(w, http.StatusServiceUnavailable, "GITHUB_RATE_LIMITED", "github rate limit reached, try again soon", nil)
	default:
		h.opts.Logger.Error("upstream github error", "error", err)
		writeError(w, http.StatusBadGateway, "UPSTREAM_ERROR", "failed to fetch portfolio data from GitHub", nil)
	}
}

func (h *handler) withCORS(next http.Handler) http.Handler {
	allowAll := false
	allowed := make(map[string]struct{}, len(h.opts.AllowedOrigins))
	for _, origin := range h.opts.AllowedOrigins {
		if origin == "*" {
			allowAll = true
		} else {
			allowed[origin] = struct{}{}
		}
	}

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")
		if allowAll {
			w.Header().Set("Access-Control-Allow-Origin", "*")
		} else {
			// Always advertise Vary: Origin so CDNs do not serve non-CORS cached responses to allowed browser origins.
			w.Header().Add("Vary", "Origin")
			if origin != "" {
				if _, ok := allowed[origin]; ok {
					w.Header().Set("Access-Control-Allow-Origin", origin)
				}
			}
		}
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (sr *statusRecorder) WriteHeader(code int) {
	sr.status = code
	sr.ResponseWriter.WriteHeader(code)
}

func (h *handler) withLogging(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := h.opts.Now()
		rec := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(rec, r)
		h.opts.Logger.Info("http_request",
			"method", r.Method,
			"path", sanitizePath(r.URL.Path),
			"status", rec.status,
			"duration_ms", h.opts.Now().Sub(start).Milliseconds(),
			"ip", ratelimit.ClientIP(r, h.opts.TrustProxy),
		)
	})
}

func (h *handler) withSecurityHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "DENY")
		w.Header().Set("Referrer-Policy", "strict-origin-when-cross-origin")
		w.Header().Set("Content-Security-Policy", "default-src 'none'; frame-ancestors 'none'")
		w.Header().Set("Permissions-Policy", "camera=(), microphone=(), geolocation=()")
		next.ServeHTTP(w, r)
	})
}

func sanitizePath(p string) string {
	return strings.ReplaceAll(strings.ReplaceAll(p, "\n", ""), "\r", "")
}

func writeError(w http.ResponseWriter, status int, code, message string, fields map[string]string) {
	w.Header().Set("Cache-Control", "no-store")
	writeJSON(w, status, apiErrorBody{
		Error: apiError{
			Code:    code,
			Message: message,
			Fields:  fields,
		},
	})
}

func writeJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}
