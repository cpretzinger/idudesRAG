-- FIXED SCHEMA - No ALTER SYSTEM, Correct User Permissions
-- Enable pgvector
CREATE EXTENSION IF NOT EXISTS vector;

-- Use the core schema
CREATE SCHEMA IF NOT EXISTS core;

-- 1. DOCUMENTS TABLE - Store your content
CREATE TABLE IF NOT EXISTS core.documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    filename VARCHAR(255),
    spaces_url TEXT,
    content TEXT NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP DEFAULT NOW()
);

-- 2. EMBEDDINGS TABLE - Store vectors for search
CREATE TABLE IF NOT EXISTS core.document_embeddings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID NOT NULL REFERENCES core.documents(id) ON DELETE CASCADE,
    chunk_text TEXT NOT NULL,                     -- FIXED: matches workflow expectation
    embedding vector(1536) NOT NULL,
    chunk_index INTEGER DEFAULT 0
);

-- HNSW INDEX for best performance (better than IVFFlat)
CREATE INDEX IF NOT EXISTS idx_embeddings_hnsw 
ON core.document_embeddings 
USING hnsw (embedding vector_cosine_ops) 
WITH (m = 16, ef_construction = 64);

-- Metadata index for filtering
CREATE INDEX IF NOT EXISTS idx_documents_metadata 
ON core.documents USING gin (metadata);

-- Filename index for file-based searches
CREATE INDEX IF NOT EXISTS idx_documents_filename 
ON core.documents (filename);

-- Grant permissions to current user (craigpretzinger)
GRANT SELECT, INSERT, UPDATE, DELETE ON core.documents TO craigpretzinger;
GRANT SELECT, INSERT, UPDATE, DELETE ON core.document_embeddings TO craigpretzinger;
GRANT USAGE ON SCHEMA core TO craigpretzinger;

-- Grant permissions to postgres user (for n8n workflows)
GRANT SELECT, INSERT, UPDATE, DELETE ON core.documents TO postgres;
GRANT SELECT, INSERT, UPDATE, DELETE ON core.document_embeddings TO postgres;
GRANT USAGE ON SCHEMA core TO postgres;

-- Create optimized search function
CREATE OR REPLACE FUNCTION core.search_documents(
    query_embedding vector(1536),
    similarity_threshold float DEFAULT 0.7,
    result_limit integer DEFAULT 10
)
RETURNS TABLE (
    document_id UUID,
    filename VARCHAR(255),
    spaces_url TEXT,
    chunk_text TEXT,
    similarity FLOAT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        d.id,
        d.filename,
        d.spaces_url,
        de.chunk_text,
        (1 - (de.embedding <=> query_embedding))::FLOAT as sim
    FROM core.document_embeddings de
    JOIN core.documents d ON d.id = de.document_id
    WHERE (1 - (de.embedding <=> query_embedding)) > similarity_threshold
    ORDER BY de.embedding <=> query_embedding
    LIMIT result_limit;
END;
$$ LANGUAGE plpgsql;

-- Grant execute on function
GRANT EXECUTE ON FUNCTION core.search_documents TO craigpretzinger;
GRANT EXECUTE ON FUNCTION core.search_documents TO postgres;