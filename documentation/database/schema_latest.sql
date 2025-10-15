--
-- PostgreSQL database dump
--

\restrict PxjagcnBmXppCdebVGIEUFwxxGerfGH7R4QCTa4MHXAAxlaH5mMTm10K0AIRshy

-- Dumped from database version 16.10 (Debian 16.10-1.pgdg12+1)
-- Dumped by pg_dump version 17.6 (Ubuntu 17.6-0ubuntu0.25.04.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: core; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA core;


--
-- Name: assign_chunk_index(); Type: FUNCTION; Schema: core; Owner: -
--

CREATE FUNCTION core.assign_chunk_index() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  from_line int;
  meta_idx  int;
  curr      int;
BEGIN
  BEGIN meta_idx := (NEW.metadata->>'chunk_index')::int; EXCEPTION WHEN others THEN meta_idx := NULL; END;
  BEGIN from_line := (NEW.metadata->'loc'->'lines'->>'from')::int; EXCEPTION WHEN others THEN from_line := NULL; END;

  IF meta_idx IS NOT NULL OR from_line IS NOT NULL THEN
    NEW.chunk_index := COALESCE(meta_idx, from_line - 1, 0);
    RETURN NEW;
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext(NEW.document_id::text));

  UPDATE core.document_chunk_counters
     SET next_index = next_index + 1,
         updated_at = now()
   WHERE document_id = NEW.document_id
   RETURNING next_index - 1 INTO curr;

  IF NOT FOUND THEN
    INSERT INTO core.document_chunk_counters (document_id, next_index)
    VALUES (NEW.document_id, 1)
    RETURNING 0 INTO curr;
  END IF;

  NEW.chunk_index := curr;
  RETURN NEW;
END;
$$;


--
-- Name: calculate_performance_tier(numeric); Type: FUNCTION; Schema: core; Owner: -
--

CREATE FUNCTION core.calculate_performance_tier(p_engagement_rate numeric) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE
  percentile_90 DECIMAL;
  percentile_75 DECIMAL;
BEGIN
  -- Get top 10% threshold
  SELECT PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY engagement_rate)
  INTO percentile_90
  FROM core.social_post_performance
  WHERE engagement_rate IS NOT NULL;

  -- Get top 25% threshold
  SELECT PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY engagement_rate)
  INTO percentile_75
  FROM core.social_post_performance
  WHERE engagement_rate IS NOT NULL;

  IF p_engagement_rate >= percentile_90 THEN
    RETURN 'viral';
  ELSIF p_engagement_rate >= percentile_75 THEN
    RETURN 'high';
  ELSIF p_engagement_rate >= (percentile_75 * 0.5) THEN
    RETURN 'medium';
  ELSE
    RETURN 'low';
  END IF;
END;
$$;


--
-- Name: cleanup_old_cache(integer); Type: FUNCTION; Schema: core; Owner: -
--

CREATE FUNCTION core.cleanup_old_cache(retention_days integer DEFAULT 90) RETURNS TABLE(cache_type text, deleted_count bigint)
    LANGUAGE plpgsql
    AS $$
DECLARE
  cutoff_date timestamptz;
BEGIN
  cutoff_date := NOW() - (retention_days || ' days')::interval;

  -- Delete old cache entries by type and return counts
  RETURN QUERY
  WITH deleted AS (
    DELETE FROM core.api_cache
    WHERE created_at < cutoff_date
    RETURNING cache_type
  )
  SELECT
    d.cache_type,
    COUNT(*)::bigint as deleted_count
  FROM deleted d
  GROUP BY d.cache_type;

END;
$$;


--
-- Name: FUNCTION cleanup_old_cache(retention_days integer); Type: COMMENT; Schema: core; Owner: -
--

COMMENT ON FUNCTION core.cleanup_old_cache(retention_days integer) IS 'Deletes cache entries older than retention_days (default: 90). Returns deleted counts by cache_type.';


--
-- Name: cleanup_orphaned_embeddings(boolean); Type: FUNCTION; Schema: core; Owner: -
--

CREATE FUNCTION core.cleanup_orphaned_embeddings(p_dry_run boolean DEFAULT true) RETURNS TABLE(deleted_count bigint, orphaned_ids uuid[])
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_deleted_count bigint;
    v_orphaned_ids uuid[];
BEGIN
    SELECT ARRAY_AGG(id) INTO v_orphaned_ids
    FROM core.document_embeddings WHERE document_id NOT IN (SELECT id FROM core.documents);
    
    v_deleted_count := COALESCE(ARRAY_LENGTH(v_orphaned_ids, 1), 0);
    
    IF NOT p_dry_run AND v_deleted_count > 0 THEN
        DELETE FROM core.document_embeddings WHERE id = ANY(v_orphaned_ids);
    END IF;
    
    RETURN QUERY SELECT v_deleted_count, v_orphaned_ids;
END;
$$;


--
-- Name: coerce_chunk_index(); Type: FUNCTION; Schema: core; Owner: -
--

CREATE FUNCTION core.coerce_chunk_index() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  from_line int;
  meta_idx  int;
  next_idx  int;
BEGIN
  -- Try to read splitter line number (DocLoader/TextSplitter puts this in metadata.loc.lines.from)
  BEGIN
    from_line := (NEW.metadata->'loc'->'lines'->>'from')::int;
  EXCEPTION WHEN others THEN
    from_line := NULL;
  END;

  -- Try to read any existing metadata.chunk_index
  BEGIN
    meta_idx := (NEW.metadata->>'chunk_index')::int;
  EXCEPTION WHEN others THEN
    meta_idx := NULL;
  END;

  -- If still null, compute the next index for this document_id
  IF from_line IS NULL AND meta_idx IS NULL THEN
    SELECT COALESCE(MAX(chunk_index) + 1, 0)
      INTO next_idx
      FROM core.document_embeddings
     WHERE document_id = NEW.document_id;
  END IF;

  -- Final assignment: prefer loc.from-1, then metadata.chunk_index, then next_idx
  NEW.chunk_index := COALESCE(from_line - 1, meta_idx, next_idx, 0);

  RETURN NEW;
END;
$$;


--
-- Name: document_embeddings_ingest4_upsert_fn(); Type: FUNCTION; Schema: core; Owner: -
--

CREATE FUNCTION core.document_embeddings_ingest4_upsert_fn() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_id  uuid := COALESCE(NEW.id, gen_random_uuid());
  v_doc uuid := (NEW.metadata->>'document_id')::uuid;
  v_idx int  := NULL;
