📋 Implementation Summary for Your Coder

  Project Goal:

  Add intelligent API caching to Workflow 10 (social-content-automation) to reduce OpenAI costs by 50-80%
  on duplicate content generation.

  ---
  What's Already Done (Backend - Database Layer):

  1. Database Schema Created

  Location: /migrations/add-api-cache-table.sql (already applied to Railway PostgreSQL)

  New Table: core.api_cache
  - Unified cache for all OpenAI API calls (embeddings, generation, review)
  - Uses SHA256 hashing for cache keys
  - Tracks hit counts for cost analysis
  - Supports versioning for cache invalidation

  Columns:
  key_hash          (PRIMARY KEY) - SHA256 of request
  cache_type        - 'embedding' | 'generation' | 'review'
  model             - Model name (e.g., 'gpt-4o-mini')
  model_version     - Version for cache busting (default: 'v1')
  request_payload   - Full request (jsonb)
  response_data     - Cached response (jsonb)
  cost_usd          - Estimated API call cost
  hit_count         - Times this cache entry was reused
  created_at        - Cache entry timestamp
  updated_at        - Last hit timestamp

  Indexes Created:
  - idx_api_cache_type - Fast lookups by cache type
  - idx_api_cache_created - Retention cleanup
  - idx_api_cache_version - Version-based invalidation
  - idx_api_cache_hit_count - Cost analysis queries

  Functions Created:
  - core.cleanup_old_cache(days) - Deletes entries older than N days
  - core.get_cache_stats() - Returns cache effectiveness metrics

  Bonus:
  - Added content_hash column to core.embeddings for future deduplication

  ---
  What Needs to Be Done (Frontend - n8n Workflow Integration):

  2. Workflow 10 Modifications

  Guide Location: /json-flows/farts.md

  Task: Add 6 new nodes to workflow 10 that wrap the "Generate Content" step with caching logic.

  ---
  The 6 Nodes to Add:

  Node 1: Build Gen Cache Key (Code node)

  - Before: "Combine Enrichment Data" (existing)
  - After: "Check Gen Cache" (new)
  - Purpose: Creates SHA256 hash from episode content + model + prompt version
  - Output: Adds gen_cache_key, gen_model, gen_prompt_version to $json

  Node 2: Check Gen Cache (Postgres node)

  - Before: "Build Gen Cache Key"
  - After: "Cache Hit?" (IF node)
  - Purpose: Queries core.api_cache for existing response
  - Query: SELECT * FROM core.api_cache WHERE key_hash = $1 AND cache_type = 'generation'
  - Config: "Always Output Data" = enabled (returns empty on miss)

  Node 3: Cache Hit? (IF node)

  - Before: "Check Gen Cache"
  - After (TRUE): "Use Cached Generation"
  - After (FALSE): "Generate Content" (existing node)
  - Purpose: Routes to cached response or fresh LLM call
  - Condition: Check if response_data is not empty

  Node 4: Use Cached Generation (Code node)

  - Before: "Cache Hit?" (true branch)
  - After: "Merge Cached + Fresh"
  - Purpose: Extracts cached content, marks as from_cache: true
  - Benefit: Skips expensive OpenAI API call

  Node 5: Store Gen Cache (Postgres node)

  - Before: "Generate Content" (existing node)
  - After: "Merge Cached + Fresh"
  - Purpose: Saves LLM response to cache for future reuse
  - Query: UPSERT to core.api_cache (handles race conditions)

  Node 6: Merge Cached + Fresh (Merge node)

  - Before (Input 1): "Use Cached Generation"
  - Before (Input 2): "Store Gen Cache"
  - After: "Parse Generated Content" (existing node)
  - Purpose: Combines both paths back into single flow

  ---
  Flow Diagram:

  BEFORE (Current):
  Combine Enrichment Data → Generate Content → Parse Generated Content

  AFTER (With Caching):
  Combine Enrichment Data
    → Build Gen Cache Key
    → Check Gen Cache
    → Cache Hit?
        ├─ TRUE → Use Cached Generation ────┐
        └─ FALSE → Generate Content          │
                   → Store Gen Cache ────────┤
    → Merge Cached + Fresh
    → Parse Generated Content

  ---
  Expected Behavior:

  First Run (Cache Miss):

  1. Episode processed normally
  2. LLM generates content
  3. Response stored in core.api_cache with hit_count = 0
  4. Total nodes executed: ALL (including LLM call)

  Second Run (Same Episode - Cache Hit):

  1. Cache check finds existing response
  2. "Generate Content" node is SKIPPED (no API call)
  3. Cached response used instead
  4. hit_count incremented to 1
  5. Total nodes executed: FEWER (LLM bypassed)
  6. Cost savings: ~$0.001-0.01 per hit (depending on model)

  Different Episode (Cache Miss):

  1. New cache key generated
  2. LLM generates fresh content
  3. New cache entry created
  4. Process continues normally

  ---
  Testing Instructions for Coder:

  Test 1: First Run

  # Trigger workflow with episode_id = "test123"
  # Expected:
  - Workflow completes normally
  - Query: SELECT * FROM core.api_cache WHERE cache_type = 'generation';
  - Should show 1 row with hit_count = 0

  Test 2: Cache Hit

  # Trigger workflow AGAIN with SAME episode_id = "test123"
  # Expected:
  - Workflow completes faster
  - "Generate Content" node NOT executed (check n8n execution log)
  - Query: SELECT hit_count FROM core.api_cache WHERE cache_type = 'generation';
  - Should show hit_count = 1

  Test 3: Different Episode

  # Trigger workflow with episode_id = "test456"
  # Expected:
  - New cache entry created
  - Query: SELECT COUNT(*) FROM core.api_cache WHERE cache_type = 'generation';
  - Should show 2 rows

  ---
  Monitoring Queries:

  Check Cache Effectiveness:

  SELECT * FROM core.get_cache_stats();

  Returns:
  cache_type | total_entries | total_hits | hit_rate | estimated_savings_usd
  generation |       150     |    450     |   3.0    |         $4.50

  Find Most Reused Content:

  SELECT key_hash, hit_count, created_at
  FROM core.api_cache
  WHERE cache_type = 'generation'
  ORDER BY hit_count DESC
  LIMIT 10;

  Calculate Total Savings:

  SELECT
    cache_type,
    SUM(hit_count) as total_hits,
    SUM(hit_count * cost_usd) as savings_usd
  FROM core.api_cache
  GROUP BY cache_type;

  ---
  Future Phases (Not Implemented Yet):

  Phase 2: Embedding Cache

  - Same 6-node pattern
  - Wrap "Build Query Embeddings" node
  - cache_type = 'embedding'
  - Est. savings: 20-30% on enrichment queries

  Phase 3: Review Cache

  - Same 6-node pattern
  - Wrap "Expert Review" node
  - cache_type = 'review'
  - Est. savings: 15-20% on content reviews

  ---
  Files for Reference:

  1. Migration SQL: /migrations/add-api-cache-table.sql (already applied)
  2. Node Configs: /json-flows/farts.md (step-by-step guide)
  3. Workflow JSON: /json-flows/10-social-content-automation.json (existing workflow)

  ---
  Implementation Time Estimate:

  - Add 6 nodes to n8n: 30-45 minutes
  - Test with 3 scenarios: 15 minutes
  - Verify cache stats: 5 minutes
  - Total: ~1 hour

  ---
  Success Criteria:

  ✅ Cache hit on duplicate episode (confirmed in logs)✅ hit_count increments on subsequent runs✅
  "Generate Content" node skipped on cache hit✅ Cost savings visible in get_cache_stats()✅ No errors or
  data loss