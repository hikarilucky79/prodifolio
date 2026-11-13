package config

import "testing"

func TestLoadSecurityDefaults(t *testing.T) {
	t.Setenv("CORS_ALLOWED_ORIGINS", "")
	t.Setenv("VERCEL", "")
	t.Setenv("VERCEL_ENV", "")
	t.Setenv("APP_ENV", "")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(cfg.CORSAllowedOrigins) != 0 {
		t.Fatalf("expected empty CORSAllowedOrigins by default, got %v", cfg.CORSAllowedOrigins)
	}
	if cfg.IsProduction {
		t.Fatal("expected IsProduction=false by default")
	}

	t.Setenv("VERCEL", "1")
	t.Setenv("CORS_ALLOWED_ORIGINS", "https://prodifolio.vercel.app, https://example.com")
	cfg, err = Load()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !cfg.IsProduction {
		t.Fatal("expected IsProduction=true when VERCEL=1")
	}
	if len(cfg.CORSAllowedOrigins) != 2 || cfg.CORSAllowedOrigins[0] != "https://prodifolio.vercel.app" {
		t.Fatalf("unexpected CORSAllowedOrigins: %v", cfg.CORSAllowedOrigins)
	}
}

func TestLoadSupabaseRESTConfig(t *testing.T) {
	t.Setenv("SUPABASE_DB_URL", "")
	t.Setenv("DATABASE_URL", "")
	t.Setenv("SUPABASE_SERVICE_ROLE_KEY", "")

	t.Setenv("SUPABASE_URL", "https://example.supabase.co/")
	t.Setenv("SUPABASE_SECRET_KEY", "")
	if _, err := Load(); err == nil {
		t.Fatal("expected error when SUPABASE_URL is set without SUPABASE_SECRET_KEY")
	}

	t.Setenv("SUPABASE_URL", "ftp://example.supabase.co")
	t.Setenv("SUPABASE_SECRET_KEY", "sb_secret_test")
	if _, err := Load(); err == nil {
		t.Fatal("expected error for non-http SUPABASE_URL")
	}

	t.Setenv("SUPABASE_URL", "https://example.supabase.co/")
	t.Setenv("SUPABASE_SECRET_KEY", "sb_secret_test")
	cfg, err := Load()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if cfg.SupabaseURL != "https://example.supabase.co" {
		t.Fatalf("expected trimmed SupabaseURL, got %q", cfg.SupabaseURL)
	}
	if cfg.SupabaseSecretKey != "sb_secret_test" {
		t.Fatalf("unexpected SupabaseSecretKey: %q", cfg.SupabaseSecretKey)
	}
}