BEGIN
  -- prefer explicit chunk_index you set in metadata
  BEGIN v_idx := (NEW.metadata->>'chunk_index')::int; EXCEPTION WHEN others THEN v_idx := NULL; END;
  -- fallback: loader_index if you ever stamp it
  IF v_idx IS NULL THEN
    BEGIN v_idx := (NEW.metadata->>'loader_index')::int; EXCEPTION WHEN others THEN v_idx := NULL; END;
  END IF;
  -- final fallback
  v_idx := COALESCE(v_idx, 0);

  INSERT INTO core.document_embeddings
    (id, document_id, chunk_index, text, embedding, metadata, created_at)
  VALUES
    (v_id, v_doc, v_idx, NEW.content, NEW.embedding, COALESCE(NEW.metadata,'{}'::jsonb), now())
  ON CONFLICT (document_id, chunk_index)
  DO UPDATE SET
    text = EXCLUDED.text,
    embedding = EXCLUDED.embedding,
    metadata = EXCLUDED.metadata;

  RETURN NULL;
END $$;


--
-- Name: generate_feedback_insights(); Type: FUNCTION; Schema: core; Owner: -
--

CREATE FUNCTION core.generate_feedback_insights() RETURNS TABLE(pattern_type character varying, pattern_description text, avg_engagement numeric, sample_size integer, recommendation text)
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- Pattern 1: High-performing hooks by day theme
  RETURN QUERY
  WITH top_posts AS (
    SELECT
      scg.id,
      scg.day_theme,
      scg.topic_category,
      spp.engagement_rate,
      spp.platform
    FROM core.social_content_generated scg
    JOIN core.social_post_performance spp ON scg.id = spp.content_id
    WHERE spp.performance_tier IN ('viral', 'high')
      AND scg.day_number IS NOT NULL
  )
  SELECT
    'high_performing_day_theme'::VARCHAR as pattern_type,
    'Day ' || day_theme || ' consistently performs well'::TEXT as pattern_description,
    AVG(engagement_rate) as avg_engagement,
    COUNT(*)::INT as sample_size,
    'Prioritize ' || day_theme || ' content style for ' ||
    ROUND(AVG(engagement_rate) * 100, 1)::TEXT || '% engagement'::TEXT as recommendation
  FROM top_posts
  GROUP BY day_theme
  HAVING COUNT(*) >= 3
  ORDER BY AVG(engagement_rate) DESC
  LIMIT 5;

  -- Pattern 2: Best performing platforms by topic category
  RETURN QUERY
  WITH category_performance AS (
    SELECT
      scg.topic_category,
      spp.platform,
      AVG(spp.engagement_rate) as avg_eng,
      COUNT(*) as cnt
    FROM core.social_content_generated scg
    JOIN core.social_post_performance spp ON scg.id = spp.content_id
    WHERE scg.topic_category IS NOT NULL
    GROUP BY scg.topic_category, spp.platform
    HAVING COUNT(*) >= 2
  )
  SELECT
    'best_platform_for_category'::VARCHAR,
    topic_category || ' performs best on ' || platform::TEXT,
    avg_eng,
    cnt::INT,
    'Post ' || topic_category || ' content on ' || platform ||
    ' for ' || ROUND(avg_eng * 100, 1)::TEXT || '% engagement'::TEXT
  FROM category_performance
  WHERE avg_eng > 0.05
  ORDER BY avg_eng DESC
  LIMIT 5;
END;
$$;


--
-- Name: FUNCTION generate_feedback_insights(); Type: COMMENT; Schema: core; Owner: -
--

COMMENT ON FUNCTION core.generate_feedback_insights() IS 'Analyzes top posts to extract actionable patterns for content improvement';


--
-- Name: get_cache_stats(); Type: FUNCTION; Schema: core; Owner: -
--

