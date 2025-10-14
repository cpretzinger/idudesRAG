-- =========================================
-- Migration: Add Unified API Cache Table
-- =========================================
-- Created: 2025-10-14
-- Purpose: Add caching for OpenAI API calls (embeddings, LLM generation, review)
-- Based on: Zuck + Elon's unified design with observability
--
-- Tables Added:
--   - core.api_cache (unified cache for all API types)
--
-- Columns Added:
--   - core.embeddings.content_hash (for deduplication)
--
-- Functions Added:
--   - core.cleanup_old_cache() (retention policy)
--
-- =========================================

SET search_path TO core, public;

-- =========================================
-- 1. Create Unified API Cache Table
-- =========================================

CREATE TABLE IF NOT EXISTS core.api_cache (
  key_hash text PRIMARY KEY,
  cache_type text NOT NULL CHECK (cache_type IN ('embedding', 'generation', 'review')),
  model text NOT NULL,
  model_version text NOT NULL DEFAULT 'v1',
  request_payload jsonb NOT NULL,
  response_data jsonb NOT NULL,
  cost_usd numeric(10,6),
  hit_count int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Add comment
COMMENT ON TABLE core.api_cache IS 'Unified cache for OpenAI API responses (embeddings, generation, review). Tracks hit_count and cost for observability.';

COMMENT ON COLUMN core.api_cache.key_hash IS 'SHA256 hash of (model + request_payload + version). Unique cache key.';
COMMENT ON COLUMN core.api_cache.cache_type IS 'Type of cached API call: embedding, generation, or review';
COMMENT ON COLUMN core.api_cache.model_version IS 'Prompt/model version for cache invalidation';
COMMENT ON COLUMN core.api_cache.hit_count IS 'Number of times this cache entry was used (cost savings metric)';
COMMENT ON COLUMN core.api_cache.cost_usd IS 'Estimated cost per call (for ROI tracking)';

-- =========================================
-- 2. Create Indexes
-- =========================================

-- Index for cache lookups by type
CREATE INDEX IF NOT EXISTS idx_api_cache_type
  ON core.api_cache(cache_type, created_at DESC);

-- Index for retention cleanup
CREATE INDEX IF NOT EXISTS idx_api_cache_created
  ON core.api_cache(created_at DESC);

-- Index for model version invalidation
CREATE INDEX IF NOT EXISTS idx_api_cache_version
  ON core.api_cache(cache_type, model_version);

-- Index for cost analysis
CREATE INDEX IF NOT EXISTS idx_api_cache_hit_count
  ON core.api_cache(cache_type, hit_count DESC)
  WHERE hit_count > 0;

-- =========================================
-- 3. Add content_hash to embeddings
-- =========================================

-- Add column for deduplication
ALTER TABLE core.embeddings
  ADD COLUMN IF NOT EXISTS content_hash text;

-- Add index for lookup
CREATE INDEX IF NOT EXISTS idx_embeddings_content_hash
  ON core.embeddings(file_id, content_hash);

COMMENT ON COLUMN core.embeddings.content_hash IS 'SHA256 hash of text content for deduplication';

-- =========================================
-- 4. Create Cleanup Function
-- =========================================

CREATE OR REPLACE FUNCTION core.cleanup_old_cache(
  retention_days int DEFAULT 90
)
RETURNS TABLE(
  cache_type text,
  deleted_count bigint
) AS $$
DECLARE
  cutoff_date timestamptz;
BEGIN
  cutoff_date := NOW() - (retention_days || ' days')::interval;

  -- Delete old cache entries by type and return counts
  RETURN QUERY
  WITH deleted AS (
    DELETE FROM core.api_cache
    WHERE created_at < cutoff_date
    RETURNING cache_type
  )
  SELECT
    d.cache_type,
    COUNT(*)::bigint as deleted_count
  FROM deleted d
  GROUP BY d.cache_type;

END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION core.cleanup_old_cache(int) IS 'Deletes cache entries older than retention_days (default: 90). Returns deleted counts by cache_type.';

-- =========================================
-- 5. Create Cache Stats Function
-- =========================================

CREATE OR REPLACE FUNCTION core.get_cache_stats()
RETURNS TABLE(
  cache_type text,
  total_entries bigint,
  total_hits bigint,
  hit_rate numeric,
  estimated_savings_usd numeric,
  avg_age_days numeric
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    ac.cache_type,
    COUNT(*)::bigint as total_entries,
    SUM(ac.hit_count)::bigint as total_hits,
    CASE
      WHEN COUNT(*) > 0 THEN ROUND(AVG(ac.hit_count), 2)
      ELSE 0
    END as hit_rate,
    ROUND(SUM(ac.hit_count * COALESCE(ac.cost_usd, 0)), 2) as estimated_savings_usd,
    ROUND(AVG(EXTRACT(EPOCH FROM (NOW() - ac.created_at)) / 86400), 1) as avg_age_days
  FROM core.api_cache ac
  GROUP BY ac.cache_type
  ORDER BY total_hits DESC;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION core.get_cache_stats() IS 'Returns cache effectiveness metrics: entries, hits, savings, age by cache_type';

-- =========================================
-- 6. Create Trigger for updated_at
-- =========================================

CREATE OR REPLACE FUNCTION core.update_cache_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_api_cache_updated_at
  BEFORE UPDATE ON core.api_cache
  FOR EACH ROW
  EXECUTE FUNCTION core.update_cache_timestamp();

-- =========================================
-- 7. Verify Migration
-- =========================================

DO $$
BEGIN
  -- Check table exists
  IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'core' AND tablename = 'api_cache') THEN
    RAISE EXCEPTION 'Migration failed: core.api_cache table not created';
  END IF;

  -- Check indexes exist
  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'core' AND indexname = 'idx_api_cache_type') THEN
    RAISE EXCEPTION 'Migration failed: idx_api_cache_type index not created';
  END IF;

  -- Check functions exist
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'cleanup_old_cache') THEN
    RAISE EXCEPTION 'Migration failed: cleanup_old_cache function not created';
  END IF;

  RAISE NOTICE 'Migration completed successfully!';
  RAISE NOTICE 'Created: core.api_cache table';
  RAISE NOTICE 'Created: 4 indexes on api_cache';
  RAISE NOTICE 'Created: cleanup_old_cache() function';
  RAISE NOTICE 'Created: get_cache_stats() function';
  RAISE NOTICE 'Added: content_hash column to embeddings';
END $$;

-- =========================================
-- Usage Examples
-- =========================================

-- Check cache stats
-- SELECT * FROM core.get_cache_stats();

-- Run cleanup (dry run)
-- SELECT * FROM core.cleanup_old_cache(90);

-- Query cache hits by type
-- SELECT cache_type, SUM(hit_count) as total_hits, COUNT(*) as entries
-- FROM core.api_cache
-- GROUP BY cache_type;

-- Find most reused cache entries
-- SELECT cache_type, key_hash, hit_count, created_at
-- FROM core.api_cache
-- ORDER BY hit_count DESC
-- LIMIT 10;
