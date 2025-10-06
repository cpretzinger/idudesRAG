-- OPTIMIZED RAG SCHEMA FOR n8n INTEGRATION
-- Solves all identified problems and matches workflow expectations exactly

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;  -- For full-text search
CREATE EXTENSION IF NOT EXISTS btree_gin; -- For metadata indexing

-- Use the core schema as per requirements
CREATE SCHEMA IF NOT EXISTS core;

-- 1. DOCUMENTS TABLE - Enhanced for workflow requirements
CREATE TABLE core.documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    filename VARCHAR(255) NOT NULL,                    -- Required by workflow
    spaces_url TEXT NOT NULL,                          -- Required by workflow  
    content TEXT NOT NULL,                             -- The actual document text
    file_size BIGINT,                                  -- File size in bytes
    file_type VARCHAR(50),                             -- MIME type or extension
    upload_date TIMESTAMP DEFAULT NOW(),
    metadata JSONB DEFAULT '{}'::jsonb,                -- Flexible metadata storage
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- 2. DOCUMENT_EMBEDDINGS TABLE - Matches workflow field expectations
CREATE TABLE core.document_embeddings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID NOT NULL,
    chunk_text TEXT NOT NULL,                          -- Matches workflow expectation (not "chunk")
    embedding vector(1536) NOT NULL,                   -- OpenAI embedding vector
    chunk_index INTEGER NOT NULL DEFAULT 0,            -- Order of chunks in document
    chunk_size INTEGER,                                -- Length of chunk for analytics
    created_at TIMESTAMP DEFAULT NOW(),
    
    -- Foreign key with proper cascade
    CONSTRAINT fk_document_embeddings_document_id 
        FOREIGN KEY (document_id) 
        REFERENCES core.documents(id) 
        ON DELETE CASCADE
);

-- 3. PERFORMANCE INDEXES

-- HNSW index for ultra-fast vector similarity search (replaces IVFFlat)
-- HNSW is superior for high-dimensional vectors and provides better recall
CREATE INDEX idx_embeddings_hnsw ON core.document_embeddings 
    USING hnsw (embedding vector_cosine_ops) 
    WITH (m = 16, ef_construction = 64);

-- Alternative distance functions for different use cases
CREATE INDEX idx_embeddings_l2 ON core.document_embeddings 
    USING hnsw (embedding vector_l2_ops) 
    WITH (m = 16, ef_construction = 64);

-- Standard B-tree indexes for fast joins and filtering
CREATE INDEX idx_document_embeddings_document_id ON core.document_embeddings(document_id);
CREATE INDEX idx_document_embeddings_chunk_index ON core.document_embeddings(document_id, chunk_index);
CREATE INDEX idx_documents_filename ON core.documents(filename);
CREATE INDEX idx_documents_file_type ON core.documents(file_type);
CREATE INDEX idx_documents_upload_date ON core.documents(upload_date DESC);

-- 4. METADATA INDEXING for advanced filtering
-- GIN index for JSONB metadata queries
CREATE INDEX idx_documents_metadata_gin ON core.documents USING gin(metadata);

-- 5. FULL-TEXT SEARCH INTEGRATION
-- GIN index for full-text search on document content
CREATE INDEX idx_documents_content_fts ON core.documents 
    USING gin(to_tsvector('english', content));

-- GIN index for full-text search on chunk text
CREATE INDEX idx_embeddings_chunk_text_fts ON core.document_embeddings 
    USING gin(to_tsvector('english', chunk_text));

-- Trigram index for fuzzy text matching on filenames
CREATE INDEX idx_documents_filename_trgm ON core.documents 
    USING gin(filename gin_trgm_ops);

-- 6. CONSTRAINTS AND SECURITY

-- Check constraints for data validation
ALTER TABLE core.documents 
    ADD CONSTRAINT chk_filename_not_empty CHECK (filename != ''),
    ADD CONSTRAINT chk_spaces_url_not_empty CHECK (spaces_url != ''),
    ADD CONSTRAINT chk_content_not_empty CHECK (content != ''),
    ADD CONSTRAINT chk_file_size_positive CHECK (file_size IS NULL OR file_size >= 0);

ALTER TABLE core.document_embeddings 
    ADD CONSTRAINT chk_chunk_text_not_empty CHECK (chunk_text != ''),
    ADD CONSTRAINT chk_chunk_index_non_negative CHECK (chunk_index >= 0),
    ADD CONSTRAINT chk_chunk_size_positive CHECK (chunk_size IS NULL OR chunk_size > 0);

-- Unique constraint to prevent duplicate embeddings
ALTER TABLE core.document_embeddings 
    ADD CONSTRAINT uq_document_chunk_index UNIQUE (document_id, chunk_index);

-- 7. ROW LEVEL SECURITY (Optional - uncomment if needed)
-- ALTER TABLE core.documents ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE core.document_embeddings ENABLE ROW LEVEL SECURITY;

-- 8. UPDATED_AT TRIGGER for documents table
CREATE OR REPLACE FUNCTION core.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER trigger_documents_updated_at 
    BEFORE UPDATE ON core.documents 
    FOR EACH ROW 
    EXECUTE FUNCTION core.update_updated_at_column();

-- 9. OPTIMIZED SEARCH FUNCTION
-- This function matches your workflow query exactly but with better performance
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

-- 10. ANALYTICS VIEWS

-- Document statistics view
CREATE VIEW core.v_document_stats AS
SELECT 
    COUNT(*) as total_documents,
    COUNT(DISTINCT file_type) as unique_file_types,
    SUM(file_size) as total_size_bytes,
    AVG(file_size) as avg_file_size,
    MIN(upload_date) as first_upload,
    MAX(upload_date) as latest_upload
FROM core.documents;

-- Embedding statistics view  
CREATE VIEW core.v_embedding_stats AS
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

-- 11. MAINTENANCE FUNCTIONS

-- Function to reindex HNSW for optimal performance
CREATE OR REPLACE FUNCTION core.reindex_vectors()
RETURNS VOID AS $$
BEGIN
    REINDEX INDEX CONCURRENTLY core.idx_embeddings_hnsw;
    REINDEX INDEX CONCURRENTLY core.idx_embeddings_l2;
END;
$$ LANGUAGE plpgsql;

-- Function to analyze table statistics
CREATE OR REPLACE FUNCTION core.update_table_stats()
RETURNS VOID AS $$
BEGIN
    ANALYZE core.documents;
    ANALYZE core.document_embeddings;
END;
$$ LANGUAGE plpgsql;

-- 12. PERFORMANCE TUNING SETTINGS
-- Optimize for vector operations
ALTER SYSTEM SET effective_cache_size = '4GB';
ALTER SYSTEM SET random_page_cost = 1.1;
ALTER SYSTEM SET seq_page_cost = 1.0;

-- Comments for documentation
COMMENT ON TABLE core.documents IS 'Stores document metadata and content for RAG system';
COMMENT ON TABLE core.document_embeddings IS 'Stores vector embeddings for semantic search';
COMMENT ON FUNCTION core.search_documents IS 'Optimized semantic search function matching n8n workflow requirements';
COMMENT ON INDEX core.idx_embeddings_hnsw IS 'HNSW index for ultra-fast vector similarity search';

-- Grant permissions (adjust as needed for your application user)
-- GRANT SELECT, INSERT, UPDATE, DELETE ON core.documents TO your_app_user;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON core.document_embeddings TO your_app_user;
-- GRANT EXECUTE ON FUNCTION core.search_documents TO your_app_user;