CREATE FUNCTION core.get_cache_stats() RETURNS TABLE(cache_type text, total_entries bigint, total_hits bigint, hit_rate numeric, estimated_savings_usd numeric, avg_age_days numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
  RETURN QUERY
  SELECT
    ac.cache_type,
    COUNT(*)::bigint as total_entries,
    SUM(ac.hit_count)::bigint as total_hits,
    CASE
      WHEN COUNT(*) > 0 THEN ROUND(AVG(ac.hit_count), 2)
      ELSE 0
    END as hit_rate,
    ROUND(SUM(ac.hit_count * COALESCE(ac.cost_usd, 0)), 2) as estimated_savings_usd,
    ROUND(AVG(EXTRACT(EPOCH FROM (NOW() - ac.created_at)) / 86400), 1) as avg_age_days
  FROM core.api_cache ac
  GROUP BY ac.cache_type
  ORDER BY total_hits DESC;
END;
$$;


--
-- Name: FUNCTION get_cache_stats(); Type: COMMENT; Schema: core; Owner: -
--

COMMENT ON FUNCTION core.get_cache_stats() IS 'Returns cache effectiveness metrics: entries, hits, savings, age by cache_type';


--
-- Name: get_optimal_posting_time(character varying, character varying, integer); Type: FUNCTION; Schema: core; Owner: -
--

CREATE FUNCTION core.get_optimal_posting_time(p_platform character varying, p_day_of_week character varying, p_priority_rank integer DEFAULT 1) RETURNS TABLE(platform character varying, day_of_week character varying, optimal_hour integer, optimal_minute integer, engagement_score numeric, notes text)
    LANGUAGE plpgsql
    AS $$
BEGIN
  RETURN QUERY
  SELECT
    ss.platform,
    ss.day_of_week,
    ss.optimal_hour,
    ss.optimal_minute,
    ss.engagement_score,
    ss.notes
  FROM core.social_scheduling ss
  WHERE ss.platform = p_platform
    AND ss.day_of_week = p_day_of_week
    AND ss.priority_rank = p_priority_rank
  ORDER BY ss.engagement_score DESC
  LIMIT 1;
END;
$$;


--
-- Name: FUNCTION get_optimal_posting_time(p_platform character varying, p_day_of_week character varying, p_priority_rank integer); Type: COMMENT; Schema: core; Owner: -
--

COMMENT ON FUNCTION core.get_optimal_posting_time(p_platform character varying, p_day_of_week character varying, p_priority_rank integer) IS 'Returns optimal posting time for platform/day/priority';


--
-- Name: insert_document_chunk(uuid, text, public.vector, jsonb); Type: FUNCTION; Schema: core; Owner: -
--

CREATE FUNCTION core.insert_document_chunk(p_document_id uuid, p_text text, p_embedding public.vector, p_metadata jsonb DEFAULT '{}'::jsonb) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_chunk_index int;
    v_chunk_size int;
    v_chunk_id uuid;
BEGIN
    PERFORM 1 FROM core.documents WHERE id = p_document_id FOR UPDATE;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Document % does not exist', p_document_id;
    END IF;
    
    SELECT COALESCE(MAX(chunk_index), -1) + 1 
    INTO v_chunk_index FROM core.document_embeddings WHERE document_id = p_document_id;
    
    v_chunk_size := LENGTH(p_text);
    
    INSERT INTO core.document_embeddings (document_id, text, embedding, chunk_index, chunk_size, metadata)
    VALUES (p_document_id, p_text, p_embedding, v_chunk_index, v_chunk_size, p_metadata)
    RETURNING id INTO v_chunk_id;
    
    RETURN v_chunk_id;
END;
$$;


--
-- Name: match_embeddings(public.vector, integer, text); Type: FUNCTION; Schema: core; Owner: -
--

CREATE FUNCTION core.match_embeddings(q public.vector, top_k integer DEFAULT 5, exclude_file_id text DEFAULT NULL::text) RETURNS TABLE(file_id text, filename text, chunk_index integer, text text, similarity double precision)
    LANGUAGE sql STABLE
    AS $$
  SELECT e.file_id, e.filename, e.chunk_index, e.text,
         1 - (e.embedding <=> q) AS similarity
  FROM core.embeddings e
  WHERE (exclude_file_id IS NULL OR e.file_id <> exclude_file_id)
  ORDER BY e.embedding <=> q
  LIMIT top_k;
$$;


--
-- Name: populate_embedding_columns(); Type: FUNCTION; Schema: core; Owner: -
--

CREATE FUNCTION core.populate_embedding_columns() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  BEGIN
    -- Extract from metadata JSONB and populate separate columns
    NEW.document_id := (NEW.metadata->>'document_id')::uuid;
    NEW.chunk_index := COALESCE((NEW.metadata->>'chunk_index')::integer, 0);
    RETURN NEW;
  END;
  $$;


--
-- Name: reindex_vectors(); Type: FUNCTION; Schema: core; Owner: -
--

CREATE FUNCTION core.reindex_vectors() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    REINDEX INDEX CONCURRENTLY core.idx_embeddings_hnsw;
    REINDEX INDEX CONCURRENTLY core.idx_embeddings_l2;
END;
$$;


--
-- Name: replace_embeddings(text, jsonb); Type: FUNCTION; Schema: core; Owner: -
--

CREATE FUNCTION core.replace_embeddings(_file_id text, _rows jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- wipe the file’s prior rows
  DELETE FROM core.embeddings WHERE file_id = _file_id;

  -- insert new rows
  INSERT INTO core.embeddings(
    file_id, filename, chunk_index, text, chunk_size,
    embedding, file_type, file_size, created_at, updated_at
  )
  SELECT
    (r->>'file_id'),
    (r->>'filename'),
    (r->>'chunk_index')::int,
    (r->>'text'),
    (r->>'chunk_size')::int,
    (r->>'embedding')::vector(1536),
    (r->>'file_type'),
    (r->>'file_size')::int,
    NOW(), NOW()
  FROM jsonb_array_elements(_rows) AS r;

  -- optional sanity: assert count > 0
  -- IF NOT EXISTS (SELECT 1 FROM core.embeddings WHERE file_id=_file_id) THEN
  --   RAISE EXCEPTION 'No embeddings inserted for %', _file_id;
  -- END IF;

END;
$$;


--
-- Name: schedule_10_day_campaign(date); Type: FUNCTION; Schema: core; Owner: -
--

CREATE FUNCTION core.schedule_10_day_campaign(start_date date) RETURNS TABLE(day_number integer, post_date date, day_of_week character varying, instagram_hour integer, instagram_minute integer, facebook_hour integer, facebook_minute integer, linkedin_hour integer, linkedin_minute integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
  target_date DATE;
  current_dow VARCHAR;
  day_num INT;
BEGIN
  FOR day_num IN 1..10 LOOP
    target_date := start_date + (day_num - 1);
    current_dow := LOWER(TO_CHAR(target_date, 'Day'));
    current_dow := TRIM(current_dow);

    day_number := day_num;
    post_date := target_date;
    day_of_week := current_dow;

    -- Get optimal time for Instagram (priority 1)
    SELECT ss.optimal_hour, ss.optimal_minute
    INTO instagram_hour, instagram_minute
    FROM core.social_scheduling ss
    WHERE ss.platform = 'instagram_reel'
      AND ss.day_of_week = current_dow
      AND ss.priority_rank = 1
    ORDER BY ss.engagement_score DESC
    LIMIT 1;

    -- Get optimal time for Facebook (priority 1)
    SELECT ss.optimal_hour, ss.optimal_minute
    INTO facebook_hour, facebook_minute
    FROM core.social_scheduling ss
    WHERE ss.platform = 'facebook'
      AND ss.day_of_week = current_dow
      AND ss.priority_rank = 1
    ORDER BY ss.engagement_score DESC
    LIMIT 1;

    -- Get optimal time for LinkedIn (priority 1)
    SELECT ss.optimal_hour, ss.optimal_minute
    INTO linkedin_hour, linkedin_minute
    FROM core.social_scheduling ss
    WHERE ss.platform = 'linkedin'
      AND ss.day_of_week = current_dow
      AND ss.priority_rank = 1
    ORDER BY ss.engagement_score DESC
    LIMIT 1;

    RETURN NEXT;
  END LOOP;
END;
$$;


--
-- Name: FUNCTION schedule_10_day_campaign(start_date date); Type: COMMENT; Schema: core; Owner: -
--

COMMENT ON FUNCTION core.schedule_10_day_campaign(start_date date) IS 'Generates 10-day posting schedule with optimal times per platform';


--
-- Name: search_documents(public.vector, double precision, integer, character varying, jsonb); Type: FUNCTION; Schema: core; Owner: -
--

CREATE FUNCTION core.search_documents(query_embedding public.vector, similarity_threshold double precision DEFAULT 0.7, result_limit integer DEFAULT 10, file_type_filter character varying DEFAULT NULL::character varying, metadata_filter jsonb DEFAULT NULL::jsonb) RETURNS TABLE(document_id uuid, filename character varying, chunk_text text, chunk_index integer, similarity double precision)
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        d.id,
        d.filename,
        de.text,
        de.chunk_index,
        (1 - (de.embedding <=> query_embedding))::FLOAT8
    FROM core.document_embeddings de
    JOIN core.documents d ON d.id = de.document_id
    WHERE (1 - (de.embedding <=> query_embedding)) > similarity_threshold
        AND (file_type_filter IS NULL OR d.file_type = file_type_filter)
        AND (metadata_filter IS NULL OR d.metadata @> metadata_filter)
    ORDER BY de.embedding <=> query_embedding
    LIMIT result_limit;
END; $$;


--
-- Name: set_chunk_index_from_metadata(); Type: FUNCTION; Schema: core; Owner: -
--

CREATE FUNCTION core.set_chunk_index_from_metadata() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.chunk_index IS NULL THEN
    -- take chunk_index from metadata; fallback to 0 (or raise if you prefer strict)
    NEW.chunk_index := COALESCE((NEW.metadata->>'chunk_index')::int, 0);
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: sync_text_column(); Type: FUNCTION; Schema: core; Owner: -
--

CREATE FUNCTION core.sync_text_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN NEW.text = NEW.chunk_text; RETURN NEW; END; $$;


--
-- Name: update_cache_timestamp(); Type: FUNCTION; Schema: core; Owner: -
--

CREATE FUNCTION core.update_cache_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


--
-- Name: update_post_performance(uuid, character varying, integer, integer, integer, integer, integer, integer, integer); Type: FUNCTION; Schema: core; Owner: -
--

CREATE FUNCTION core.update_post_performance(p_content_id uuid, p_platform character varying, p_likes integer, p_comments integer, p_shares integer, p_saves integer, p_reach integer, p_impressions integer, p_clicks integer) RETURNS TABLE(engagement_rate numeric, virality_score numeric, performance_tier character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_engagement_rate DECIMAL;
  v_virality_score DECIMAL;
  v_save_rate DECIMAL;
  v_tier VARCHAR;
BEGIN
  -- Calculate engagement rate
  IF p_reach > 0 THEN
    v_engagement_rate := (p_likes + p_comments + p_shares)::DECIMAL / p_reach;
    v_virality_score := p_shares::DECIMAL / p_reach;
    v_save_rate := p_saves::DECIMAL / p_reach;
  ELSE
    v_engagement_rate := 0;
    v_virality_score := 0;
    v_save_rate := 0;
  END IF;

  -- Calculate tier
  v_tier := calculate_performance_tier(v_engagement_rate);

  -- Upsert performance data
  INSERT INTO core.social_post_performance (
    content_id,
    platform,
    likes,
    comments,
    shares,
    saves,
    reach,
    impressions,
    clicks,
    engagement_rate,
    virality_score,
    save_rate,
    performance_tier,
    metrics_updated_at
  ) VALUES (
    p_content_id,
    p_platform,
    p_likes,
    p_comments,
    p_shares,
    p_saves,
    p_reach,
    p_impressions,
    p_clicks,
    v_engagement_rate,
    v_virality_score,
    v_save_rate,
    v_tier,
    NOW()
  )
  ON CONFLICT (content_id, platform)
  DO UPDATE SET
    likes = EXCLUDED.likes,
    comments = EXCLUDED.comments,
    shares = EXCLUDED.shares,
    saves = EXCLUDED.saves,
    reach = EXCLUDED.reach,
    impressions = EXCLUDED.impressions,
    clicks = EXCLUDED.clicks,
    engagement_rate = EXCLUDED.engagement_rate,
    virality_score = EXCLUDED.virality_score,
    save_rate = EXCLUDED.save_rate,
    performance_tier = EXCLUDED.performance_tier,
    metrics_updated_at = NOW();

  -- Return calculated metrics
  RETURN QUERY
  SELECT v_engagement_rate, v_virality_score, v_tier;
END;
$$;


--
-- Name: FUNCTION update_post_performance(p_content_id uuid, p_platform character varying, p_likes integer, p_comments integer, p_shares integer, p_saves integer, p_reach integer, p_impressions integer, p_clicks integer); Type: COMMENT; Schema: core; Owner: -
--

COMMENT ON FUNCTION core.update_post_performance(p_content_id uuid, p_platform character varying, p_likes integer, p_comments integer, p_shares integer, p_saves integer, p_reach integer, p_impressions integer, p_clicks integer) IS 'Updates performance metrics from GHL webhook data and calculates scores';


--
-- Name: update_table_stats(); Type: FUNCTION; Schema: core; Owner: -
--

CREATE FUNCTION core.update_table_stats() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    ANALYZE core.documents;
    ANALYZE core.document_embeddings;
END;
$$;


--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: core; Owner: -
--

CREATE FUNCTION core.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: api_cache; Type: TABLE; Schema: core; Owner: -
--

CREATE TABLE core.api_cache (
    key_hash text NOT NULL,
    cache_type text NOT NULL,
    model text NOT NULL,
    model_version text DEFAULT 'v1'::text NOT NULL,
    request_payload jsonb NOT NULL,
    response_data jsonb NOT NULL,
    cost_usd numeric(10,6),
    hit_count integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT api_cache_cache_type_check CHECK ((cache_type = ANY (ARRAY['embedding'::text, 'generation'::text, 'review'::text])))
);


--
-- Name: TABLE api_cache; Type: COMMENT; Schema: core; Owner: -
--

COMMENT ON TABLE core.api_cache IS 'Unified cache for OpenAI API responses (embeddings, generation, review). Tracks hit_count and cost for observability.';


--
-- Name: COLUMN api_cache.key_hash; Type: COMMENT; Schema: core; Owner: -
--

COMMENT ON COLUMN core.api_cache.key_hash IS 'SHA256 hash of (model + request_payload + version). Unique cache key.';


--
-- Name: COLUMN api_cache.cache_type; Type: COMMENT; Schema: core; Owner: -
--

COMMENT ON COLUMN core.api_cache.cache_type IS 'Type of cached API call: embedding, generation, or review';


--
-- Name: COLUMN api_cache.model_version; Type: COMMENT; Schema: core; Owner: -
--

COMMENT ON COLUMN core.api_cache.model_version IS 'Prompt/model version for cache invalidation';


--
-- Name: COLUMN api_cache.cost_usd; Type: COMMENT; Schema: core; Owner: -
--

COMMENT ON COLUMN core.api_cache.cost_usd IS 'Estimated cost per call (for ROI tracking)';


--
-- Name: COLUMN api_cache.hit_count; Type: COMMENT; Schema: core; Owner: -
--

COMMENT ON COLUMN core.api_cache.hit_count IS 'Number of times this cache entry was used (cost savings metric)';


--
-- Name: auth_logs; Type: TABLE; Schema: core; Owner: -
--

CREATE TABLE core.auth_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant character varying(50) DEFAULT 'idudes'::character varying NOT NULL,
    email character varying(255) NOT NULL,
    action character varying(50) NOT NULL,
    status character varying(50) NOT NULL,
    ip_address character varying(100),
    user_agent text,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'America/Phoenix'::text) NOT NULL
);


--
-- Name: drive_sync_state; Type: TABLE; Schema: core; Owner: -
--

CREATE TABLE core.drive_sync_state (
    id text DEFAULT 'drive_changes'::text NOT NULL,
    page_token text NOT NULL,
    last_sync_at timestamp with time zone DEFAULT now(),
    total_changes_processed bigint DEFAULT 0,
    last_error text,
    CONSTRAINT chk_page_token_not_empty CHECK ((page_token <> ''::text))
);


--
-- Name: TABLE drive_sync_state; Type: COMMENT; Schema: core; Owner: -
--

COMMENT ON TABLE core.drive_sync_state IS 'Stores Google Drive changes.list API pagination state';


--
-- Name: COLUMN drive_sync_state.page_token; Type: COMMENT; Schema: core; Owner: -
--

COMMENT ON COLUMN core.drive_sync_state.page_token IS 'Google Drive changes API pageToken for incremental sync';


--
-- Name: COLUMN drive_sync_state.total_changes_processed; Type: COMMENT; Schema: core; Owner: -
--

COMMENT ON COLUMN core.drive_sync_state.total_changes_processed IS 'Counter for observability';


--
-- Name: embeddings; Type: TABLE; Schema: core; Owner: -
--

CREATE TABLE core.embeddings (
    id bigint NOT NULL,
    file_id text NOT NULL,
    filename text NOT NULL,
    chunk_index integer NOT NULL,
    text text NOT NULL,
    chunk_size integer NOT NULL,
    embedding public.vector(1536) NOT NULL,
    file_type text,
    file_size integer,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    content_hash text
);


--
-- Name: COLUMN embeddings.content_hash; Type: COMMENT; Schema: core; Owner: -
--

COMMENT ON COLUMN core.embeddings.content_hash IS 'SHA256 hash of text content for deduplication';


--
-- Name: embeddings_id_seq; Type: SEQUENCE; Schema: core; Owner: -
--

CREATE SEQUENCE core.embeddings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: embeddings_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: -
--

ALTER SEQUENCE core.embeddings_id_seq OWNED BY core.embeddings.id;


--
-- Name: enrichment_logs; Type: TABLE; Schema: core; Owner: -
--

CREATE TABLE core.enrichment_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant text DEFAULT 'idudes'::text NOT NULL,
    document_id uuid NOT NULL,
    status text NOT NULL,
    metadata_extracted jsonb,
    error_message text,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'America/Phoenix'::text) NOT NULL,
    CONSTRAINT enrichment_logs_status_check CHECK ((status = ANY (ARRAY['success'::text, 'error'::text, 'pending'::text])))
);


