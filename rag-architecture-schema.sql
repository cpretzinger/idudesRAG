-- =====================================================================
-- PRODUCTION RAG ARCHITECTURE FOR MULTI-CONTENT SYSTEM
-- Optimized for: 800 podcasts + books + avatars + social + prompts
-- Performance: <250ms search, 90%+ accuracy, 60+ concurrent users
-- Cost target: <$0.002 per search
-- =====================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS btree_gin;

-- =====================================================================
-- CONTENT TYPE TABLES (Content-specific optimizations)
-- =====================================================================

-- 1. PODCAST EPISODES (Conversational, long-form)
CREATE TABLE core.podcast_episodes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    episode_number INTEGER,
    title TEXT NOT NULL,
    description TEXT,
    duration_seconds INTEGER,
    publish_date TIMESTAMP WITH TIME ZONE,
    hosts JSONB DEFAULT '[]'::jsonb,
    guests JSONB DEFAULT '[]'::jsonb,
    topics JSONB DEFAULT '[]'::jsonb,
    transcript_url TEXT,
    audio_url TEXT,
    season INTEGER,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. BOOKS (Structured, educational)
CREATE TABLE core.books (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    author TEXT NOT NULL,
    isbn TEXT,
    publication_date DATE,
    genre TEXT,
    page_count INTEGER,
    publisher TEXT,
    summary TEXT,
    table_of_contents JSONB DEFAULT '[]'::jsonb,
    chapters JSONB DEFAULT '[]'::jsonb,
    key_concepts JSONB DEFAULT '[]'::jsonb,
    difficulty_level INTEGER CHECK (difficulty_level BETWEEN 1 AND 5),
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. AVATARS (Persona/character data)
CREATE TABLE core.avatars (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('persona', 'character', 'expert', 'brand')),
    description TEXT,
    personality_traits JSONB DEFAULT '[]'::jsonb,
    expertise_areas JSONB DEFAULT '[]'::jsonb,
    communication_style TEXT,
    background_story TEXT,
    values JSONB DEFAULT '[]'::jsonb,
    goals JSONB DEFAULT '[]'::jsonb,
    prompt_template TEXT,
    example_responses JSONB DEFAULT '[]'::jsonb,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. SOCIAL MEDIA PLANS (Strategic content)
CREATE TABLE core.social_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_name TEXT NOT NULL,
    platform TEXT NOT NULL CHECK (platform IN ('twitter', 'linkedin', 'instagram', 'facebook', 'tiktok', 'youtube')),
    content_type TEXT CHECK (content_type IN ('post', 'story', 'reel', 'video', 'carousel', 'thread')),
    target_audience TEXT,
    objectives JSONB DEFAULT '[]'::jsonb,
    key_messages JSONB DEFAULT '[]'::jsonb,
    hashtags JSONB DEFAULT '[]'::jsonb,
    posting_schedule JSONB DEFAULT '{}'::jsonb,
    metrics_goals JSONB DEFAULT '{}'::jsonb,
    content_pillars JSONB DEFAULT '[]'::jsonb,
    brand_voice TEXT,
    call_to_action TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. PROMPTS (AI instruction templates)
CREATE TABLE core.prompts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    use_case TEXT,
    prompt_text TEXT NOT NULL,
    system_message TEXT,
    user_message_template TEXT,
    parameters JSONB DEFAULT '[]'::jsonb,
    model_config JSONB DEFAULT '{}'::jsonb,
    expected_output_format TEXT,
    examples JSONB DEFAULT '[]'::jsonb,
    tags JSONB DEFAULT '[]'::jsonb,
    effectiveness_score DECIMAL(3,2) CHECK (effectiveness_score BETWEEN 0 AND 10),
    usage_count INTEGER DEFAULT 0,
    last_used TIMESTAMP WITH TIME ZONE,
    created_by TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================================
-- CONTENT CHUNKS TABLE (Unified chunking with content-type awareness)
-- =====================================================================

CREATE TABLE core.content_chunks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content_type TEXT NOT NULL CHECK (content_type IN ('podcast', 'book', 'avatar', 'social', 'prompt')),
    content_id UUID NOT NULL,
    chunk_index INTEGER NOT NULL,
    total_chunks INTEGER NOT NULL,
    chunk_text TEXT NOT NULL,
    chunk_size INTEGER NOT NULL,
    overlap_size INTEGER DEFAULT 0,
    
    -- Content-specific metadata
    chapter_title TEXT, -- for books
    timestamp_start INTEGER, -- for podcasts (seconds)
    timestamp_end INTEGER, -- for podcasts (seconds)
    speaker TEXT, -- for podcasts
    section_type TEXT, -- for any content (intro, body, conclusion)
    
    -- Search optimization
    search_vector tsvector,
    keyword_density JSONB DEFAULT '{}'::jsonb,
    named_entities JSONB DEFAULT '[]'::jsonb,
    
    -- Vector embedding
    embedding vector(1536),
    
    -- Performance metadata
    importance_score DECIMAL(3,2) DEFAULT 5.0 CHECK (importance_score BETWEEN 0 AND 10),
    access_frequency INTEGER DEFAULT 0,
    last_accessed TIMESTAMP WITH TIME ZONE,
    
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(content_type, content_id, chunk_index)
);

