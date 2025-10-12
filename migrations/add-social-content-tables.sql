-- ============================================================================
-- SOCIAL CONTENT STORAGE & FEEDBACK TRACKING
-- ============================================================================
-- Purpose: Store generated social content and track performance metrics
-- Used by: n8n social automation workflow + feedback loop
-- ============================================================================

-- ============================================================================
-- TABLE: social_content_generated
-- ============================================================================
-- Stores all generated social media posts before/after posting

CREATE TABLE IF NOT EXISTS core.social_content_generated (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Episode context
  episode_title VARCHAR(255) NOT NULL,
  file_id TEXT REFERENCES core.file_status(file_id),

  -- Day/theme info
  day_number INT NOT NULL CHECK (day_number >= 1 AND day_number <= 10),
  day_theme VARCHAR(100) NOT NULL,
  topic_title TEXT NOT NULL,
  topic_category VARCHAR(50),

  -- Generated content
  instagram_content TEXT,
  facebook_content TEXT,
  linkedin_content TEXT,

  -- Scheduling data
  schedule_data JSONB,

  -- Review/quality data
  review_scores JSONB,
  review_summary TEXT,

  -- Status tracking
  status VARCHAR(50) DEFAULT 'pending_schedule',
  -- Values: pending_schedule, scheduled, posted, rejected, failed

  -- GHL integration
  ghl_instagram_id VARCHAR(100),
  ghl_facebook_id VARCHAR(100),
  ghl_linkedin_id VARCHAR(100),
  posted_at TIMESTAMPTZ,

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for quick lookups
CREATE INDEX IF NOT EXISTS idx_social_content_episode
ON core.social_content_generated(episode_title, day_number);

CREATE INDEX IF NOT EXISTS idx_social_content_status
ON core.social_content_generated(status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_social_content_posted
ON core.social_content_generated(posted_at DESC)
WHERE posted_at IS NOT NULL;

-- ============================================================================
-- TABLE: social_post_performance
-- ============================================================================
-- Tracks actual performance metrics from posted content (feedback loop)

CREATE TABLE IF NOT EXISTS core.social_post_performance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  content_id UUID REFERENCES core.social_content_generated(id) ON DELETE CASCADE,

  -- Platform & post identifiers
  platform VARCHAR(50) NOT NULL,
  -- Values: instagram_reel, facebook, linkedin
  ghl_post_id VARCHAR(100),

  -- Engagement metrics
  likes INT DEFAULT 0,
  comments INT DEFAULT 0,
  shares INT DEFAULT 0,
  saves INT DEFAULT 0,
  reach INT DEFAULT 0,
  impressions INT DEFAULT 0,
  clicks INT DEFAULT 0,

  -- Calculated engagement scores
  engagement_rate DECIMAL(5,4),
  -- Formula: (likes + comments + shares) / reach

  virality_score DECIMAL(5,4),
  -- Formula: shares / reach

  save_rate DECIMAL(5,4),
  -- Formula: saves / reach (high value for valuable content)

  -- Performance tier (auto-calculated)
  performance_tier VARCHAR(20),
  -- Values: viral (top 10%), high (top 25%), medium, low

  -- Feedback analysis
  sentiment_score DECIMAL(3,2),
  -- 1-10 score from comment sentiment analysis

  top_performing_elements JSONB,
  -- e.g., {"hook": "contrarian", "emotion": "surprise", "cta": "engagement"}

  -- Timestamps
  metrics_updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Unique constraint for content_id + platform combination
CREATE UNIQUE INDEX IF NOT EXISTS idx_social_performance_content_platform_unique
ON core.social_post_performance(content_id, platform);

-- Indexes for analytics queries
CREATE INDEX IF NOT EXISTS idx_social_performance_content
ON core.social_post_performance(content_id);

CREATE INDEX IF NOT EXISTS idx_social_performance_platform
ON core.social_post_performance(platform, engagement_rate DESC);

CREATE INDEX IF NOT EXISTS idx_social_performance_tier
ON core.social_post_performance(performance_tier, metrics_updated_at DESC);

-- ============================================================================
-- TABLE: social_feedback_insights
-- ============================================================================
-- Aggregated learnings from post performance (ML training data)

CREATE TABLE IF NOT EXISTS core.social_feedback_insights (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Pattern identification
  pattern_type VARCHAR(100) NOT NULL,
  -- Values: high_performing_hook, engaging_emotion, viral_topic, best_posting_time

  pattern_description TEXT NOT NULL,

  -- Evidence
  sample_content_ids UUID[] NOT NULL,
  -- Array of content IDs that demonstrate this pattern

  avg_engagement_rate DECIMAL(5,4),
  sample_size INT NOT NULL,

  -- Pattern metadata
  platform VARCHAR(50),
  topic_category VARCHAR(50),
  day_theme VARCHAR(100),

  -- Confidence scoring
  confidence_score DECIMAL(3,2) CHECK (confidence_score >= 0 AND confidence_score <= 10),
  -- Based on sample size and consistency

  -- Actionable recommendation
  recommendation TEXT,
  -- e.g., "Use contrarian hooks on Day 1 for 35% higher engagement"

  -- Status
  status VARCHAR(50) DEFAULT 'active',
  -- Values: active, deprecated, testing

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for quick pattern lookups
CREATE INDEX IF NOT EXISTS idx_social_insights_pattern
ON core.social_feedback_insights(pattern_type, confidence_score DESC);

CREATE INDEX IF NOT EXISTS idx_social_insights_platform
ON core.social_feedback_insights(platform, avg_engagement_rate DESC);

-- ============================================================================
-- HELPER FUNCTION: Calculate Performance Tier
-- ============================================================================

CREATE OR REPLACE FUNCTION calculate_performance_tier(
  p_engagement_rate DECIMAL
)
RETURNS VARCHAR AS $$
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
$$ LANGUAGE plpgsql;

-- ============================================================================
-- HELPER FUNCTION: Update Performance Metrics
-- ============================================================================
-- Call this from n8n when GHL webhook delivers new metrics

CREATE OR REPLACE FUNCTION update_post_performance(
  p_content_id UUID,
  p_platform VARCHAR,
  p_likes INT,
  p_comments INT,
  p_shares INT,
  p_saves INT,
  p_reach INT,
  p_impressions INT,
  p_clicks INT
)
RETURNS TABLE (
  engagement_rate DECIMAL,
  virality_score DECIMAL,
  performance_tier VARCHAR
) AS $$
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
$$ LANGUAGE plpgsql;

-- ============================================================================
-- HELPER FUNCTION: Generate Feedback Insights
-- ============================================================================
-- Analyzes top-performing posts to extract patterns

CREATE OR REPLACE FUNCTION generate_feedback_insights()
RETURNS TABLE (
  pattern_type VARCHAR,
  pattern_description TEXT,
  avg_engagement DECIMAL,
  sample_size INT,
  recommendation TEXT
) AS $$
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
$$ LANGUAGE plpgsql;

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON TABLE core.social_content_generated IS
'Stores all AI-generated social media content with review scores and scheduling';

COMMENT ON TABLE core.social_post_performance IS
'Tracks real engagement metrics from posted content for feedback loop';

COMMENT ON TABLE core.social_feedback_insights IS
'ML-derived patterns from post performance to improve future content';

COMMENT ON FUNCTION update_post_performance IS
'Updates performance metrics from GHL webhook data and calculates scores';

COMMENT ON FUNCTION generate_feedback_insights IS
'Analyzes top posts to extract actionable patterns for content improvement';
