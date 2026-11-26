package store

import (
	"context"
	"crypto/tls"
	"database/sql"
	_ "embed"
	"fmt"
	"math"
	"os"
	"strings"
	"sync/atomic"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/stdlib"
)

//go:embed schema.sql
var schemaSQL string

type PostgresStore struct {
	db              *sql.DB
	mode            string
	lastCleanupUnix atomic.Int64
}

func NewPostgres(ctx context.Context, dbURL string) (*PostgresStore, error) {
	pgCfg, err := pgx.ParseConfig(dbURL)
	if err != nil {
		return nil, fmt.Errorf("parse postgres config: %w", err)
	}
	isTiDB := strings.Contains(strings.ToLower(pgCfg.Host), "tidb")
	if isTiDB && pgCfg.TLSConfig == nil {
		// TiDB Cloud PostgreSQL requires TLS even when sslmode is omitted from the DSN.
		pgCfg.TLSConfig = &tls.Config{
			ServerName: pgCfg.Host,
			MinVersion: tls.VersionTLS12,
		}
	}
	isVercel := strings.TrimSpace(os.Getenv("VERCEL")) == "1"
	if pgCfg.Port == 6543 || isVercel {
		// Poolers and ephemeral lambdas avoid prepared-statement affinity issues.
		pgCfg.DefaultQueryExecMode = pgx.QueryExecModeSimpleProtocol
	}

	db := stdlib.OpenDB(*pgCfg)
	if isVercel {
		db.SetMaxOpenConns(3)
		db.SetMaxIdleConns(1)
		db.SetConnMaxLifetime(5 * time.Minute)
	} else {
		db.SetMaxOpenConns(10)
		db.SetMaxIdleConns(5)
		db.SetConnMaxLifetime(30 * time.Minute)
	}

	pingCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	if err := db.PingContext(pingCtx); err != nil {
		_ = db.Close()
		return nil, fmt.Errorf("ping database: %w", err)
	}

	schemaCtx, schemaCancel := context.WithTimeout(ctx, 15*time.Second)
	defer schemaCancel()
	if _, err := db.ExecContext(schemaCtx, schemaSQL); err != nil {
		_ = db.Close()
		return nil, fmt.Errorf("ensure database schema: %w", err)
	}

	mode := "postgres"
	if isTiDB {
		mode = "tidb"
	}
	return &PostgresStore{db: db, mode: mode}, nil
}

func (p *PostgresStore) SaveContact(ctx context.Context, input ContactInput) (ContactReceipt, error) {
	tx, err := p.db.BeginTx(ctx, nil)
	if err != nil {
		return ContactReceipt{}, err
	}
	defer tx.Rollback()

	var senderID string
	err = tx.QueryRowContext(ctx, `
		INSERT INTO contact_senders (email, name)
		VALUES ($1, $2)
		ON CONFLICT (email) DO UPDATE
		SET updated_at = NOW()
		RETURNING id::text
	`, input.Email, input.Name).Scan(&senderID)
	if err != nil {
		return ContactReceipt{}, fmt.Errorf("upsert contact_sender: %w", err)
	}

	var receipt ContactReceipt
	err = tx.QueryRowContext(ctx, `
		INSERT INTO contact_messages (sender_id, sender_name, message, client_ip)
		VALUES ($1::uuid, $2, $3, $4::inet)
		RETURNING id::text, created_at
	`, senderID, input.Name, input.Message, input.ClientIP).Scan(&receipt.ID, &receipt.CreatedAt)
	if err != nil {
		return ContactReceipt{}, fmt.Errorf("insert contact_message: %w", err)
	}

	if err := tx.Commit(); err != nil {
		return ContactReceipt{}, err
	}
	receipt.Status = "received"
	receipt.CreatedAt = receipt.CreatedAt.UTC()
	return receipt, nil
}

