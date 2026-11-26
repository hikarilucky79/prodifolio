package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/hikarilucky79/prodifolio/backend/internal/config"
	"github.com/hikarilucky79/prodifolio/backend/internal/github"
	"github.com/hikarilucky79/prodifolio/backend/internal/httpapi"
	"github.com/hikarilucky79/prodifolio/backend/internal/portfolio"
	"github.com/hikarilucky79/prodifolio/backend/internal/ratelimit"
	"github.com/hikarilucky79/prodifolio/backend/internal/store"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))

	cfg, err := config.Load()
	if err != nil {
		logger.Error("invalid configuration", "error", err)
		os.Exit(1)
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	var st store.Store
	switch {
	case cfg.DBURL != "":
		pgStore, err := store.NewPostgres(ctx, cfg.DBURL)
		if err != nil {
			logger.Error("failed to connect to database", "error", err)
			os.Exit(1)
		}
		st = pgStore
	case cfg.SupabaseURL != "" && cfg.SupabaseSecretKey != "":
		restStore, err := store.NewSupabaseREST(cfg.SupabaseURL, cfg.SupabaseSecretKey, nil, logger)
		if err != nil {
			logger.Error("failed to initialize supabase rest store", "error", err)
			os.Exit(1)
		}
		st = restStore
	default:
		logger.Warn("database storage is not configured; using ephemeral in-memory store")
		st = store.NewMemory(nil)
	}
	defer func() {
		if err := st.Close(); err != nil {
			logger.Error("failed to close store", "error", err)
		}
	}()

	ghClient := github.NewHTTPClient(cfg.GitHubBaseURL, cfg.GitHubToken, nil)
	svc := portfolio.NewService(cfg.GitHubUsername, ghClient, st, cfg.CacheTTL, nil, logger)
	limiter := ratelimit.New(cfg.ContactRateLimit, cfg.ContactRateWindow, nil)
	readLimiter := ratelimit.New(120, time.Minute, nil)

	handler := httpapi.NewHandler(svc, st, limiter, httpapi.Options{
		GitHubUsername:      cfg.GitHubUsername,
		AllowedOrigins:      cfg.CORSAllowedOrigins,
		TrustProxy:          cfg.TrustProxy,
		RequireDBForContact: cfg.IsProduction,
		ReadLimiter:         readLimiter,
		Logger:              logger,
	})

	srv := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           handler,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       15 * time.Second,
		WriteTimeout:      15 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	errCh := make(chan error, 1)
	go func() {
		logger.Info("server starting",
			"addr", srv.Addr,
			"github_user", cfg.GitHubUsername,
			"database", st.Mode(),
			"cache_ttl", cfg.CacheTTL.String(),
		)
		errCh <- srv.ListenAndServe()
	}()

	select {
	case err := <-errCh:
		if err != nil && !errors.Is(err, http.ErrServerClosed) {
			logger.Error("server exited with error", "error", err)
			os.Exit(1)
		}
	case <-ctx.Done():
		logger.Info("shutdown signal received")
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if err := srv.Shutdown(shutdownCtx); err != nil {
			logger.Error("graceful shutdown failed", "error", err)
			os.Exit(1)
		}
		logger.Info("server stopped cleanly")
	}
}
