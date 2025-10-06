-- MIGRATION STRATEGY: Simple Schema → Optimized RAG Schema
-- Safe, zero-downtime migration with rollback capability

-- =====================================
-- PHASE 1: BACKUP AND PREPARATION
-- =====================================

-- 1. Create backup tables
CREATE TABLE IF NOT EXISTS core.documents_backup AS 
SELECT * FROM core.documents;

CREATE TABLE IF NOT EXISTS core.document_embeddings_backup AS 
SELECT * FROM core.document_embeddings;

-- 2. Check current data state
DO $$
DECLARE
    doc_count INTEGER;
    embed_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO doc_count FROM core.documents;
    SELECT COUNT(*) INTO embed_count FROM core.document_embeddings;
    
    RAISE NOTICE 'Current state: % documents, % embeddings', doc_count, embed_count;
    
    -- Log migration start
    INSERT INTO core.migration_log (migration_name, phase, status, details, created_at)
    VALUES ('simple_to_optimized_rag', 'backup', 'completed', 
            format('Backed up %s documents and %s embeddings', doc_count, embed_count), 
            NOW());
END $$;

-- =====================================
-- PHASE 2: ADD MISSING COLUMNS
-- =====================================

-- Add missing columns to documents table
ALTER TABLE core.documents 
    ADD COLUMN IF NOT EXISTS filename VARCHAR(255),
    ADD COLUMN IF NOT EXISTS spaces_url TEXT,
    ADD COLUMN IF NOT EXISTS file_size BIGINT,
    ADD COLUMN IF NOT EXISTS file_type VARCHAR(50),
    ADD COLUMN IF NOT EXISTS upload_date TIMESTAMP DEFAULT NOW(),
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT NOW();

-- Rename chunk to chunk_text in embeddings table
DO $$
BEGIN
    -- Check if old column exists and new doesn't
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_schema = 'core' 
               AND table_name = 'document_embeddings' 
               AND column_name = 'chunk')
    AND NOT EXISTS (SELECT 1 FROM information_schema.columns 
                    WHERE table_schema = 'core' 
                    AND table_name = 'document_embeddings' 
                    AND column_name = 'chunk_text') THEN
        
        ALTER TABLE core.document_embeddings RENAME COLUMN chunk TO chunk_text;
        RAISE NOTICE 'Renamed chunk column to chunk_text';
    END IF;
END $$;

-- Add missing columns to embeddings table
ALTER TABLE core.document_embeddings 
    ADD COLUMN IF NOT EXISTS chunk_size INTEGER;

-- =====================================
-- PHASE 3: POPULATE MISSING DATA
-- =====================================

-- Populate missing filename and spaces_url from metadata or generate defaults
UPDATE core.documents 
SET 
    filename = COALESCE(
        metadata->>'filename',
        metadata->>'original_name', 
        'document_' || id::text || '.txt'
    ),
    spaces_url = COALESCE(
        metadata->>'spaces_url',
        metadata->>'url',
        'https://datainjestion.nyc3.cdn.digitaloceanspaces.com/' || 
        COALESCE(metadata->>'filename', 'document_' || id::text || '.txt')
    ),
    file_type = COALESCE(
        metadata->>'file_type',
        metadata->>'content_type',
        'text/plain'
    ),
    file_size = COALESCE(
        (metadata->>'file_size')::BIGINT,
        LENGTH(content)
    ),
    upload_date = COALESCE(created_at, NOW()),
    updated_at = NOW()
WHERE filename IS NULL OR spaces_url IS NULL;

-- Populate chunk_size in embeddings
UPDATE core.document_embeddings 
SET chunk_size = LENGTH(chunk_text)
WHERE chunk_size IS NULL;

-- =====================================
-- PHASE 4: ADD CONSTRAINTS SAFELY
-- =====================================

-- Add NOT NULL constraints after data population
ALTER TABLE core.documents 
    ALTER COLUMN filename SET NOT NULL,
    ALTER COLUMN spaces_url SET NOT NULL;