--
-- Name: file_pipeline_status; Type: TABLE; Schema: core; Owner: -
--

CREATE TABLE core.file_pipeline_status (
    file_id character varying(255) NOT NULL,
    filename character varying(500) NOT NULL,
    rag_status character varying(50) DEFAULT 'pending'::character varying,
    rag_chunks_count integer DEFAULT 0,
    rag_embedding_count integer DEFAULT 0,
    rag_completed_at timestamp without time zone,
    rag_error_message text,
    social_status character varying(50) DEFAULT 'not_started'::character varying,
    social_posts_generated integer DEFAULT 0,
    social_completed_at timestamp without time zone,
    social_error_message text,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now(),
    CONSTRAINT file_pipeline_status_rag_status_check CHECK (((rag_status)::text = ANY ((ARRAY['pending'::character varying, 'processing'::character varying, 'completed'::character varying, 'failed'::character varying])::text[]))),
    CONSTRAINT file_pipeline_status_social_status_check CHECK (((social_status)::text = ANY ((ARRAY['not_started'::character varying, 'in_progress'::character varying, 'completed'::character varying, 'failed'::character varying])::text[])))
);


--
-- Name: file_status; Type: TABLE; Schema: core; Owner: -
--

CREATE TABLE core.file_status (
    file_id text NOT NULL,
    filename text NOT NULL,
    status text NOT NULL,
    chunks_count integer DEFAULT 0,
    error_message text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT file_status_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'processing'::text, 'completed'::text, 'failed'::text])))
);


