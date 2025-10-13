-- Migration: Add podcast metadata columns to embeddings table
-- Date: 2025-10-13
-- Purpose: Store podcast episode metadata alongside text embeddings for better search and filtering

BEGIN;

-- Add podcast-specific columns to embeddings table
ALTER TABLE core.embeddings
ADD COLUMN IF NOT EXISTS episode_title TEXT,
ADD COLUMN IF NOT EXISTS episode_number TEXT,
ADD COLUMN IF NOT EXISTS episode_guid TEXT,
ADD COLUMN IF NOT EXISTS show_name TEXT,
ADD COLUMN IF NOT EXISTS published_at TEXT;

-- Create indexes for podcast metadata searches
CREATE INDEX IF NOT EXISTS idx_embeddings_episode_number ON core.embeddings(episode_number) WHERE episode_number IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_embeddings_episode_guid ON core.embeddings(episode_guid) WHERE episode_guid IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_embeddings_show_name ON core.embeddings(show_name) WHERE show_name IS NOT NULL;

-- Add comment for documentation
COMMENT ON COLUMN core.embeddings.episode_title IS 'Podcast episode title extracted from filename or metadata';
COMMENT ON COLUMN core.embeddings.episode_number IS 'Podcast episode number (e.g., "754")';
COMMENT ON COLUMN core.embeddings.episode_guid IS 'Unique podcast episode identifier from RSS feed';
COMMENT ON COLUMN core.embeddings.show_name IS 'Podcast show name (e.g., "The Insurance Dudes")';
COMMENT ON COLUMN core.embeddings.published_at IS 'Episode publication date';

COMMIT;

-- Verification query
SELECT
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'core'
  AND table_name = 'embeddings'
  AND column_name IN ('episode_title', 'episode_number', 'episode_guid', 'show_name', 'published_at')
ORDER BY ordinal_position;