-- Add check constraints
ALTER TABLE core.documents 
    ADD CONSTRAINT IF NOT EXISTS chk_filename_not_empty CHECK (filename != ''),
    ADD CONSTRAINT IF NOT EXISTS chk_spaces_url_not_empty CHECK (spaces_url != ''),
    ADD CONSTRAINT IF NOT EXISTS chk_content_not_empty CHECK (content != ''),
    ADD CONSTRAINT IF NOT EXISTS chk_file_size_positive CHECK (file_size IS NULL OR file_size >= 0);

ALTER TABLE core.document_embeddings 
    ADD CONSTRAINT IF NOT EXISTS chk_chunk_text_not_empty CHECK (chunk_text != ''),
    ADD CONSTRAINT IF NOT EXISTS chk_chunk_index_non_negative CHECK (chunk_index >= 0),
    ADD CONSTRAINT IF NOT EXISTS chk_chunk_size_positive CHECK (chunk_size IS NULL OR chunk_size > 0);

-- Add unique constraint for chunk index
ALTER TABLE core.document_embeddings 
    ADD CONSTRAINT IF NOT EXISTS uq_document_chunk_index UNIQUE (document_id, chunk_index);

-- =====================================
-- PHASE 5: UPGRADE INDEXES
-- =====================================

-- Drop old IVFFlat index
DROP INDEX IF EXISTS core.idx_embeddings_vector;

-- Create new HNSW indexes
CREATE INDEX IF NOT EXISTS idx_embeddings_hnsw ON core.document_embeddings 
    USING hnsw (embedding vector_cosine_ops) 
    WITH (m = 16, ef_construction = 64);

-- Add all other performance indexes
CREATE INDEX IF NOT EXISTS idx_document_embeddings_document_id ON core.document_embeddings(document_id);
CREATE INDEX IF NOT EXISTS idx_document_embeddings_chunk_index ON core.document_embeddings(document_id, chunk_index);
CREATE INDEX IF NOT EXISTS idx_documents_filename ON core.documents(filename);
CREATE INDEX IF NOT EXISTS idx_documents_file_type ON core.documents(file_type);
CREATE INDEX IF NOT EXISTS idx_documents_upload_date ON core.documents(upload_date DESC);

-- Metadata and full-text search indexes
CREATE INDEX IF NOT EXISTS idx_documents_metadata_gin ON core.documents USING gin(metadata);
CREATE INDEX IF NOT EXISTS idx_documents_content_fts ON core.documents 
    USING gin(to_tsvector('english', content));
CREATE INDEX IF NOT EXISTS idx_embeddings_chunk_text_fts ON core.document_embeddings 
    USING gin(to_tsvector('english', chunk_text));
CREATE INDEX IF NOT EXISTS idx_documents_filename_trgm ON core.documents 
    USING gin(filename gin_trgm_ops);

-- =====================================
-- PHASE 6: CREATE FUNCTIONS AND VIEWS
-- =====================================

-- Updated trigger function
CREATE OR REPLACE FUNCTION core.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger if it doesn't exist
DROP TRIGGER IF EXISTS trigger_documents_updated_at ON core.documents;
CREATE TRIGGER trigger_documents_updated_at 
    BEFORE UPDATE ON core.documents 
    FOR EACH ROW 
    EXECUTE FUNCTION core.update_updated_at_column();