--
-- Name: metrics; Type: TABLE; Schema: core; Owner: -
--

CREATE TABLE core.metrics (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    metric_name character varying(100) NOT NULL,
    metric_value numeric NOT NULL,
    tags jsonb DEFAULT '{}'::jsonb,
    recorded_at timestamp with time zone DEFAULT now()
);


--
-- Name: password_reset_tokens; Type: TABLE; Schema: core; Owner: -
--

CREATE TABLE core.password_reset_tokens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    token character varying(255) NOT NULL,
    expires_at timestamp without time zone NOT NULL,
    used boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT now()
);


--
-- Name: password_resets; Type: TABLE; Schema: core; Owner: -
--

CREATE TABLE core.password_resets (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    token_hash character varying(64) NOT NULL,
    expires_at timestamp without time zone NOT NULL,
    created_at timestamp without time zone DEFAULT now()
);


--
-- Name: prompt_library; Type: TABLE; Schema: core; Owner: -
--

CREATE TABLE core.prompt_library (
    id bigint NOT NULL,
    prompt_key text NOT NULL,
    version text NOT NULL,
    role text NOT NULL,
    content text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: prompt_library_id_seq; Type: SEQUENCE; Schema: core; Owner: -
--

CREATE SEQUENCE core.prompt_library_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: prompt_library_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: -
--

ALTER SEQUENCE core.prompt_library_id_seq OWNED BY core.prompt_library.id;


--
-- Name: social_content_generated; Type: TABLE; Schema: core; Owner: -
--

CREATE TABLE core.social_content_generated (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    episode_title character varying(255) NOT NULL,
    file_id text,
    day_number integer NOT NULL,
    day_theme character varying(100) NOT NULL,
    topic_title text NOT NULL,
    topic_category character varying(50),
    instagram_content text,
    facebook_content text,
    linkedin_content text,
    schedule_data jsonb,
    review_scores jsonb,
    review_summary text,
    status character varying(50) DEFAULT 'pending_schedule'::character varying,
    ghl_instagram_id character varying(100),
    ghl_facebook_id character varying(100),
    ghl_linkedin_id character varying(100),
    posted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    work_id text,
    attempt integer DEFAULT 0,
    persona_segment text,
    emotion_tone text,
    CONSTRAINT social_content_generated_day_number_check CHECK (((day_number >= 1) AND (day_number <= 10)))
);


--
-- Name: TABLE social_content_generated; Type: COMMENT; Schema: core; Owner: -
--

COMMENT ON TABLE core.social_content_generated IS 'Stores all AI-generated social media content with review scores and scheduling';


--
-- Name: social_feedback_insights; Type: TABLE; Schema: core; Owner: -
--

CREATE TABLE core.social_feedback_insights (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    pattern_type character varying(100) NOT NULL,
    pattern_description text NOT NULL,
    sample_content_ids uuid[] NOT NULL,
    avg_engagement_rate numeric(5,4),
    sample_size integer NOT NULL,
    platform character varying(50),
    topic_category character varying(50),
    day_theme character varying(100),
    confidence_score numeric(3,2),
    recommendation text,
    status character varying(50) DEFAULT 'active'::character varying,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT social_feedback_insights_confidence_score_check CHECK (((confidence_score >= (0)::numeric) AND (confidence_score <= (10)::numeric)))
);


--
-- Name: TABLE social_feedback_insights; Type: COMMENT; Schema: core; Owner: -
--

COMMENT ON TABLE core.social_feedback_insights IS 'ML-derived patterns from post performance to improve future content';


--
-- Name: social_post_performance; Type: TABLE; Schema: core; Owner: -
--

CREATE TABLE core.social_post_performance (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    content_id uuid,
    platform character varying(50) NOT NULL,
    ghl_post_id character varying(100),
    likes integer DEFAULT 0,
    comments integer DEFAULT 0,
    shares integer DEFAULT 0,
    saves integer DEFAULT 0,
    reach integer DEFAULT 0,
    impressions integer DEFAULT 0,
    clicks integer DEFAULT 0,
    engagement_rate numeric(5,4),
    virality_score numeric(5,4),
    save_rate numeric(5,4),
    performance_tier character varying(20),
    sentiment_score numeric(3,2),
    top_performing_elements jsonb,
    metrics_updated_at timestamp with time zone DEFAULT now(),
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: TABLE social_post_performance; Type: COMMENT; Schema: core; Owner: -
--

COMMENT ON TABLE core.social_post_performance IS 'Tracks real engagement metrics from posted content for feedback loop';


--
-- Name: social_processed; Type: TABLE; Schema: core; Owner: -
--

CREATE TABLE core.social_processed (
    file_id character varying(255) NOT NULL,
    filename character varying(500),
    first_processed_at timestamp without time zone DEFAULT now(),
    last_checked_at timestamp without time zone DEFAULT now()
);


--
-- Name: social_scheduling; Type: TABLE; Schema: core; Owner: -
--

CREATE TABLE core.social_scheduling (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    platform character varying(50) NOT NULL,
    content_type character varying(50) NOT NULL,
    day_of_week character varying(20) NOT NULL,
    optimal_hour integer NOT NULL,
    optimal_minute integer DEFAULT 0,
    timezone character varying(50) DEFAULT 'America/Phoenix'::character varying,
    engagement_score numeric(4,2),
    priority_rank integer DEFAULT 1,
    source character varying(100),
    notes text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT social_scheduling_engagement_score_check CHECK (((engagement_score >= (0)::numeric) AND (engagement_score <= (10)::numeric))),
    CONSTRAINT social_scheduling_optimal_hour_check CHECK (((optimal_hour >= 0) AND (optimal_hour <= 23))),
    CONSTRAINT social_scheduling_optimal_minute_check CHECK (((optimal_minute >= 0) AND (optimal_minute <= 59)))
);


--
-- Name: TABLE social_scheduling; Type: COMMENT; Schema: core; Owner: -
--

COMMENT ON TABLE core.social_scheduling IS 'Optimal posting times per platform based on 2025 research data';


--
-- Name: user_sessions; Type: TABLE; Schema: core; Owner: -
--

CREATE TABLE core.user_sessions (
    token character varying(64) NOT NULL,
    user_id uuid NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'America/Phoenix'::text) NOT NULL,
    last_accessed timestamp with time zone DEFAULT (now() AT TIME ZONE 'America/Phoenix'::text),
    id uuid DEFAULT gen_random_uuid(),
    session_token character varying(255)
);


--
-- Name: users; Type: TABLE; Schema: core; Owner: -
--

CREATE TABLE core.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    email character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    password_hash character varying(255) NOT NULL,
    role character varying(50) DEFAULT 'user'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'America/Phoenix'::text) NOT NULL,
    updated_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'America/Phoenix'::text) NOT NULL,
    must_reset_password boolean DEFAULT true,
    last_login timestamp without time zone,
    CONSTRAINT users_role_check CHECK (((role)::text = ANY ((ARRAY['user'::character varying, 'admin'::character varying, 'superadmin'::character varying])::text[])))
);


