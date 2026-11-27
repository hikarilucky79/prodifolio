# AGENTS.md

Guidelines and context for coding agents working in the **Prodifolio** monorepo.

## Overview

**Prodifolio** is a dynamic developer portfolio for `@hikarilucky79`:
- **`backend/`**: Go 1.22+ REST API (`net/http`, `slog`, `singleflight`, TTL cache, IP rate limiting) syncing GitHub repositories/stats and persisting snapshots, rate-limit buckets, and contact messages.
- **`app/`**: Flutter Material 3 app (Web & Mobile) using Riverpod (`flutter_riverpod`) and `CustomPainter`.
- **`db/migrations/`**: Canonical TiDB Cloud (PostgreSQL-compatible) 3NF SQL schema.

## Database & Storage

- **Primary DB**: TiDB Cloud PostgreSQL-compatible (`pgx/v5`).
- **Connection precedence** (`backend/internal/config/config.go`):
  1. `TIDB_DB_URL`
  2. `DATABASE_URL`
  3. `SUPABASE_DB_URL` (legacy fallback)
  - When empty in local dev/tests, the backend falls back to `MemoryStore`.
- **TLS**: `NewPostgres` (`backend/internal/store/postgres.go`) enforces TLS 1.2+ automatically when the host contains `tidb`.
- **Auto-migration**: `backend/internal/store/schema.sql` is embedded via `//go:embed schema.sql` and executed idempotently (`CREATE TABLE IF NOT EXISTS` / `CREATE INDEX IF NOT EXISTS`) during `NewPostgres`. Keep `backend/internal/store/schema.sql` and `db/migrations/001_tidb_init.sql` in sync.
- **Compatibility**: Do **not** add Supabase-specific extensions/roles (`pgcrypto`, `ROW LEVEL SECURITY`, `anon`, `authenticated`, `service_role`) to TiDB migrations.

## Frontend Conventions (`app/`)

- **Architecture**: `core/` (config, theme `FolioPalette`), `domain/` (entities, repository contract), `data/` (HTTP client & repository impl), `presentation/` (Riverpod providers, screens, widgets).
- **CSP**: `app/vercel.json` enforces a strict `Content-Security-Policy`. Any new external image/API origin must be explicitly added to `img-src` / `connect-src`.
- **Widget tests**: `flutter test` blocks real network requests (`Image.network` triggers `errorBuilder`), so widgets rendering network images must provide a local fallback and tests should account for fallback UI.

## Verification Commands

- **Backend (Go)**:
  ```bash
  cd backend
  go vet ./...
  go test -race -v ./...
  ```
- **Frontend (Flutter)**:
  ```bash
  cd app
  flutter analyze
  flutter test
  ```

## Git, Commits & Deploy

- Follow **Conventional Commits** (`feat:`, `fix:`, `docs:`, `refactor:`) with small, atomic commits.
- Never commit `.env` files, tokens, or database credentials.
- **Vercel (`hikari-s-projects2`)**:
  - `prodifolio-api`: Go backend (`backend/`, `Root Directory` = `backend`).
  - `prodifolio`: Flutter Web (`app/build/web`; requires Flutter SDK build before deploying).
