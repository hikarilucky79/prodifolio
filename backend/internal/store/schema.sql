-- Prodifolio: TiDB Cloud (PostgreSQL-compatible) schema normalized to 3NF (Third Normal Form).

CREATE TABLE IF NOT EXISTS owners (
    id BIGINT PRIMARY KEY,
    github_username TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL DEFAULT '',
    bio TEXT NOT NULL DEFAULT '',
    avatar_url TEXT NOT NULL DEFAULT '',
    profile_url TEXT NOT NULL,
    blog_url TEXT NOT NULL DEFAULT '',
    synced_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS languages (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS repositories (
    id BIGINT PRIMARY KEY,
    owner_id BIGINT NOT NULL REFERENCES owners(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    html_url TEXT NOT NULL,
    homepage_url TEXT NOT NULL DEFAULT '',
    default_branch TEXT NOT NULL DEFAULT 'main',
    stars_count INTEGER NOT NULL DEFAULT 0 CHECK (stars_count >= 0),
    forks_count INTEGER NOT NULL DEFAULT 0 CHECK (forks_count >= 0),
    primary_language_id BIGINT REFERENCES languages(id) ON DELETE SET NULL,
    is_fork BOOLEAN NOT NULL DEFAULT FALSE,
    last_commit_at TIMESTAMPTZ,
    synced_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (owner_id, name)
);

CREATE TABLE IF NOT EXISTS repository_languages (
    repository_id BIGINT NOT NULL REFERENCES repositories(id) ON DELETE CASCADE,
    language_id BIGINT NOT NULL REFERENCES languages(id) ON DELETE RESTRICT,
    bytes_count BIGINT NOT NULL DEFAULT 0 CHECK (bytes_count >= 0),
    PRIMARY KEY (repository_id, language_id)
);

CREATE TABLE IF NOT EXISTS commit_activities (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    repository_id BIGINT NOT NULL REFERENCES repositories(id) ON DELETE CASCADE,
    commit_sha TEXT NOT NULL,
    commit_count INTEGER NOT NULL DEFAULT 1 CHECK (commit_count > 0),
    committed_at TIMESTAMPTZ NOT NULL,
    UNIQUE (repository_id, commit_sha)
);

CREATE TABLE IF NOT EXISTS contact_senders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL CHECK (char_length(trim(name)) BETWEEN 2 AND 100),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS contact_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID NOT NULL REFERENCES contact_senders(id) ON DELETE RESTRICT,
    sender_name TEXT NOT NULL DEFAULT '' CHECK (sender_name = '' OR char_length(trim(sender_name)) BETWEEN 2 AND 100),
    message TEXT NOT NULL CHECK (char_length(trim(message)) BETWEEN 10 AND 2000),
    client_ip INET NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS rate_limit_buckets (
    bucket_key TEXT PRIMARY KEY,
    hits INTEGER NOT NULL DEFAULT 1 CHECK (hits > 0),
    reset_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_repositories_owner_last_commit
    ON repositories (owner_id, last_commit_at DESC NULLS LAST);

CREATE INDEX IF NOT EXISTS idx_repositories_primary_language
    ON repositories (primary_language_id);

CREATE INDEX IF NOT EXISTS idx_repository_languages_language
    ON repository_languages (language_id);

CREATE INDEX IF NOT EXISTS idx_commit_activities_committed_at
    ON commit_activities (committed_at DESC);

CREATE INDEX IF NOT EXISTS idx_contact_messages_sender_created
    ON contact_messages (sender_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_rate_limit_buckets_reset_at
    ON rate_limit_buckets (reset_at);