func (p *PostgresStore) AllowRateLimit(ctx context.Context, key string, limit int, window time.Duration) (bool, time.Duration, error) {
	if limit <= 0 || window <= 0 {
		return true, 0, nil
	}

	var hits int
	var retrySecs float64
	err := p.db.QueryRowContext(ctx, `
		INSERT INTO rate_limit_buckets (bucket_key, hits, reset_at)
		VALUES ($1, 1, NOW() + make_interval(secs => $2))
		ON CONFLICT (bucket_key) DO UPDATE
		SET hits = CASE
				WHEN rate_limit_buckets.reset_at <= NOW() THEN 1
				ELSE rate_limit_buckets.hits + 1
			END,
			reset_at = CASE
				WHEN rate_limit_buckets.reset_at <= NOW() THEN NOW() + make_interval(secs => $2)
				ELSE rate_limit_buckets.reset_at
			END
		RETURNING hits, GREATEST(0, EXTRACT(EPOCH FROM (reset_at - NOW())))::double precision
	`, key, window.Seconds()).Scan(&hits, &retrySecs)
	if err != nil {
		return false, 0, fmt.Errorf("check rate limit bucket: %w", err)
	}

	p.maybeCleanupExpiredBuckets(ctx)

	if hits > limit {
		secs := int64(math.Ceil(retrySecs))
		if secs < 1 {
			secs = 1
		}
		return false, time.Duration(secs) * time.Second, nil
	}
	return true, 0, nil
}

func (p *PostgresStore) maybeCleanupExpiredBuckets(ctx context.Context) {
	nowUnix := time.Now().Unix()
	last := p.lastCleanupUnix.Load()
	if nowUnix-last < 300 || !p.lastCleanupUnix.CompareAndSwap(last, nowUnix) {
		return
	}
	cleanupCtx, cancel := context.WithTimeout(ctx, 2*time.Second)
	defer cancel()
	_, _ = p.db.ExecContext(cleanupCtx, `DELETE FROM rate_limit_buckets WHERE reset_at < NOW() - INTERVAL '5 minutes'`)
}

