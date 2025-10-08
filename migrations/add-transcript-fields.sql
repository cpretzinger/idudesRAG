-- =====================================================================
-- MIGRATION: Add Transcript-Specific Fields to Documents Table
-- Purpose: Support podcast transcript ingestion and management
-- Date: 2025-10-08
-- =====================================================================

-- Add new columns to core.documents table
ALTER TABLE core.documents 
    ADD COLUMN IF NOT EXISTS document_type VARCHAR(50) DEFAULT 'document' NOT NULL,
    ADD COLUMN IF NOT EXISTS language VARCHAR(10) DEFAULT 'en' NOT NULL,
    ADD COLUMN IF NOT EXISTS episode_id VARCHAR(255);

-- Add check constraint for document_type validation
ALTER TABLE core.documents 
    ADD CONSTRAINT chk_document_type 
    CHECK (document_type IN ('document', 'transcript'));

-- Add check constraint for language code format (ISO 639-1)
ALTER TABLE core.documents 
    ADD CONSTRAINT chk_language_format 
    CHECK (language ~ '^[a-z]{2}$');

-- =====================================================================
-- PERFORMANCE INDEXES
-- =====================================================================

-- Index for filtering by document type (common query pattern)
CREATE INDEX IF NOT EXISTS idx_documents_document_type 
    ON core.documents(document_type);

-- Index for transcript lookup by episode_id
CREATE INDEX IF NOT EXISTS idx_documents_episode_id 
    ON core.documents(episode_id) 
    WHERE episode_id IS NOT NULL;

-- Composite index for efficient transcript queries
CREATE INDEX IF NOT EXISTS idx_documents_type_episode 
    ON core.documents(document_type, episode_id) 
    WHERE document_type = 'transcript';

-- Index for language-based filtering
CREATE INDEX IF NOT EXISTS idx_documents_language 
    ON core.documents(language);

-- =====================================================================
-- COMMENTS FOR DOCUMENTATION
-- =====================================================================

COMMENT ON COLUMN core.documents.document_type IS 
    'Type of document: "document" for regular files, "transcript" for podcast episodes';

COMMENT ON COLUMN core.documents.language IS 
    'ISO 639-1 language code (e.g., "en" for English, "es" for Spanish)';

COMMENT ON COLUMN core.documents.episode_id IS 
    'Unique identifier linking transcripts to podcast episodes (nullable for non-transcript documents)';

-- =====================================================================
-- DATA MIGRATION
-- =====================================================================

-- Update existing records to have default values
-- (Already handled by DEFAULT clause, but explicit for clarity)
UPDATE core.documents 
SET 
    document_type = 'document',
    language = 'en'
WHERE 
    document_type IS NULL 
    OR language IS NULL;

-- =====================================================================
-- VERIFICATION QUERY
-- =====================================================================

-- Verify the migration succeeded
DO $$
DECLARE
    doc_type_exists BOOLEAN;
    language_exists BOOLEAN;
    episode_id_exists BOOLEAN;
BEGIN
    -- Check if columns exist
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'core' 
        AND table_name = 'documents' 
        AND column_name = 'document_type'
    ) INTO doc_type_exists;
    
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'core' 
        AND table_name = 'documents' 
        AND column_name = 'language'
    ) INTO language_exists;
    
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'core' 
        AND table_name = 'documents' 
        AND column_name = 'episode_id'
    ) INTO episode_id_exists;
    
    -- Report results
    IF doc_type_exists AND language_exists AND episode_id_exists THEN
        RAISE NOTICE 'Migration successful: All transcript fields added to core.documents';
    ELSE
        RAISE EXCEPTION 'Migration failed: Not all fields were created';
    END IF;
END $$;

-- =====================================================================
-- USAGE EXAMPLES
-- =====================================================================

-- Example: Insert a podcast transcript
-- INSERT INTO core.documents (
--     filename, 
--     spaces_url, 
--     content, 
--     document_type, 
--     language, 
--     episode_id
-- ) VALUES (
--     'insurance-dudes-ep-001.txt',
--     'https://spaces.example.com/transcripts/ep001.txt',
--     'Episode transcript content here...',
--     'transcript',
--     'en',
--     'EP-001-2024-10-08'
-- );

-- Example: Query all transcripts
-- SELECT * FROM core.documents 
-- WHERE document_type = 'transcript';

-- Example: Find transcript by episode
-- SELECT * FROM core.documents 
-- WHERE episode_id = 'EP-001-2024-10-08';

-- Example: Find all Spanish transcripts
-- SELECT * FROM core.documents 
-- WHERE document_type = 'transcript' 
-- AND language = 'es';