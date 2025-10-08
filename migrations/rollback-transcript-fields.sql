-- =====================================================================
-- ROLLBACK MIGRATION: Remove Transcript-Specific Fields from Documents
-- Purpose: Reverse the add-transcript-fields.sql migration
-- Date: 2025-10-08
-- =====================================================================

-- WARNING: This will permanently delete all transcript-specific data
-- Make sure to backup your data before running this rollback

BEGIN;

-- =====================================================================
-- DROP INDEXES (in reverse order of creation)
-- =====================================================================

-- Drop transcript-specific indexes
DROP INDEX IF EXISTS core.idx_documents_language;
DROP INDEX IF EXISTS core.idx_documents_type_episode;
DROP INDEX IF EXISTS core.idx_documents_episode_id;
DROP INDEX IF EXISTS core.idx_documents_document_type;

-- =====================================================================
-- DROP CONSTRAINTS
-- =====================================================================

-- Drop check constraints
ALTER TABLE core.documents 
    DROP CONSTRAINT IF EXISTS chk_language_format;

ALTER TABLE core.documents 
    DROP CONSTRAINT IF EXISTS chk_document_type;

-- =====================================================================
-- DROP COLUMNS
-- =====================================================================

-- Drop the three transcript-specific columns
ALTER TABLE core.documents 
    DROP COLUMN IF EXISTS episode_id,
    DROP COLUMN IF EXISTS language,
    DROP COLUMN IF EXISTS document_type;

-- =====================================================================
-- VERIFICATION
-- =====================================================================

-- Verify the rollback succeeded
DO $$
DECLARE
    doc_type_exists BOOLEAN;
    language_exists BOOLEAN;
    episode_id_exists BOOLEAN;
BEGIN
    -- Check if columns still exist (they shouldn't)
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
    IF NOT doc_type_exists AND NOT language_exists AND NOT episode_id_exists THEN
        RAISE NOTICE 'Rollback successful: All transcript fields removed from core.documents';
    ELSE
        RAISE EXCEPTION 'Rollback failed: Some fields still exist';
    END IF;
END $$;

COMMIT;

-- =====================================================================
-- POST-ROLLBACK NOTES
-- =====================================================================

-- After running this rollback:
-- 1. All transcript-specific data will be lost
-- 2. The documents table will return to its original structure
-- 3. Any applications using these fields will need to be updated
-- 4. Consider backing up transcript data before rollback if needed