func (p *PostgresStore) SyncPortfolio(ctx context.Context, snapshot PortfolioSnapshot) error {
	if snapshot.Owner.Login == "" {
		return nil
	}

	tx, err := p.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	ownerID := snapshot.Owner.ID
	if ownerID == 0 {
		err := tx.QueryRowContext(ctx, `SELECT id FROM owners WHERE github_username = $1`, snapshot.Owner.Login).Scan(&ownerID)
		if err == sql.ErrNoRows {
			return nil
		}
		if err != nil {
			return fmt.Errorf("lookup owner: %w", err)
		}
	} else {
		_, err = tx.ExecContext(ctx, `
			INSERT INTO owners (id, github_username, display_name, bio, avatar_url, profile_url, blog_url, synced_at)
			VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
			ON CONFLICT (id) DO UPDATE
			SET github_username = EXCLUDED.github_username,
			    display_name = EXCLUDED.display_name,
			    bio = EXCLUDED.bio,
			    avatar_url = EXCLUDED.avatar_url,
			    profile_url = EXCLUDED.profile_url,
			    blog_url = EXCLUDED.blog_url,
			    synced_at = NOW()
		`,
			ownerID,
			snapshot.Owner.Login,
			snapshot.Owner.Name,
			snapshot.Owner.Bio,
			snapshot.Owner.AvatarURL,
			snapshot.Owner.HTMLURL,
			snapshot.Owner.Blog,
		)
		if err != nil {
			return fmt.Errorf("upsert owner: %w", err)
		}
	}

	langIDs := make(map[string]int64)
	ensureLang := func(name string) (*int64, error) {
		name = strings.TrimSpace(name)
		if name == "" {
			return nil, nil
		}
		if id, ok := langIDs[name]; ok {
			return &id, nil
		}
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO languages (name) VALUES ($1) ON CONFLICT (name) DO NOTHING
		`, name); err != nil {
			return nil, err
		}
		var id int64
		if err := tx.QueryRowContext(ctx, `SELECT id FROM languages WHERE name = $1`, name).Scan(&id); err != nil {
			return nil, err
		}
		langIDs[name] = id
		return &id, nil
	}

	repoIDByFullName := make(map[string]int64, len(snapshot.Repos))
	for _, repo := range snapshot.Repos {
		if repo.ID == 0 {
			continue
		}
		primaryLangID, err := ensureLang(repo.Language)
		if err != nil {
			return fmt.Errorf("ensure primary language: %w", err)
		}

		branch := repo.DefaultBranch
		if branch == "" {
			branch = "main"
		}
		var lastCommit any
		if repo.PushedAt != nil {
			lastCommit = *repo.PushedAt
		}

		_, err = tx.ExecContext(ctx, `
			INSERT INTO repositories (
				id, owner_id, name, description, html_url, homepage_url,
				default_branch, stars_count, forks_count, primary_language_id,
				is_fork, last_commit_at, synced_at
			)
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, NOW())
			ON CONFLICT (id) DO UPDATE
			SET name = EXCLUDED.name,
			    description = EXCLUDED.description,
			    html_url = EXCLUDED.html_url,
			    homepage_url = EXCLUDED.homepage_url,
			    default_branch = EXCLUDED.default_branch,
			    stars_count = EXCLUDED.stars_count,
			    forks_count = EXCLUDED.forks_count,
			    primary_language_id = EXCLUDED.primary_language_id,
			    is_fork = EXCLUDED.is_fork,
			    last_commit_at = EXCLUDED.last_commit_at,
			    synced_at = NOW()
		`,
			repo.ID, ownerID, repo.Name, repo.Description, repo.HTMLURL, repo.Homepage,
			branch, repo.StargazersCount, repo.ForksCount, primaryLangID,
			repo.Fork, lastCommit,
		)
		if err != nil {
			return fmt.Errorf("upsert repository %s: %w", repo.Name, err)
		}
		repoIDByFullName[strings.ToLower(snapshot.Owner.Login+"/"+repo.Name)] = repo.ID

		if langs, ok := snapshot.Languages[repo.ID]; ok {
			for langName, bytesCount := range langs {
				langID, err := ensureLang(langName)
				if err != nil || langID == nil {
					return fmt.Errorf("ensure repo language %s: %w", langName, err)
				}
				if _, err := tx.ExecContext(ctx, `
					INSERT INTO repository_languages (repository_id, language_id, bytes_count)
					VALUES ($1, $2, $3)
					ON CONFLICT (repository_id, language_id) DO UPDATE
					SET bytes_count = EXCLUDED.bytes_count
				`, repo.ID, *langID, bytesCount); err != nil {
					return fmt.Errorf("upsert repository_language: %w", err)
				}
			}
		}
	}

	for _, ev := range snapshot.Events {
		if ev.Type != "PushEvent" || ev.HeadSHA == "" || ev.CommitCount <= 0 {
			continue
		}
		repoID, ok := repoIDByFullName[strings.ToLower(ev.RepoName)]
		if !ok {
			continue
		}
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO commit_activities (repository_id, commit_sha, commit_count, committed_at)
			VALUES ($1, $2, $3, $4)
			ON CONFLICT (repository_id, commit_sha) DO NOTHING
		`, repoID, ev.HeadSHA, ev.CommitCount, ev.CreatedAt); err != nil {
			return fmt.Errorf("insert commit_activity: %w", err)
		}
	}

	return tx.Commit()
}

func (p *PostgresStore) Ping(ctx context.Context) error {
	return p.db.PingContext(ctx)
}

func (p *PostgresStore) Close() error {
	return p.db.Close()
}

func (p *PostgresStore) Mode() string {
	if p.mode != "" {
		return p.mode
	}
	return "postgres"
}
