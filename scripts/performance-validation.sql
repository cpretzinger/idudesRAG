-- PERFORMANCE VALIDATION AND TESTING SCRIPTS
-- Run these after migration to ensure optimal performance

-- =====================================
-- 1. INDEX HEALTH CHECK
-- =====================================

-- Check all indexes are created and being used
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan as times_used,
    idx_tup_read as tuples_read,
    idx_tup_fetch as tuples_fetched,
    CASE 
        WHEN idx_scan = 0 THEN 'UNUSED'
        WHEN idx_scan < 10 THEN 'LOW_USAGE'
        ELSE 'ACTIVE'
    END as status
FROM pg_stat_user_indexes 
WHERE schemaname = 'core' 
    AND tablename IN ('documents', 'document_embeddings')
ORDER BY idx_scan DESC;

-- =====================================
-- 2. VECTOR INDEX PERFORMANCE TEST
-- =====================================

-- Test HNSW vs IVFFlat performance (if you still have old index)
EXPLAIN (ANALYZE, BUFFERS) 
SELECT 
    d.id as document_id,
    d.filename,
    d.spaces_url,
    de.chunk_text,
    (1 - (de.embedding <=> '[0.1,0.2,0.3,0.4,0.5]'::vector)) as similarity
FROM core.document_embeddings de
JOIN core.documents d ON d.id = de.document_id
WHERE (1 - (de.embedding <=> '[0.1,0.2,0.3,0.4,0.5]'::vector)) > 0.7
ORDER BY de.embedding <=> '[0.1,0.2,0.3,0.4,0.5]'::vector
LIMIT 10;

-- =====================================
-- 3. SEARCH FUNCTION PERFORMANCE TEST
-- =====================================

-- Test the optimized search function
EXPLAIN (ANALYZE, BUFFERS, COSTS)
SELECT * FROM core.search_documents(
    '[0.1,0.2,0.3,0.4,0.5]'::vector(1536),
    0.7,
    10
);

-- =====================================
-- 4. DATA QUALITY VALIDATION
-- =====================================

-- Check for missing required fields
SELECT 
    'Documents missing filename' as issue,
    COUNT(*) as count
FROM core.documents 
WHERE filename IS NULL OR filename = ''
UNION ALL
SELECT 
    'Documents missing spaces_url' as issue,
    COUNT(*) as count
FROM core.documents 
WHERE spaces_url IS NULL OR spaces_url = ''
UNION ALL
SELECT 
    'Embeddings missing chunk_text' as issue,
    COUNT(*) as count
FROM core.document_embeddings 
WHERE chunk_text IS NULL OR chunk_text = ''
UNION ALL
SELECT 
    'Orphaned embeddings' as issue,
    COUNT(*) as count
FROM core.document_embeddings de
LEFT JOIN core.documents d ON de.document_id = d.id
WHERE d.id IS NULL;

-- =====================================
-- 5. STORAGE AND DISTRIBUTION ANALYSIS
-- =====================================

-- Table sizes and row counts
SELECT 
    schemaname,
    tablename,
    n_tup_ins as inserts,
    n_tup_upd as updates,
    n_tup_del as deletes,
    n_live_tup as live_rows,
    n_dead_tup as dead_rows,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as total_size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) as table_size
FROM pg_stat_user_tables 
WHERE schemaname = 'core' 
    AND tablename IN ('documents', 'document_embeddings');

-- Embedding vector distribution
SELECT 
    d.file_type,
    COUNT(*) as document_count,
    COUNT(de.id) as embedding_count,
    AVG(LENGTH(de.chunk_text))::INTEGER as avg_chunk_length,
    AVG(de.chunk_size)::INTEGER as avg_chunk_size
FROM core.documents d
LEFT JOIN core.document_embeddings de ON d.id = de.document_id
GROUP BY d.file_type
ORDER BY document_count DESC;

-- =====================================
-- 6. BENCHMARK DIFFERENT QUERY PATTERNS
-- =====================================

-- Benchmark 1: Direct vector search (current n8n workflow)
\timing on
SELECT COUNT(*) FROM (
    SELECT 
        d.id as document_id,
        d.filename,
        d.spaces_url,
        de.chunk_text,
        (1 - (de.embedding <=> '[0.1,0.2,0.3,0.4,0.5]'::vector)) as similarity
    FROM core.document_embeddings de
    JOIN core.documents d ON d.id = de.document_id
    WHERE (1 - (de.embedding <=> '[0.1,0.2,0.3,0.4,0.5]'::vector)) > 0.7
    ORDER BY de.embedding <=> '[0.1,0.2,0.3,0.4,0.5]'::vector
    LIMIT 10
) sub;

-- Benchmark 2: Function-based search
SELECT COUNT(*) FROM (
    SELECT * FROM core.search_documents(
        '[0.1,0.2,0.3,0.4,0.5]'::vector(1536),
        0.7,
        10
    )
) sub;

