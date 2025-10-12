-- ============================================================================
-- SOCIAL MEDIA SCHEDULING TABLE
-- ============================================================================
-- Purpose: Store optimal posting times per platform based on 2025 research
-- Used by: n8n social content automation workflow
-- Research: Sprout Social, Buffer, Hootsuite 2025 data
-- ============================================================================

CREATE TABLE IF NOT EXISTS core.social_scheduling (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  platform VARCHAR(50) NOT NULL,
  content_type VARCHAR(50) NOT NULL,
  day_of_week VARCHAR(20) NOT NULL,
  optimal_hour INT NOT NULL CHECK (optimal_hour >= 0 AND optimal_hour <= 23),
  optimal_minute INT DEFAULT 0 CHECK (optimal_minute >= 0 AND optimal_minute <= 59),
  timezone VARCHAR(50) DEFAULT 'America/Phoenix',
  engagement_score DECIMAL(4,2) CHECK (engagement_score >= 0 AND engagement_score <= 10),
  priority_rank INT DEFAULT 1,
  source VARCHAR(100),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add indexes for fast lookups
CREATE INDEX IF NOT EXISTS idx_social_scheduling_platform
ON core.social_scheduling(platform);

CREATE INDEX IF NOT EXISTS idx_social_scheduling_day
ON core.social_scheduling(day_of_week);

CREATE INDEX IF NOT EXISTS idx_social_scheduling_platform_day
ON core.social_scheduling(platform, day_of_week, priority_rank);

-- ============================================================================
-- SEED DATA - 2025 OPTIMAL POSTING TIMES
-- ============================================================================
-- Based on aggregated research from Sprout Social, Buffer, Hootsuite
-- All times in Arizona timezone (America/Phoenix)
-- ============================================================================

-- INSTAGRAM REELS - Peak Times
INSERT INTO core.social_scheduling (platform, content_type, day_of_week, optimal_hour, optimal_minute, engagement_score, priority_rank, source, notes) VALUES
-- Early morning posts (highest engagement - 5AM peak)
('instagram_reel', 'any', 'monday', 5, 0, 9.5, 1, 'Buffer 2025', 'Highest engagement time - early risers'),
('instagram_reel', 'any', 'tuesday', 5, 0, 9.5, 1, 'Buffer 2025', 'Highest engagement time - early risers'),
('instagram_reel', 'any', 'wednesday', 5, 0, 9.5, 1, 'Buffer 2025', 'Highest engagement time - early risers'),
('instagram_reel', 'any', 'thursday', 5, 0, 9.5, 1, 'Buffer 2025', 'Highest engagement time - early risers'),
('instagram_reel', 'any', 'friday', 5, 0, 10.0, 1, 'Buffer 2025 + Sprout', 'Best day + best time - PEAK'),

-- Mid-day alternatives (10AM-3PM strong engagement)
('instagram_reel', 'any', 'monday', 10, 0, 8.5, 2, 'Sprout 2025', 'Lunch scroll time'),
('instagram_reel', 'any', 'tuesday', 11, 0, 8.5, 2, 'Sprout 2025', 'Mid-morning engagement'),
('instagram_reel', 'any', 'wednesday', 10, 30, 8.5, 2, 'Sprout 2025', 'Morning coffee break'),
('instagram_reel', 'any', 'thursday', 14, 0, 8.0, 2, 'Sprout 2025', 'Afternoon engagement'),
('instagram_reel', 'any', 'friday', 11, 0, 9.0, 2, 'Sprout 2025', 'Friday momentum'),

-- Avoid weekends for business content
('instagram_reel', 'any', 'saturday', 10, 0, 5.0, 3, 'General', 'Lower engagement for B2B'),
('instagram_reel', 'any', 'sunday', 10, 0, 4.5, 3, 'General', 'Lowest engagement day');

-- FACEBOOK - Peak Times
INSERT INTO core.social_scheduling (platform, content_type, day_of_week, optimal_hour, optimal_minute, engagement_score, priority_rank, source, notes) VALUES
-- Best times: Tuesday 9-10AM, Friday peak day
('facebook', 'any', 'tuesday', 9, 0, 9.5, 1, 'Sprout 2025', 'Peak engagement - Tuesday morning'),
('facebook', 'any', 'friday', 9, 0, 10.0, 1, 'Sprout + Buffer 2025', 'Best day - Friday morning'),
('facebook', 'any', 'friday', 13, 0, 9.0, 2, 'Sprout 2025', 'Friday afternoon engagement'),

-- Strong alternative times (7-9AM)
('facebook', 'any', 'monday', 8, 0, 8.0, 2, 'Sprout 2025', 'Monday morning routine'),
('facebook', 'any', 'wednesday', 9, 0, 8.5, 2, 'Sprout 2025', 'Mid-week engagement'),
('facebook', 'any', 'thursday', 8, 30, 8.5, 2, 'Sprout 2025', 'Thursday morning'),

-- Avoid weekends
('facebook', 'any', 'saturday', 10, 0, 5.5, 3, 'Sprout 2025', 'Weekend - lower engagement'),
('facebook', 'any', 'sunday', 10, 0, 5.0, 3, 'Sprout 2025', 'Worst day for engagement');

-- LINKEDIN - Peak Times
INSERT INTO core.social_scheduling (platform, content_type, day_of_week, optimal_hour, optimal_minute, engagement_score, priority_rank, source, notes) VALUES
-- Best times: Tue-Wed 4-6AM, 8-10AM
('linkedin', 'any', 'tuesday', 5, 0, 10.0, 1, 'Later + Hootsuite 2025', 'Peak professional engagement'),
('linkedin', 'any', 'wednesday', 5, 0, 10.0, 1, 'Later + Hootsuite 2025', 'Peak professional engagement'),
('linkedin', 'any', 'tuesday', 9, 0, 9.5, 2, 'Sprout 2025', 'Workday start engagement'),
('linkedin', 'any', 'wednesday', 9, 0, 9.5, 2, 'Sprout 2025', 'Workday start engagement'),

-- Alternative strong times (5-6PM end of workday)
('linkedin', 'any', 'tuesday', 17, 0, 9.0, 3, 'Later 2025', 'End of workday scroll'),
('linkedin', 'any', 'wednesday', 17, 0, 9.0, 3, 'Later 2025', 'End of workday scroll'),
('linkedin', 'any', 'thursday', 9, 0, 8.5, 2, 'Sprout 2025', 'Thursday morning'),

-- Decent weekday times
('linkedin', 'any', 'monday', 9, 0, 7.5, 3, 'Sprout 2025', 'Monday - avoid if possible'),
('linkedin', 'any', 'thursday', 17, 0, 8.0, 3, 'Later 2025', 'Thursday evening'),
('linkedin', 'any', 'friday', 9, 0, 7.0, 4, 'Later 2025', 'Friday - lower engagement'),

-- AVOID weekends completely
('linkedin', 'any', 'saturday', 10, 0, 3.0, 5, 'Later 2025', 'Weekend - very low engagement'),
('linkedin', 'any', 'sunday', 10, 0, 2.5, 5, 'Later 2025', 'Worst day for LinkedIn');

-- ============================================================================
-- HELPER FUNCTION - Get Optimal Posting Time
-- ============================================================================
-- Usage: SELECT * FROM get_optimal_posting_time('instagram_reel', 'tuesday', 1);
-- ============================================================================

CREATE OR REPLACE FUNCTION get_optimal_posting_time(
  p_platform VARCHAR,
  p_day_of_week VARCHAR,
  p_priority_rank INT DEFAULT 1
)
RETURNS TABLE (
  platform VARCHAR,
  day_of_week VARCHAR,
  optimal_hour INT,
  optimal_minute INT,
  engagement_score DECIMAL(4,2),
  notes TEXT
) AS $$
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
$$ LANGUAGE plpgsql;

-- ============================================================================
-- HELPER FUNCTION - Get Next Available Slot
-- ============================================================================
-- Intelligently schedules posts across 10 days with optimal timing
-- Usage: SELECT * FROM schedule_10_day_campaign('2025-10-15'::date);
-- ============================================================================

CREATE OR REPLACE FUNCTION schedule_10_day_campaign(
  start_date DATE
)
RETURNS TABLE (
  day_number INT,
  post_date DATE,
  day_of_week VARCHAR,
  instagram_hour INT,
  instagram_minute INT,
  facebook_hour INT,
  facebook_minute INT,
  linkedin_hour INT,
  linkedin_minute INT
) AS $$
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
$$ LANGUAGE plpgsql;

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Check all platform peak times
-- SELECT platform, day_of_week, optimal_hour, engagement_score
-- FROM core.social_scheduling
-- WHERE priority_rank = 1
-- ORDER BY platform, engagement_score DESC;

-- Test scheduling function
-- SELECT * FROM schedule_10_day_campaign('2025-10-15'::date);

-- Get optimal time for specific platform/day
-- SELECT * FROM get_optimal_posting_time('instagram_reel', 'friday', 1);

COMMENT ON TABLE core.social_scheduling IS 'Optimal posting times per platform based on 2025 research data';
COMMENT ON FUNCTION get_optimal_posting_time IS 'Returns optimal posting time for platform/day/priority';
COMMENT ON FUNCTION schedule_10_day_campaign IS 'Generates 10-day posting schedule with optimal times per platform';
