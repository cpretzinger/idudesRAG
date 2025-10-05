-- SIMPLEST POSSIBLE QUERIES FOR DOCUMENT OPERATIONS

-- ============================================
-- 1. INSERT A DOCUMENT
-- ============================================
INSERT INTO core.documents (content, metadata)
VALUES (
    'Your document text here',
    '{"source": "upload", "title": "My Document"}'::jsonb
)
RETURNING id;

-- ============================================
-- 2. INSERT EMBEDDINGS (after chunking)
-- ============================================
INSERT INTO core.document_embeddings (document_id, chunk, embedding, chunk_index)
VALUES (
    'document-uuid-here',
    'This is the text chunk',
    '[0.1, 0.2, 0.3, ...]'::vector,  -- Your 1536-dim embedding
    0
);

-- ============================================
-- 3. SEARCH DOCUMENTS (The Money Query)
-- ============================================
-- This finds the 10 most similar chunks to your query embedding
SELECT 
    de.chunk,
    d.metadata->>'title' as title,
    1 - (de.embedding <=> $1::vector) as similarity
FROM core.document_embeddings de
JOIN core.documents d ON d.id = de.document_id
WHERE 1 - (de.embedding <=> $1::vector) > 0.7  -- Similarity threshold
ORDER BY de.embedding <=> $1::vector
LIMIT 10;

-- ============================================
-- 4. DELETE A DOCUMENT (cascades to embeddings)
-- ============================================
DELETE FROM core.documents WHERE id = 'document-uuid-here';

-- That's all you need!