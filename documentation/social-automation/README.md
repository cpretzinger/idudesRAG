# Insurance Dudes - Social Media Automation System

**Complete AI-powered social content generation with RAG enrichment and performance feedback loop**

---

## 📋 Table of Contents

1. [System Overview](#system-overview)
2. [Architecture](#architecture)
3. [File Structure](#file-structure)
4. [Database Schema](#database-schema)
5. [Workflows](#workflows)
6. [Setup Instructions](#setup-instructions)
7. [Usage Guide](#usage-guide)
8. [Feedback Loop](#feedback-loop)
9. [Troubleshooting](#troubleshooting)

---

## 🎯 System Overview

This system automatically generates 10 days of social media content (Instagram Reels, Facebook posts, LinkedIn posts) from each podcast episode using:

1. **Topic Extraction & Ranking** - AI identifies 15-20 concepts, ranks by avatar relevance (35%), platform fit (25%), content richness (20%), virality potential (15%), and Craig/Jason energy (5%)
2. **RAG Enrichment** - Semantic search across all episodes, Million Dollar Agency book, Internet Lead Secrets, and guides to enhance content
3. **Multi-Stage Generation** - Content Generator → Expert Review → Platform Optimizer pipeline
4. **Optimal Scheduling** - Research-based posting times per platform (Instagram: 5AM, Facebook: 9AM Tue/Fri, LinkedIn: 5AM Tue/Wed)
5. **GHL Integration** - Posts scheduled via GoHighLevel MCP server
6. **Performance Feedback** - Tracks engagement metrics and generates ML insights to improve future content

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    CONTENT GENERATION PIPELINE                   │
└─────────────────────────────────────────────────────────────────┘

Episode Transcript (core.embeddings)
           ↓
    Extract Concepts (GPT-4o-mini)
           ↓
    Rank Topics (Weighted Algorithm)
           ↓
    Loop 10 Days:
      ├─ Semantic Search Enrichment (3 queries × 3 sources)
      ├─ Generate Content (GPT-4o-mini) → Instagram/Facebook/LinkedIn
      ├─ Expert Review (GPT-4o) → Approve/Edit/Reject
      ├─ Platform Optimization (GPT-4o-mini) → Polish for each platform
      └─ Store in Database → core.social_content_generated
           ↓
    Calculate Optimal Schedule (core.social_scheduling)
           ↓
    POST to GHL via MCP (3 platforms)
           ↓
    Track Performance (Webhook from GHL)
           ↓
    Generate Insights (ML pattern analysis)

┌─────────────────────────────────────────────────────────────────┐
│                      FEEDBACK LOOP                               │
└─────────────────────────────────────────────────────────────────┘

GHL Webhook → Parse Metrics → Update Performance → Calculate Tier
                                                        ↓
                                   Viral/High Performer? → Generate Insights
                                                        ↓
                         Weekly Report → Actionable Recommendations
```

---

## 📁 File Structure

```
/documentation/social-automation/
├── README.md                      # This file
├── content-rubric.json            # 10-day framework with topic extraction pipeline
├── content-guardrails.md          # Quality gates and rejection triggers
├── content-generator.json         # Main prompt for generating posts
├── content-reviewer.json          # Expert validation prompt with scoring
├── platform-optimizers.json       # Instagram/Facebook/LinkedIn polish prompts
└── craig-jason-voice-profile.md   # Authentic voice guide

/json-flows/
├── 10-social-content-automation.json  # Main generation workflow
└── 11-ghl-post-scheduler.json         # GHL posting + feedback loop

/migrations/
├── add-social-scheduling.sql          # Optimal posting times table
└── add-social-content-tables.sql      # Content storage + performance tracking
```

---

## 💾 Database Schema

### `core.social_scheduling`
Stores optimal posting times per platform based on 2025 research.

**Key Data:**
- Instagram Reels: Peak 5AM (9.5-10.0 score), Friday best
- Facebook: Peak Tuesday/Friday 9AM (9.5-10.0 score)
- LinkedIn: Peak Tue-Wed 5AM (10.0 score), avoid weekends

**Helper Functions:**
- `get_optimal_posting_time(platform, day_of_week, priority_rank)`
- `schedule_10_day_campaign(start_date)` - Returns 10-day schedule

### `core.social_content_generated`
Stores all generated posts with review scores, GHL IDs, and schedule data.

**Fields:**
- Episode context (episode_title, file_id, topic_title)
- Day/theme info (day_number 1-10, day_theme, topic_category)
- Generated content (instagram_content, facebook_content, linkedin_content)
- Scheduling (schedule_data JSONB)
- Quality (review_scores JSONB, review_summary)
- Status (pending_schedule → scheduled → posted)
- GHL integration (ghl_instagram_id, ghl_facebook_id, ghl_linkedin_id)

### `core.social_post_performance`
Tracks real engagement metrics from posted content.

**Metrics:**
- Engagement: likes, comments, shares, saves
- Reach: reach, impressions, clicks
- Calculated: engagement_rate, virality_score, save_rate
- Performance tier: viral (top 10%), high (top 25%), medium, low

**Helper Function:**
- `update_post_performance(content_id, platform, likes, comments, shares, saves, reach, impressions, clicks)` - Auto-calculates scores

### `core.social_feedback_insights`
ML-derived patterns from top-performing posts.

**Pattern Types:**
- high_performing_hook
- engaging_emotion
- viral_topic
- best_posting_time
- best_platform_for_category

**Helper Function:**
- `generate_feedback_insights()` - Analyzes top posts, returns actionable recommendations

---

## 🔄 Workflows

### Workflow 10: Social Content Automation

**Trigger:** Manual (run after new episode ingestion)

**Steps:**
1. Get latest completed episode from `core.file_status`
2. Retrieve all episode chunks from `core.embeddings`
3. Extract 15-20 concepts using GPT-4o-mini
4. Rank topics with weighted scoring algorithm
5. **Loop 10 days:**
   - Generate 3 semantic search queries per topic
   - Search: All episodes + Million Dollar Agency + Guides (similarity > 0.35)
   - Combine enrichment (max 9 chunks, 1200 words)
   - Map day theme from rubric (Pattern Interrupt → Recap)
   - Generate Instagram/Facebook/LinkedIn content (GPT-4o-mini)
   - Expert review with scoring (GPT-4o)
   - If approved: Platform optimization (GPT-4o-mini × 3)
   - If rejected: Log for manual review
   - Calculate optimal schedule from `core.social_scheduling`
   - Save to `core.social_content_generated`
6. Track metrics: `social_content_batch_completed`

**Output:** 30 posts (10 days × 3 platforms) ready for scheduling

---

### Workflow 11: GHL Post Scheduler & Feedback Loop

**Three Triggers:**

#### 1. Daily Scheduler (6AM)
- Get today's posts from `core.social_content_generated` WHERE status = 'pending_schedule'
- Parse schedule data (optimal times per platform)
- **Post to GHL via MCP:**
  - Instagram: `gohighlevel-mcp:create_social_post` (type: reel, status: scheduled)
  - Facebook: `gohighlevel-mcp:create_social_post` (type: post, status: scheduled)
  - LinkedIn: `gohighlevel-mcp:create_social_post` (type: post, status: scheduled)
- Update database with GHL post IDs and status = 'scheduled'
- Track metric: `social_posts_scheduled`

#### 2. Performance Webhook (Real-time)
**Endpoint:** `/webhook/ghl-performance-webhook`

**Expected Payload:**
```json
{
  "postId": "ghl_post_id_here",
  "platform": "instagram" | "facebook" | "linkedin",
  "metrics": {
    "likes": 150,
    "comments": 23,
    "shares": 8,
    "saves": 45,
    "reach": 2500,
    "impressions": 3200,
    "clicks": 112
  },
  "timestamp": "2025-10-15T18:30:00Z"
}
```

**Processing:**
- Find content_id from GHL post ID
- Call `update_post_performance()` function (auto-calculates engagement_rate, virality_score, performance_tier)
- If performance_tier = 'viral' or 'high': Trigger `generate_feedback_insights()`
- Track metric: `social_performance_tracked`
- Return engagement_rate and performance_tier

#### 3. Weekly Insights (Monday 8AM)
- Query `core.social_feedback_insights` WHERE confidence_score >= 7.0
- Format top 10 insights into markdown report
- Track metric: `weekly_insights_generated`

**Output:** Actionable recommendations for improving future content

---

## 🚀 Setup Instructions

### 1. Database Setup

```bash
# Execute migrations
PGPASSWORD='[password]' psql -h yamabiko.proxy.rlwy.net -p 15649 -U postgres -d railway \
  -f /mnt/volume_nyc1_01/idudesRAG/migrations/add-social-scheduling.sql

PGPASSWORD='[password]' psql -h yamabiko.proxy.rlwy.net -p 15649 -U postgres -d railway \
  -f /mnt/volume_nyc1_01/idudesRAG/migrations/add-social-content-tables.sql
```

### 2. Environment Variables

Add to `.env`:
```bash
# GHL MCP Integration
GHL_INSTAGRAM_ACCOUNT_ID=your_instagram_account_id
GHL_FACEBOOK_ACCOUNT_ID=your_facebook_account_id
GHL_LINKEDIN_ACCOUNT_ID=your_linkedin_account_id
GHL_USER_ID=your_ghl_user_id

# OpenAI (already configured)
OPENAI_API_KEY=your_openai_api_key
```

### 3. n8n MCP Server Setup

**Install GHL MCP Server:**
```bash
# In n8n container or MCP configuration
smithery install @cpretzinger/gohighlevel-mcp
```

**Configure MCP Credentials in n8n:**
1. Go to Credentials → Add Credential → MCP API
2. Name: "GHL MCP"
3. Server URL: `https://server.smithery.ai/@cpretzinger/gohighlevel-mcp`
4. Add authentication as required

### 4. Import Workflows

```bash
# Import to n8n
1. Open n8n UI
2. Go to Workflows → Import from File
3. Upload: json-flows/10-social-content-automation.json
4. Upload: json-flows/11-ghl-post-scheduler.json
5. Activate both workflows
```

### 5. Verify Setup

```sql
-- Check scheduling data
SELECT platform, day_of_week, optimal_hour, engagement_score
FROM core.social_scheduling
WHERE priority_rank = 1
ORDER BY platform, engagement_score DESC;

-- Test scheduling function
SELECT * FROM schedule_10_day_campaign('2025-10-15'::date);

-- Verify tables exist
\dt core.social_*
```

---

## 📖 Usage Guide

### Generate Content for New Episode

1. **Ensure episode is ingested:**
   ```sql
   SELECT filename, status, chunks_count
   FROM core.file_status
   WHERE filename LIKE '%Episode%'
   ORDER BY created_at DESC
   LIMIT 1;
   ```

2. **Run Workflow 10 (Social Content Automation):**
   - n8n → Workflows → "10 - Social Content Automation"
   - Click "Execute Workflow"
   - Wait ~5-10 minutes for completion

3. **Review generated content:**
   ```sql
   SELECT
     day_number,
     day_theme,
     topic_title,
     review_scores,
     status
   FROM core.social_content_generated
   ORDER BY created_at DESC, day_number ASC
   LIMIT 10;
   ```

4. **Automatic posting:** Workflow 11 runs daily at 6AM to schedule posts via GHL

### Manual Post Scheduling

```sql
-- Update post date if needed
UPDATE core.social_content_generated
SET schedule_data = jsonb_set(
  schedule_data,
  '{post_date}',
  '"2025-10-20"'
)
WHERE id = '[content_id]';
```

### Review Performance

```sql
-- Top performing posts
SELECT
  scg.episode_title,
  scg.topic_title,
  spp.platform,
  spp.engagement_rate,
  spp.performance_tier,
  spp.likes,
  spp.comments,
  spp.shares
FROM core.social_content_generated scg
JOIN core.social_post_performance spp ON scg.id = spp.content_id
WHERE spp.performance_tier IN ('viral', 'high')
ORDER BY spp.engagement_rate DESC
LIMIT 20;

-- Current insights
SELECT
  pattern_type,
  pattern_description,
  avg_engagement_rate,
  recommendation,
  confidence_score
FROM core.social_feedback_insights
WHERE status = 'active'
  AND confidence_score >= 7.0
ORDER BY avg_engagement_rate DESC;
```

---

## 🔁 Feedback Loop

### How It Works

1. **Post Goes Live** → GHL publishes the scheduled post
2. **Metrics Accumulate** → GHL tracks likes, comments, shares, reach
3. **Webhook Fires** → GHL sends performance data to n8n webhook
4. **Automatic Analysis:**
   - Calculate engagement_rate = (likes + comments + shares) / reach
   - Calculate virality_score = shares / reach
   - Determine performance_tier using percentile analysis
5. **Pattern Detection:** If tier = 'viral' or 'high', analyze:
   - Which day themes perform best
   - Which topic categories resonate
   - Best platform for each content type
6. **Actionable Insights Generated:**
   - "Day 1 Pattern Interrupt hooks get 35% higher engagement"
   - "Lead_gen topics perform best on LinkedIn (8.5% engagement)"
   - "Posting at 5AM on Instagram increases reach by 40%"

### Weekly Insights Report

**Generated every Monday at 8AM:**

```markdown
# WEEKLY SOCIAL MEDIA PERFORMANCE INSIGHTS

Generated: 2025-10-20

## HIGH PERFORMING DAY THEME

**Pattern:** Day Pattern Interrupt Hook consistently performs well
**Avg Engagement:** 8.45%
**Sample Size:** 12 posts
**Confidence:** 9.2/10
**Platform:** instagram_reel
**Category:** lead_gen

**Recommendation:** Prioritize Pattern Interrupt Hook content style for 8.45% engagement

---

## BEST PLATFORM FOR CATEGORY

**Pattern:** lead_gen performs best on linkedin
**Avg Engagement:** 7.82%
**Sample Size:** 8 posts
**Confidence:** 8.5/10

**Recommendation:** Post lead_gen content on linkedin for 7.82% engagement
```

### Improving Future Content

The system learns and adapts:
- **High performers** → Extract common elements (hook style, emotion, topic category)
- **Low performers** → Identify patterns to avoid
- **Confidence scoring** → Only trust patterns with 3+ samples and consistent results
- **Recommendation engine** → Specific, actionable changes for next batch

---

## 🔧 Troubleshooting

### Content Generation Issues

**Problem:** Workflow 10 fails at "Extract Concepts" step

**Solution:**
- Check OpenAI API key is valid
- Verify episode has embeddings: `SELECT COUNT(*) FROM core.embeddings WHERE file_id = '[file_id]'`
- Check episode content length (needs sufficient text)

**Problem:** Expert review keeps rejecting content

**Solution:**
- Review rejection logs in workflow execution history
- Check `content-guardrails.md` for quality requirements
- Verify voice profile is being followed (craig-jason-voice-profile.md)

### GHL Posting Issues

**Problem:** Posts not appearing in GHL

**Solution:**
- Verify MCP server credentials in n8n
- Check GHL account IDs in environment variables
- Test MCP connection: `gohighlevel-mcp:create_social_post` with minimal payload
- Review n8n execution logs for API errors

**Problem:** Wrong posting times

**Solution:**
- Check timezone in `core.social_scheduling` (default: America/Phoenix)
- Verify schedule calculation: `SELECT * FROM schedule_10_day_campaign(CURRENT_DATE);`
- Update optimal times if needed:
  ```sql
  UPDATE core.social_scheduling
  SET optimal_hour = 6, optimal_minute = 30
  WHERE platform = 'instagram_reel' AND day_of_week = 'friday';
  ```

### Performance Tracking Issues

**Problem:** Metrics not updating from GHL webhook

**Solution:**
- Test webhook manually: `curl -X POST [webhook_url] -d '[sample_payload]'`
- Verify GHL post IDs are stored correctly in database
- Check webhook authentication (if required)
- Review n8n webhook execution logs

**Problem:** No insights being generated

**Solution:**
- Need minimum 3 posts per pattern for confidence
- Check: `SELECT COUNT(*) FROM core.social_post_performance WHERE performance_tier IN ('viral', 'high')`
- Manually trigger: `SELECT * FROM generate_feedback_insights();`

---

## 📊 Metrics & Monitoring

### Key Metrics to Track

**In `core.metrics` table:**
- `social_content_batch_completed` - Episodes processed
- `social_posts_scheduled` - Posts sent to GHL
- `social_performance_tracked` - Webhook updates received
- `weekly_insights_generated` - ML insights created

**Query Metrics:**
```sql
SELECT
  metric_name,
  SUM(metric_value) as total,
  COUNT(*) as occurrences,
  MAX(recorded_at) as last_recorded
FROM core.metrics
WHERE metric_name LIKE 'social_%'
GROUP BY metric_name
ORDER BY last_recorded DESC;
```

### Performance Benchmarks

**Target Engagement Rates:**
- Instagram Reels: 5-8% (viral: >10%)
- Facebook: 3-5% (viral: >7%)
- LinkedIn: 4-6% (viral: >8%)

**Content Quality:**
- Review scores: >7.0 weighted average
- Voice authenticity: >6.0 minimum
- Brand safety: 10/10 (no exceptions)

---

## 🎓 Best Practices

1. **Run generation after each new episode** (don't batch multiple episodes)
2. **Review first batch manually** before trusting automation fully
3. **Monitor feedback insights weekly** to improve prompts
4. **Update optimal posting times** based on actual performance data
5. **Keep voice profile current** with Craig/Jason's evolving style
6. **Back up high-performing posts** for reference in future prompts

---

## 📞 Support

**Documentation Location:** `/mnt/volume_nyc1_01/idudesRAG/documentation/social-automation/`

**Database Queries:** All examples in this README are production-ready

**n8n Workflows:** Fully commented with node descriptions

**Issues:** Check n8n execution logs first, then database constraints

---

*System Created: October 12, 2025*
*Last Updated: October 12, 2025*
*Version: 1.0*