--
-- Name: embeddings id; Type: DEFAULT; Schema: core; Owner: -
--

ALTER TABLE ONLY core.embeddings ALTER COLUMN id SET DEFAULT nextval('core.embeddings_id_seq'::regclass);


--
-- Name: prompt_library id; Type: DEFAULT; Schema: core; Owner: -
--

ALTER TABLE ONLY core.prompt_library ALTER COLUMN id SET DEFAULT nextval('core.prompt_library_id_seq'::regclass);


--
-- Name: api_cache api_cache_pkey; Type: CONSTRAINT; Schema: core; Owner: -
--

ALTER TABLE ONLY core.api_cache
    ADD CONSTRAINT api_cache_pkey PRIMARY KEY (key_hash);


--
-- Name: auth_logs auth_logs_pkey; Type: CONSTRAINT; Schema: core; Owner: -
--

ALTER TABLE ONLY core.auth_logs
    ADD CONSTRAINT auth_logs_pkey PRIMARY KEY (id);


--
-- Name: drive_sync_state drive_sync_state_pkey; Type: CONSTRAINT; Schema: core; Owner: -
--

ALTER TABLE ONLY core.drive_sync_state
    ADD CONSTRAINT drive_sync_state_pkey PRIMARY KEY (id);


--
-- Name: embeddings embeddings_file_id_chunk_index_key; Type: CONSTRAINT; Schema: core; Owner: -
--

ALTER TABLE ONLY core.embeddings
    ADD CONSTRAINT embeddings_file_id_chunk_index_key UNIQUE (file_id, chunk_index);


--
-- Name: embeddings embeddings_pkey; Type: CONSTRAINT; Schema: core; Owner: -
--

ALTER TABLE ONLY core.embeddings
    ADD CONSTRAINT embeddings_pkey PRIMARY KEY (id);


--
-- Name: enrichment_logs enrichment_logs_pkey; Type: CONSTRAINT; Schema: core; Owner: -
--