-- Create optimized search function
CREATE OR REPLACE FUNCTION core.search_documents(
    query_embedding vector(1536),
    similarity_threshold FLOAT DEFAULT 0.7,
    result_limit INTEGER DEFAULT 10,
    file_type_filter VARCHAR DEFAULT NULL,
    metadata_filter JSONB DEFAULT NULL
)
RETURNS TABLE (
    document_id UUID,
    filename VARCHAR,
    spaces_url TEXT,
    chunk_text TEXT,
    similarity FLOAT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        d.id as document_id,
        d.filename,
        d.spaces_url,
        de.chunk_text,
        (1 - (de.embedding <=> query_embedding))::FLOAT as similarity
    FROM core.document_embeddings de
    JOIN core.documents d ON d.id = de.document_id
    WHERE 
        (1 - (de.embedding <=> query_embedding)) > similarity_threshold
        AND (file_type_filter IS NULL OR d.file_type = file_type_filter)
        AND (metadata_filter IS NULL OR d.metadata @> metadata_filter)
    ORDER BY de.embedding <=> query_embedding
    LIMIT result_limit;
END;
$$ LANGUAGE plpgsql;

-- Create analytics views
CREATE OR REPLACE VIEW core.v_document_stats AS
SELECT 
    COUNT(*) as total_documents,
    COUNT(DISTINCT file_type) as unique_file_types,
    SUM(file_size) as total_size_bytes,
    AVG(file_size) as avg_file_size,
    MIN(upload_date) as first_upload,
    MAX(upload_date) as latest_upload
FROM core.documents;

CREATE OR REPLACE VIEW core.v_embedding_stats AS
SELECT 
    d.filename,
    d.file_type,
    COUNT(de.id) as chunk_count,
    AVG(de.chunk_size) as avg_chunk_size,
    d.file_size,
    d.upload_date
FROM core.documents d
LEFT JOIN core.document_embeddings de ON d.id = de.document_id
GROUP BY d.id, d.filename, d.file_type, d.file_size, d.upload_date
ORDER BY d.upload_date DESC;

-- =====================================
-- PHASE 7: VALIDATION AND CLEANUP
-- =====================================

-- Validate migration
DO $$
DECLARE
    doc_count INTEGER;
    embed_count INTEGER;
    missing_filename_count INTEGER;
    missing_spaces_url_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO doc_count FROM core.documents;
    SELECT COUNT(*) INTO embed_count FROM core.document_embeddings;
    SELECT COUNT(*) INTO missing_filename_count FROM core.documents WHERE filename IS NULL;
    SELECT COUNT(*) INTO missing_spaces_url_count FROM core.documents WHERE spaces_url IS NULL;
    
    RAISE NOTICE 'Migration validation: % documents, % embeddings', doc_count, embed_count;
    RAISE NOTICE 'Missing data: % without filename, % without spaces_url', 
                 missing_filename_count, missing_spaces_url_count;
    
    -- Log successful migration
    INSERT INTO core.migration_log (migration_name, phase, status, details, created_at)
    VALUES ('simple_to_optimized_rag', 'validation', 'completed', 
            format('Migration successful: %s documents, %s embeddings, %s missing filenames, %s missing URLs', 
                   doc_count, embed_count, missing_filename_count, missing_spaces_url_count), 
            NOW());
    
    IF missing_filename_count > 0 OR missing_spaces_url_count > 0 THEN
        RAISE WARNING 'Some documents still have missing required fields. Check data integrity.';
    ELSE
        RAISE NOTICE 'Migration completed successfully! All required fields populated.';
    END IF;
END $$;

-- Test the optimized search function
SELECT core.search_documents(
    '[0.1,0.2,0.3]'::vector(3), -- dummy vector for test
    0.5, -- similarity threshold
    5    -- limit
);

-- =====================================
-- ROLLBACK SCRIPT (USE ONLY IF NEEDED)
-- =====================================

/*
-- EMERGENCY ROLLBACK - Only run if migration fails
-- This restores the original simple schema

DROP TABLE IF EXISTS core.documents CASCADE;
DROP TABLE IF EXISTS core.document_embeddings CASCADE;

-- Restore from backup
CREATE TABLE core.documents AS SELECT * FROM core.documents_backup;
CREATE TABLE core.document_embeddings AS SELECT * FROM core.document_embeddings_backup;

-- Restore original indexes
CREATE INDEX idx_embeddings_vector ON core.document_embeddings 
    USING ivfflat (embedding vector_cosine_ops) 
    WITH (lists = 100);

-- Log rollback
INSERT INTO core.migration_log (migration_name, phase, status, details, created_at)
VALUES ('simple_to_optimized_rag', 'rollback', 'completed', 'Migration rolled back to simple schema', NOW());
*/