-- Benchmark 3: Search with filters
SELECT COUNT(*) FROM (
    SELECT * FROM core.search_documents(
        '[0.1,0.2,0.3,0.4,0.5]'::vector(1536),
        0.7,
        10,
        NULL,  -- no file type filter
        '{"test": true}'::jsonb  -- metadata filter
    )
) sub;
\timing off

-- =====================================
-- 7. MEMORY AND CACHE ANALYSIS
-- =====================================

-- Check buffer cache usage
SELECT 
    schemaname,
    tablename,
    heap_blks_read,
    heap_blks_hit,
    CASE 
        WHEN heap_blks_hit + heap_blks_read = 0 THEN 0
        ELSE (heap_blks_hit::FLOAT / (heap_blks_hit + heap_blks_read) * 100)::DECIMAL(5,2)
    END as cache_hit_ratio
FROM pg_statio_user_tables 
WHERE schemaname = 'core'
    AND tablename IN ('documents', 'document_embeddings');

-- =====================================
-- 8. MAINTENANCE RECOMMENDATIONS
-- =====================================

-- Check if tables need vacuuming
SELECT 
    schemaname,
    tablename,
    n_dead_tup,
    n_live_tup,
    CASE 
        WHEN n_live_tup = 0 THEN 0
        ELSE (n_dead_tup::FLOAT / n_live_tup * 100)::DECIMAL(5,2)
    END as dead_tuple_ratio,
    last_vacuum,
    last_autovacuum,
    CASE 
        WHEN (n_dead_tup::FLOAT / NULLIF(n_live_tup, 0) * 100) > 20 THEN 'VACUUM NEEDED'
        ELSE 'OK'
    END as recommendation
FROM pg_stat_user_tables 
WHERE schemaname = 'core'
    AND tablename IN ('documents', 'document_embeddings');

-- =====================================
-- 9. VECTOR SEARCH QUALITY TEST
-- =====================================

-- Test search quality with sample queries
WITH test_embeddings AS (
    SELECT embedding, chunk_text 
    FROM core.document_embeddings 
    LIMIT 5
),
search_results AS (
    SELECT 
        te.chunk_text as original_text,
        sr.*
    FROM test_embeddings te,
    LATERAL core.search_documents(
        te.embedding,
        0.5,  -- lower threshold for testing
        3
    ) sr
)
SELECT 
    original_text,
    chunk_text as found_text,
    similarity,
    CASE 
        WHEN similarity > 0.95 THEN 'EXCELLENT'
        WHEN similarity > 0.8 THEN 'GOOD'
        WHEN similarity > 0.6 THEN 'FAIR'
        ELSE 'POOR'
    END as quality_rating
FROM search_results
ORDER BY similarity DESC;

-- =====================================
-- 10. FINAL PERFORMANCE SUMMARY
-- =====================================

-- Generate performance summary report
SELECT 
    'Performance Validation Summary' as report_title,
    NOW() as generated_at;

SELECT 
    'Table Statistics' as section,
    t.tablename,
    t.n_live_tup as row_count,
    pg_size_pretty(pg_total_relation_size('core.' || t.tablename)) as size,
    COALESCE(i.index_count, 0) as index_count
FROM pg_stat_user_tables t
LEFT JOIN (
    SELECT 
        tablename, 
        COUNT(*) as index_count
    FROM pg_stat_user_indexes 
    WHERE schemaname = 'core'
    GROUP BY tablename
) i ON t.tablename = i.tablename
WHERE t.schemaname = 'core' 
    AND t.tablename IN ('documents', 'document_embeddings');

-- Check that workflow requirements are met
SELECT 
    'Workflow Compatibility Check' as section,
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.columns 
                    WHERE table_schema = 'core' 
                    AND table_name = 'documents' 
                    AND column_name = 'filename') THEN 'PASS'
        ELSE 'FAIL'
    END as filename_field,
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.columns 
                    WHERE table_schema = 'core' 
                    AND table_name = 'documents' 
                    AND column_name = 'spaces_url') THEN 'PASS'
        ELSE 'FAIL'
    END as spaces_url_field,
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.columns 
                    WHERE table_schema = 'core' 
                    AND table_name = 'document_embeddings' 
                    AND column_name = 'chunk_text') THEN 'PASS'
        ELSE 'FAIL'
    END as chunk_text_field,
    CASE 
        WHEN EXISTS (SELECT 1 FROM pg_indexes 
                    WHERE schemaname = 'core' 
                    AND tablename = 'document_embeddings' 
                    AND indexname LIKE '%hnsw%') THEN 'HNSW'
        WHEN EXISTS (SELECT 1 FROM pg_indexes 
                    WHERE schemaname = 'core' 
                    AND tablename = 'document_embeddings' 
                    AND indexname LIKE '%ivfflat%') THEN 'IVFFLAT'
        ELSE 'NO_VECTOR_INDEX'
    END as vector_index_type;