-- =====================================================================
-- GRAPH RELATIONSHIPS (Lightweight for high-value connections)
-- =====================================================================

CREATE TABLE core.content_relationships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_type TEXT NOT NULL,
    source_id UUID NOT NULL,
    target_type TEXT NOT NULL,
    target_id UUID NOT NULL,
    relationship_type TEXT NOT NULL CHECK (relationship_type IN (
        'mentions', 'references', 'similar_to', 'part_of', 'continues', 
        'contradicts', 'supports', 'authored_by', 'featured_in', 'discusses'
    )),
    confidence_score DECIMAL(3,2) CHECK (confidence_score BETWEEN 0 AND 1),
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(source_type, source_id, target_type, target_id, relationship_type)
);

-- =====================================================================
-- SEARCH OPTIMIZATION TABLES
-- =====================================================================

-- Query cache for <250ms responses
CREATE TABLE core.search_cache (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    query_hash TEXT NOT NULL UNIQUE,
    query_text TEXT NOT NULL,
    content_types TEXT[] DEFAULT '{}',
    filters JSONB DEFAULT '{}'::jsonb,
    results JSONB NOT NULL,
    result_count INTEGER NOT NULL,
    execution_time_ms INTEGER NOT NULL,
    cache_hits INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Popular searches tracking
CREATE TABLE core.search_analytics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    query_text TEXT NOT NULL,
    content_types TEXT[],
    result_count INTEGER,
    execution_time_ms INTEGER,
    user_satisfaction INTEGER CHECK (user_satisfaction BETWEEN 1 AND 5),
    clicked_results JSONB DEFAULT '[]'::jsonb,
    search_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================================
-- INDEXES FOR PERFORMANCE (Target: <250ms)
-- =====================================================================

-- Content chunks primary indexes
CREATE INDEX idx_content_chunks_type_id ON core.content_chunks(content_type, content_id);
CREATE INDEX idx_content_chunks_embedding ON core.content_chunks USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
CREATE INDEX idx_content_chunks_search_vector ON core.content_chunks USING gin(search_vector);
CREATE INDEX idx_content_chunks_importance ON core.content_chunks(importance_score DESC, access_frequency DESC);
CREATE INDEX idx_content_chunks_created ON core.content_chunks(created_at DESC);

-- Content-specific indexes
CREATE INDEX idx_podcast_episodes_publish_date ON core.podcast_episodes(publish_date DESC);
CREATE INDEX idx_podcast_episodes_hosts ON core.podcast_episodes USING gin(hosts);
CREATE INDEX idx_podcast_episodes_topics ON core.podcast_episodes USING gin(topics);

CREATE INDEX idx_books_author ON core.books(author);
CREATE INDEX idx_books_genre ON core.books(genre);
CREATE INDEX idx_books_difficulty ON core.books(difficulty_level);

CREATE INDEX idx_avatars_type ON core.avatars(type);
CREATE INDEX idx_avatars_expertise ON core.avatars USING gin(expertise_areas);

CREATE INDEX idx_social_plans_platform ON core.social_plans(platform);
CREATE INDEX idx_social_plans_content_type ON core.social_plans(content_type);

CREATE INDEX idx_prompts_category ON core.prompts(category);
CREATE INDEX idx_prompts_effectiveness ON core.prompts(effectiveness_score DESC);
CREATE INDEX idx_prompts_usage ON core.prompts(usage_count DESC);

-- Relationship indexes
CREATE INDEX idx_relationships_source ON core.content_relationships(source_type, source_id);
CREATE INDEX idx_relationships_target ON core.content_relationships(target_type, target_id);
CREATE INDEX idx_relationships_type ON core.content_relationships(relationship_type);

-- Cache indexes
CREATE INDEX idx_search_cache_expires ON core.search_cache(expires_at);
CREATE INDEX idx_search_analytics_date ON core.search_analytics(search_date DESC);

-- =====================================================================
-- TRIGGERS AND FUNCTIONS
-- =====================================================================

-- Update search vector on content chunks
CREATE OR REPLACE FUNCTION core.update_content_search_vector()
RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector := to_tsvector('english', 
        COALESCE(NEW.chunk_text, '') || ' ' ||
        COALESCE(NEW.chapter_title, '') || ' ' ||
        COALESCE(NEW.speaker, '') || ' ' ||
        COALESCE(NEW.section_type, '')
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_content_chunks_search_vector
    BEFORE INSERT OR UPDATE ON core.content_chunks
    FOR EACH ROW EXECUTE FUNCTION core.update_content_search_vector();

-- Auto-expire cache entries
CREATE OR REPLACE FUNCTION core.cleanup_expired_cache()
RETURNS void AS $$
BEGIN
    DELETE FROM core.search_cache WHERE expires_at < NOW();
END;
$$ LANGUAGE plpgsql;

-- =====================================================================
-- PERFORMANCE OPTIMIZATION FUNCTIONS
-- =====================================================================

-- Hybrid search function (Vector + FTS + Graph)
CREATE OR REPLACE FUNCTION core.hybrid_search(
    p_query_text TEXT,
    p_content_types TEXT[] DEFAULT '{}',
    p_limit INTEGER DEFAULT 20,
    p_similarity_threshold FLOAT DEFAULT 0.7,
    p_include_relationships BOOLEAN DEFAULT FALSE
)
RETURNS TABLE (
    content_type TEXT,
    content_id UUID,
    chunk_id UUID,
    chunk_text TEXT,
    similarity_score FLOAT,
    fts_rank FLOAT,
    combined_score FLOAT,
    metadata JSONB,
    relationships JSONB
) AS $$
DECLARE
    query_embedding vector(1536);
    cache_key TEXT;
    cached_result JSONB;
BEGIN
    -- Generate cache key
    cache_key := md5(p_query_text || array_to_string(p_content_types, ',') || p_limit::text);
    
    -- Check cache first
    SELECT results INTO cached_result 
    FROM core.search_cache 
    WHERE query_hash = cache_key AND expires_at > NOW();
    
    IF cached_result IS NOT NULL THEN
        -- Update cache hits
        UPDATE core.search_cache 
        SET cache_hits = cache_hits + 1 
        WHERE query_hash = cache_key;
        
        -- Return cached results (implement JSON to table conversion)
        RETURN;
    END IF;
    
    -- Get query embedding (in production, this would come from application)
    -- For now, we'll use a placeholder
    
    RETURN QUERY
    WITH vector_search AS (
        SELECT 
            cc.content_type,
            cc.content_id,
            cc.id as chunk_id,
            cc.chunk_text,
            (1 - (cc.embedding <=> query_embedding)) as vector_similarity,
            cc.importance_score,
            cc.metadata
        FROM core.content_chunks cc
        WHERE (p_content_types = '{}' OR cc.content_type = ANY(p_content_types))
        AND cc.embedding IS NOT NULL
        ORDER BY cc.embedding <=> query_embedding
        LIMIT p_limit * 2
    ),
    fts_search AS (
        SELECT 
            cc.content_type,
            cc.content_id,
            cc.id as chunk_id,
            cc.chunk_text,
            ts_rank(cc.search_vector, plainto_tsquery('english', p_query_text)) as fts_score,
            cc.importance_score,
            cc.metadata
        FROM core.content_chunks cc
        WHERE (p_content_types = '{}' OR cc.content_type = ANY(p_content_types))
        AND cc.search_vector @@ plainto_tsquery('english', p_query_text)
        ORDER BY fts_score DESC
        LIMIT p_limit * 2
    ),
    combined_results AS (
        SELECT DISTINCT
            COALESCE(v.content_type, f.content_type) as content_type,
            COALESCE(v.content_id, f.content_id) as content_id,
            COALESCE(v.chunk_id, f.chunk_id) as chunk_id,
            COALESCE(v.chunk_text, f.chunk_text) as chunk_text,
            COALESCE(v.vector_similarity, 0) as vector_sim,
            COALESCE(f.fts_score, 0) as fts_score,
            -- Weighted combination: 70% vector, 30% FTS
            (COALESCE(v.vector_similarity, 0) * 0.7 + COALESCE(f.fts_score, 0) * 0.3) as combined_score,
            COALESCE(v.metadata, f.metadata) as metadata
        FROM vector_search v
        FULL OUTER JOIN fts_search f ON v.chunk_id = f.chunk_id
    )
    SELECT 
        cr.content_type::TEXT,
        cr.content_id,
        cr.chunk_id,
        cr.chunk_text::TEXT,
        cr.vector_sim,
        cr.fts_score,
        cr.combined_score,
        cr.metadata,
        CASE 
            WHEN p_include_relationships THEN
                (SELECT jsonb_agg(jsonb_build_object(
                    'type', rel.relationship_type,
                    'target_type', rel.target_type,
                    'target_id', rel.target_id,
                    'confidence', rel.confidence_score
                ))
                FROM core.content_relationships rel
                WHERE rel.source_type = cr.content_type 
                AND rel.source_id = cr.content_id)
            ELSE NULL
        END as relationships
    FROM combined_results cr
    WHERE cr.combined_score > p_similarity_threshold
    ORDER BY cr.combined_score DESC
    LIMIT p_limit;
    
END;
$$ LANGUAGE plpgsql;

-- =====================================================================
-- INITIAL CONFIGURATION
-- =====================================================================

-- Set up pgvector for optimal performance
-- Recommended settings for production
COMMENT ON SCHEMA core IS 'Multi-content RAG system optimized for <250ms search responses';