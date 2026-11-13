-- Prodifolio: PostgreSQL / Supabase schema normalized to 3NF (Third Normal Form).
--
-- 1NF: Every column holds atomic values; repeating language lists are decomposed into
--      `repository_languages`, and every table defines an explicit primary key.
-- 2NF: In the only composite-key table (`repository_languages`), `bytes_count` depends on
--      the complete key `(repository_id, language_id)`.
-- 3NF: Transitive dependencies and derived totals are eliminated:
--      - Owner profile fields live in `owners` (not duplicated on `repositories`).
--      - Language names live in `languages` (referenced by surrogate FK).
--      - Sender identity (`email`, `name`) lives in `contact_senders` (not duplicated on
--        every row of `contact_messages`).

CREATE EXTENSION IF NOT EXISTS pgcrypto;

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
    message TEXT NOT NULL CHECK (char_length(trim(message)) BETWEEN 10 AND 2000),
    client_ip INET NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
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

-- Lock down Supabase PostgREST public access; backend connects with DB credentials.
ALTER TABLE owners ENABLE ROW LEVEL SECURITY;
ALTER TABLE languages ENABLE ROW LEVEL SECURITY;
ALTER TABLE repositories ENABLE ROW LEVEL SECURITY;
ALTER TABLE repository_languages ENABLE ROW LEVEL SECURITY;
ALTER TABLE commit_activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE contact_senders ENABLE ROW LEVEL SECURITY;
ALTER TABLE contact_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY deny_public_owners ON owners FOR ALL TO anon, authenticated USING (false) WITH CHECK (false);
CREATE POLICY deny_public_languages ON languages FOR ALL TO anon, authenticated USING (false) WITH CHECK (false);
CREATE POLICY deny_public_repositories ON repositories FOR ALL TO anon, authenticated USING (false) WITH CHECK (false);
CREATE POLICY deny_public_repository_languages ON repository_languages FOR ALL TO anon, authenticated USING (false) WITH CHECK (false);
CREATE POLICY deny_public_commit_activities ON commit_activities FOR ALL TO anon, authenticated USING (false) WITH CHECK (false);
CREATE POLICY deny_public_contact_senders ON contact_senders FOR ALL TO anon, authenticated USING (false) WITH CHECK (false);
CREATE POLICY deny_public_contact_messages ON contact_messages FOR ALL TO anon, authenticated USING (false) WITH CHECK (false);
