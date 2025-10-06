-- OPTIMIZED SEARCH QUERY FOR n8n WORKFLOW
-- This query matches your workflow requirements exactly but with better performance

-- Option 1: Direct query (what your workflow currently uses)
-- Replace your current query with this optimized version:

SELECT 
    d.id as document_id,
    d.filename,
    d.spaces_url,
    de.chunk_text,
    (1 - (de.embedding <=> $1::vector))::FLOAT as similarity
FROM core.document_embeddings de
JOIN core.documents d ON d.id = de.document_id
WHERE (1 - (de.embedding <=> $1::vector)) > $2
ORDER BY de.embedding <=> $1::vector
LIMIT $3;

-- Option 2: Using the optimized function (recommended)
-- Replace the above query with this function call for even better performance:

SELECT * FROM core.search_documents(
    $1::vector(1536),  -- query embedding
    $2::FLOAT,         -- similarity threshold
    $3::INTEGER        -- result limit
);

-- Option 3: Advanced search with filters (for future enhancements)
-- You can extend your workflow to include file type and metadata filters:

SELECT * FROM core.search_documents(
    $1::vector(1536),        -- query embedding
    $2::FLOAT,               -- similarity threshold  
    $3::INTEGER,             -- result limit
    $4::VARCHAR,             -- file_type_filter (optional, pass NULL if not needed)
    $5::JSONB                -- metadata_filter (optional, pass NULL if not needed)
);

-- Example with filters:
-- SELECT * FROM core.search_documents(
--     '[0.1,0.2,...]'::vector(1536),
--     0.7,
--     10,
--     'application/pdf',       -- only PDFs
--     '{"category": "legal"}'  -- only legal documents
-- );

-- Performance monitoring query (run periodically to check index usage):
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes 
WHERE schemaname = 'core' 
    AND tablename IN ('documents', 'document_embeddings')
ORDER BY idx_scan DESC;

-- Query to check embedding distribution and quality:
SELECT 
    COUNT(*) as total_embeddings,
    AVG(LENGTH(chunk_text)) as avg_chunk_length,
    MIN(LENGTH(chunk_text)) as min_chunk_length,
    MAX(LENGTH(chunk_text)) as max_chunk_length,
    COUNT(DISTINCT document_id) as unique_documents
FROM core.document_embeddings;