ALTER TABLE ONLY core.enrichment_logs
    ADD CONSTRAINT enrichment_logs_pkey PRIMARY KEY (id);


--
-- Name: file_pipeline_status file_pipeline_status_pkey; Type: CONSTRAINT; Schema: core; Owner: -
--

ALTER TABLE ONLY core.file_pipeline_status
    ADD CONSTRAINT file_pipeline_status_pkey PRIMARY KEY (file_id);


--
-- Name: file_status file_status_pkey; Type: CONSTRAINT; Schema: core; Owner: -
--

ALTER TABLE ONLY core.file_status
    ADD CONSTRAINT file_status_pkey PRIMARY KEY (file_id);


--
-- Name: metrics metrics_pkey; Type: CONSTRAINT; Schema: core; Owner: -
--

ALTER TABLE ONLY core.metrics
    ADD CONSTRAINT metrics_pkey PRIMARY KEY (id);


--
-- Name: password_reset_tokens password_reset_tokens_pkey; Type: CONSTRAINT; Schema: core; Owner: -
--

ALTER TABLE ONLY core.password_reset_tokens
    ADD CONSTRAINT password_reset_tokens_pkey PRIMARY KEY (id);


--
-- Name: password_reset_tokens password_reset_tokens_token_key; Type: CONSTRAINT; Schema: core; Owner: -
--

ALTER TABLE ONLY core.password_reset_tokens
    ADD CONSTRAINT password_reset_tokens_token_key UNIQUE (token);


--
-- Name: password_resets password_resets_pkey; Type: CONSTRAINT; Schema: core; Owner: -
--

ALTER TABLE ONLY core.password_resets
    ADD CONSTRAINT password_resets_pkey PRIMARY KEY (id);


--
-- Name: prompt_library prompt_library_pkey; Type: CONSTRAINT; Schema: core; Owner: -
--

ALTER TABLE ONLY core.prompt_library
    ADD CONSTRAINT prompt_library_pkey PRIMARY KEY (id);


--
-- Name: social_content_generated social_content_generated_pkey; Type: CONSTRAINT; Schema: core; Owner: -
--

ALTER TABLE ONLY core.social_content_generated
    ADD CONSTRAINT social_content_generated_pkey PRIMARY KEY (id);


--
-- Name: social_content_generated social_content_generated_work_id_key; Type: CONSTRAINT; Schema: core; Owner: -
--

ALTER TABLE ONLY core.social_content_generated
    ADD CONSTRAINT social_content_generated_work_id_key UNIQUE (work_id);


--
-- Name: social_feedback_insights social_feedback_insights_pkey; Type: CONSTRAINT; Schema: core; Owner: -
--

ALTER TABLE ONLY core.social_feedback_insights
    ADD CONSTRAINT social_feedback_insights_pkey PRIMARY KEY (id);


--
-- Name: social_post_performance social_post_performance_pkey; Type: CONSTRAINT; Schema: core; Owner: -
--

ALTER TABLE ONLY core.social_post_performance
    ADD CONSTRAINT social_post_performance_pkey PRIMARY KEY (id);


--
-- Name: social_processed social_processed_pkey; Type: CONSTRAINT; Schema: core; Owner: -
--

ALTER TABLE ONLY core.social_processed
    ADD CONSTRAINT social_processed_pkey PRIMARY KEY (file_id);


--
-- Name: social_scheduling social_scheduling_pkey; Type: CONSTRAINT; Schema: core; Owner: -
--

ALTER TABLE ONLY core.social_scheduling
    ADD CONSTRAINT social_scheduling_pkey PRIMARY KEY (id);


--
-- Name: password_resets unique_user_id; Type: CONSTRAINT; Schema: core; Owner: -
--

ALTER TABLE ONLY core.password_resets
    ADD CONSTRAINT unique_user_id UNIQUE (user_id);


--
-- Name: user_sessions user_sessions_pkey; Type: CONSTRAINT; Schema: core; Owner: -
--

ALTER TABLE ONLY core.user_sessions
    ADD CONSTRAINT user_sessions_pkey PRIMARY KEY (token);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: core; Owner: -
--

ALTER TABLE ONLY core.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: core; Owner: -
--

ALTER TABLE ONLY core.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: idx_api_cache_created; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_api_cache_created ON core.api_cache USING btree (created_at DESC);


--
-- Name: idx_api_cache_hit_count; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_api_cache_hit_count ON core.api_cache USING btree (cache_type, hit_count DESC) WHERE (hit_count > 0);


--
-- Name: idx_api_cache_type; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_api_cache_type ON core.api_cache USING btree (cache_type, created_at DESC);


--
-- Name: idx_api_cache_version; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_api_cache_version ON core.api_cache USING btree (cache_type, model_version);


--
-- Name: idx_auth_logs_action; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_auth_logs_action ON core.auth_logs USING btree (action);


--
-- Name: idx_auth_logs_created_at; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_auth_logs_created_at ON core.auth_logs USING btree (created_at DESC);


--
-- Name: idx_auth_logs_email; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_auth_logs_email ON core.auth_logs USING btree (email);


--
-- Name: idx_auth_logs_status; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_auth_logs_status ON core.auth_logs USING btree (status);


--
-- Name: idx_auth_logs_tenant; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_auth_logs_tenant ON core.auth_logs USING btree (tenant);


--
-- Name: idx_embeddings_content_hash; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_embeddings_content_hash ON core.embeddings USING btree (file_id, content_hash);


--
-- Name: idx_embeddings_created_at; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_embeddings_created_at ON core.embeddings USING btree (created_at DESC);


--
-- Name: idx_embeddings_file_id; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_embeddings_file_id ON core.embeddings USING btree (file_id);


--
-- Name: idx_embeddings_filename; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_embeddings_filename ON core.embeddings USING gin (to_tsvector('english'::regconfig, filename));


--
-- Name: idx_embeddings_text; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_embeddings_text ON core.embeddings USING gin (to_tsvector('english'::regconfig, text));


--
-- Name: idx_embeddings_vector; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_embeddings_vector ON core.embeddings USING ivfflat (embedding public.vector_cosine_ops) WITH (lists='100');


--
-- Name: idx_enrichment_logs_created_at; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_enrichment_logs_created_at ON core.enrichment_logs USING btree (created_at DESC);


--
-- Name: idx_enrichment_logs_document_id; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_enrichment_logs_document_id ON core.enrichment_logs USING btree (document_id);


--
-- Name: idx_enrichment_logs_status; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_enrichment_logs_status ON core.enrichment_logs USING btree (status);


--
-- Name: idx_enrichment_logs_tenant; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_enrichment_logs_tenant ON core.enrichment_logs USING btree (tenant);


