-- Security hardening:
-- 1. Preserve per-message sender_name so unauthenticated callers cannot rewrite past sender names.
-- 2. Add atomic Postgres-backed rate limit buckets for serverless / multi-instance deployments.
-- 3. Revoke default table/sequence/function grants from anon and authenticated (defense in depth with RLS).

ALTER TABLE contact_messages
    ADD COLUMN IF NOT EXISTS sender_name TEXT NOT NULL DEFAULT '';

ALTER TABLE contact_messages
    DROP CONSTRAINT IF EXISTS contact_messages_sender_name_check;

ALTER TABLE contact_messages
    ADD CONSTRAINT contact_messages_sender_name_check
    CHECK (sender_name = '' OR char_length(trim(sender_name)) BETWEEN 2 AND 100);

CREATE TABLE IF NOT EXISTS rate_limit_buckets (
    bucket_key TEXT PRIMARY KEY,
    hits INTEGER NOT NULL DEFAULT 1 CHECK (hits > 0),
    reset_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_rate_limit_buckets_reset_at
    ON rate_limit_buckets (reset_at);

ALTER TABLE rate_limit_buckets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS deny_public_rate_limit_buckets ON rate_limit_buckets;
CREATE POLICY deny_public_rate_limit_buckets
    ON rate_limit_buckets FOR ALL TO anon, authenticated USING (false) WITH CHECK (false);

CREATE OR REPLACE FUNCTION public.check_rate_limit(
    p_key text,
    p_limit integer,
    p_window_secs double precision
)
RETURNS TABLE(allowed boolean, retry_after_secs double precision)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
    v_now timestamptz := pg_catalog.now();
    v_window interval := pg_catalog.make_interval(secs => p_window_secs);
    v_hits integer;
    v_reset_at timestamptz;
BEGIN
    IF p_limit <= 0 OR p_window_secs <= 0 THEN
        RAISE EXCEPTION 'p_limit and p_window_secs must be positive';
    END IF;

    INSERT INTO public.rate_limit_buckets AS b (bucket_key, hits, reset_at)
    VALUES (p_key, 1, v_now + v_window)
    ON CONFLICT (bucket_key) DO UPDATE
    SET hits = CASE
            WHEN b.reset_at <= v_now THEN 1
            ELSE b.hits + 1
        END,
        reset_at = CASE
            WHEN b.reset_at <= v_now THEN v_now + v_window
            ELSE b.reset_at
        END
    RETURNING b.hits, b.reset_at INTO v_hits, v_reset_at;

    IF pg_catalog.random() < 0.02 THEN
        DELETE FROM public.rate_limit_buckets WHERE reset_at < v_now;
    END IF;

    IF v_hits > p_limit THEN
        RETURN QUERY SELECT false, GREATEST(0::double precision, EXTRACT(EPOCH FROM (v_reset_at - v_now))::double precision);
    ELSE
        RETURN QUERY SELECT true, 0::double precision;
    END IF;
END;
$$;

GRANT ALL ON TABLE public.rate_limit_buckets TO service_role;
REVOKE ALL ON FUNCTION public.check_rate_limit(text, integer, double precision) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.check_rate_limit(text, integer, double precision) TO service_role;

REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon, authenticated;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon, authenticated;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM anon, authenticated;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
    REVOKE ALL ON TABLES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
    REVOKE ALL ON SEQUENCES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
    REVOKE ALL ON FUNCTIONS FROM anon, authenticated;
