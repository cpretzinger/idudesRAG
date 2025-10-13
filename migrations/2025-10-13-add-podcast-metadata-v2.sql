-- Migration: Add podcast metadata columns to embeddings table
-- Date: 2025-10-13
-- Version: 2 (Production-ready with proper types)
-- Purpose: Store podcast episode metadata alongside text embeddings for better search and filtering
-- Reviewed by: Postgres team, approved for production

-- ========================================
-- PHASE 1: Add columns (holds table lock briefly)
-- ========================================
BEGIN;

ALTER TABLE core.embeddings
ADD COLUMN IF NOT EXISTS episode_title TEXT,
ADD COLUMN IF NOT EXISTS episode_number INTEGER,  -- Changed from TEXT to INTEGER
ADD COLUMN IF NOT EXISTS episode_guid TEXT,
ADD COLUMN IF NOT EXISTS show_name TEXT,
ADD COLUMN IF NOT EXISTS published_at TIMESTAMPTZ;  -- Changed from TEXT to TIMESTAMPTZ

COMMIT;

-- ========================================
-- PHASE 2: Add indexes CONCURRENTLY (no table lock)
-- ========================================
-- Note: CONCURRENTLY requires separate transactions

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_embeddings_episode_number
ON core.embeddings(episode_number)
WHERE episode_number IS NOT NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_embeddings_episode_guid
ON core.embeddings(episode_guid)
WHERE episode_guid IS NOT NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_embeddings_show_name
ON core.embeddings(show_name)
WHERE show_name IS NOT NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_embeddings_published_at
ON core.embeddings(published_at DESC)
WHERE published_at IS NOT NULL;

-- ========================================
-- PHASE 3: Add metadata and constraints
-- ========================================
BEGIN;

-- Documentation comments
COMMENT ON COLUMN core.embeddings.episode_title IS 'Podcast episode title extracted from filename or RSS feed';
COMMENT ON COLUMN core.embeddings.episode_number IS 'Podcast episode number as integer (e.g., 754)';
COMMENT ON COLUMN core.embeddings.episode_guid IS 'Unique podcast episode identifier from RSS feed GUID';
COMMENT ON COLUMN core.embeddings.show_name IS 'Podcast show name (e.g., "The Insurance Dudes")';
COMMENT ON COLUMN core.embeddings.published_at IS 'Episode publication date with timezone';

-- Optional: Add constraint to ensure episode_number is positive
ALTER TABLE core.embeddings
ADD CONSTRAINT check_episode_number_positive
CHECK (episode_number IS NULL OR episode_number > 0);

COMMIT;

-- ========================================
-- VERIFICATION
-- ========================================
SELECT
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'core'
  AND table_name = 'embeddings'
  AND column_name IN ('episode_title', 'episode_number', 'episode_guid', 'show_name', 'published_at')
ORDER BY ordinal_position;

-- Verify indexes
SELECT
  indexname,
  indexdef
FROM pg_indexes
WHERE tablename = 'embeddings'
  AND schemaname = 'core'
  AND indexname LIKE 'idx_embeddings_%episode%'
ORDER BY indexname;