--
-- Name: idx_enrichment_logs_tenant_status; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_enrichment_logs_tenant_status ON core.enrichment_logs USING btree (tenant, status, created_at DESC);


--
-- Name: idx_file_pipeline_filename; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_file_pipeline_filename ON core.file_pipeline_status USING btree (filename);


--
-- Name: idx_file_pipeline_rag_status; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_file_pipeline_rag_status ON core.file_pipeline_status USING btree (rag_status);


--
-- Name: idx_file_pipeline_social_status; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_file_pipeline_social_status ON core.file_pipeline_status USING btree (social_status);


--
-- Name: idx_file_status_filename_trgm; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_file_status_filename_trgm ON core.file_status USING gin (filename public.gin_trgm_ops);


--
-- Name: idx_file_status_status; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_file_status_status ON core.file_status USING btree (status);


--
-- Name: idx_file_status_status_updated; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_file_status_status_updated ON core.file_status USING btree (status, updated_at DESC);


--
-- Name: idx_file_status_updated; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_file_status_updated ON core.file_status USING btree (updated_at DESC);


--
-- Name: idx_metrics_name_time; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_metrics_name_time ON core.metrics USING btree (metric_name, recorded_at DESC);


--
-- Name: idx_metrics_tags; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_metrics_tags ON core.metrics USING gin (tags);


--
-- Name: idx_password_reset_tokens_token; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_password_reset_tokens_token ON core.password_reset_tokens USING btree (token);


--
-- Name: idx_password_resets_token_hash; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_password_resets_token_hash ON core.password_resets USING btree (token_hash);


--
-- Name: idx_password_resets_user_id; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_password_resets_user_id ON core.password_resets USING btree (user_id);


--
-- Name: idx_social_content_episode; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_social_content_episode ON core.social_content_generated USING btree (episode_title, day_number);


--
-- Name: idx_social_content_posted; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_social_content_posted ON core.social_content_generated USING btree (posted_at DESC) WHERE (posted_at IS NOT NULL);


--
-- Name: idx_social_content_status; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_social_content_status ON core.social_content_generated USING btree (status, created_at DESC);


--
-- Name: idx_social_insights_pattern; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_social_insights_pattern ON core.social_feedback_insights USING btree (pattern_type, confidence_score DESC);


--
-- Name: idx_social_insights_platform; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_social_insights_platform ON core.social_feedback_insights USING btree (platform, avg_engagement_rate DESC);


--
-- Name: idx_social_performance_content; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_social_performance_content ON core.social_post_performance USING btree (content_id);


--
-- Name: idx_social_performance_content_platform_unique; Type: INDEX; Schema: core; Owner: -
--

CREATE UNIQUE INDEX idx_social_performance_content_platform_unique ON core.social_post_performance USING btree (content_id, platform);


--
-- Name: idx_social_performance_platform; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_social_performance_platform ON core.social_post_performance USING btree (platform, engagement_rate DESC);


--
-- Name: idx_social_performance_tier; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_social_performance_tier ON core.social_post_performance USING btree (performance_tier, metrics_updated_at DESC);


--
-- Name: idx_social_scheduling_day; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_social_scheduling_day ON core.social_scheduling USING btree (day_of_week);


--
-- Name: idx_social_scheduling_platform; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_social_scheduling_platform ON core.social_scheduling USING btree (platform);


--
-- Name: idx_social_scheduling_platform_day; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_social_scheduling_platform_day ON core.social_scheduling USING btree (platform, day_of_week, priority_rank);


--
-- Name: idx_user_sessions_expires_at; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_user_sessions_expires_at ON core.user_sessions USING btree (expires_at);


--
-- Name: idx_user_sessions_last_accessed; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_user_sessions_last_accessed ON core.user_sessions USING btree (last_accessed DESC);


--
-- Name: idx_user_sessions_user_expires; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_user_sessions_user_expires ON core.user_sessions USING btree (user_id, expires_at DESC);


--
-- Name: idx_user_sessions_user_id; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_user_sessions_user_id ON core.user_sessions USING btree (user_id);


--
-- Name: idx_users_role; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX idx_users_role ON core.users USING btree (role) WHERE ((role)::text = ANY ((ARRAY['admin'::character varying, 'superadmin'::character varying])::text[]));


--
-- Name: prompt_library_key_ver_role; Type: INDEX; Schema: core; Owner: -
--

CREATE UNIQUE INDEX prompt_library_key_ver_role ON core.prompt_library USING btree (prompt_key, version, role);


--
-- Name: ux_embeddings_file_idx; Type: INDEX; Schema: core; Owner: -
--

CREATE UNIQUE INDEX ux_embeddings_file_idx ON core.embeddings USING btree (file_id, chunk_index);


--
-- Name: api_cache trigger_api_cache_updated_at; Type: TRIGGER; Schema: core; Owner: -
--

CREATE TRIGGER trigger_api_cache_updated_at BEFORE UPDATE ON core.api_cache FOR EACH ROW EXECUTE FUNCTION core.update_cache_timestamp();


--
-- Name: users update_users_updated_at; Type: TRIGGER; Schema: core; Owner: -
--

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON core.users FOR EACH ROW EXECUTE FUNCTION core.update_updated_at_column();


--
-- Name: password_reset_tokens password_reset_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: -
--

ALTER TABLE ONLY core.password_reset_tokens
    ADD CONSTRAINT password_reset_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES core.users(id) ON DELETE CASCADE;


--
-- Name: password_resets password_resets_user_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: -
--

ALTER TABLE ONLY core.password_resets
    ADD CONSTRAINT password_resets_user_id_fkey FOREIGN KEY (user_id) REFERENCES core.users(id) ON DELETE CASCADE;


--
-- Name: social_content_generated social_content_generated_file_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: -
--

ALTER TABLE ONLY core.social_content_generated
    ADD CONSTRAINT social_content_generated_file_id_fkey FOREIGN KEY (file_id) REFERENCES core.file_status(file_id);


--
-- Name: social_post_performance social_post_performance_content_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: -
--

ALTER TABLE ONLY core.social_post_performance
    ADD CONSTRAINT social_post_performance_content_id_fkey FOREIGN KEY (content_id) REFERENCES core.social_content_generated(id) ON DELETE CASCADE;


--
-- Name: user_sessions user_sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: -
--

ALTER TABLE ONLY core.user_sessions
    ADD CONSTRAINT user_sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES core.users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict PxjagcnBmXppCdebVGIEUFwxxGerfGH7R4QCTa4MHXAAxlaH5mMTm10K0AIRshy

