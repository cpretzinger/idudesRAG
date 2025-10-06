-- SIMPLEST POSSIBLE DOCUMENT RAG SCHEMA
-- Just 2 tables: documents and embeddings

-- Enable pgvector
CREATE EXTENSION IF NOT EXISTS vector;

-- Use the core schema as per your requirements
CREATE SCHEMA IF NOT EXISTS core;

-- 1. DOCUMENTS TABLE - Store your content
CREATE TABLE core.documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content TEXT NOT NULL,                          -- The actual document text
    metadata JSONB DEFAULT '{}'::jsonb,            -- Any extra info you want
    created_at TIMESTAMP DEFAULT NOW()
);

-- 2. EMBEDDINGS TABLE - Store vectors for search
CREATE TABLE core.document_embeddings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID NOT NULL REFERENCES core.documents(id) ON DELETE CASCADE,
    chunk TEXT NOT NULL,                           -- Text chunk that was embedded
    embedding vector(1536) NOT NULL,               -- OpenAI embedding vector
    chunk_index INTEGER DEFAULT 0                  -- Order of chunks in document
);

-- ONLY INDEX YOU NEED - For fast vector search
CREATE INDEX idx_embeddings_vector ON core.document_embeddings 
    USING ivfflat (embedding vector_cosine_ops) 
    WITH (lists = 100);

-- That's it. Done.