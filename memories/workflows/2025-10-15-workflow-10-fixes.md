# Workflow 10 (Social Content Automation) - Critical Fixes
**Date**: 2025-10-15
**Status**: Fixed - Awaiting Deployment
**Workflow**: `uLQsT8ImlCY4SWtu` (10-social-content-automation.json)

## Summary
Fixed critical data flow issues in the social content review pipeline that were causing DB insert failures and incorrect review routing.

---

## Issues Discovered

### 1. Missing Brand Voice Rules in Review Output
**Problem**: LLM was saying "Marcus" and using first-person language (I/me/my) in generated content.

**Root Cause**: Brand voice rules were added to the user prompt via inline prepending, but should be in the DB prompts instead.

**Fix**:
- Removed inline `BRAND_VOICE_RULES` from Prompt Mapper subflow
- Rules now enforced in DB prompts (v3 system prompt)
- Prevents duplication and ensures consistency across all prompt versions

---

### 2. Reviewer Prompt Missing Context
**Problem**: Expert Review was receiving empty prompts with `persona: {}`, `brand: {}`, `enriched: {}`, `payload: {}`.

**Root Cause**: `packInputs4` node was only passing `prompt_key` and `prompt_version` from `$json`, not pulling enriched data from upstream.

**Fix**:
```javascript
// Updated packInputs4 to pull ALL data from upstream
const upstream = $('setPromptVersionLLMS').first().json || {};

return [{
  json: {
    prompt_key: $json.prompt_key || upstream.prompt_key,
    version: $json.prompt_version || upstream.prompt_version,
    persona: upstream.persona || {},
    brand: upstream.brand || {},
    enriched: upstream.enriched || {},
    payload: {
      instagram: upstream.instagram_content || '',
      facebook: upstream.facebook_content || '',
      linkedin: upstream.linkedin_content || ''
    },
    // CRITICAL: Preserve fields for DB insert
    episode_title: upstream.episode_title,
    day_number: upstream.day_number,
    day_theme: upstream.day_theme,
    topic_title: upstream.topic_title,
    topic_category: upstream.topic_category,
    file_id: upstream.file_id,
    work_id: upstream.work_id,
    instagram_content: upstream.instagram_content,
    facebook_content: upstream.facebook_content,
    linkedin_content: upstream.linkedin_content,
    prompts
  }
}];
```

---

### 3. Merge Node Dead End
**Problem**: `Merge content + ReviewPrompts` node had empty output configuration (line 141-144 in connections).

**Impact**: Expert Review never executed because Merge wasn't connected to anything.

**Fix**: Connect `Merge content + ReviewPrompts` → `Expert Review` node.

---

### 4. Review Output Not Merged with Enriched Data
**Problem**: DB insert failing with:
```
null value in column "episode_title" of relation "social_content_generated" violates not-null constraint
```

**Root Cause**: Review output from `setupRouter` flows to `Recommendation` Switch, but enriched data (episode_title, day_number, etc.) was never merged back in before DB insert.

**Fix**: Add new Merge node before DB insert:

```javascript
// Node: Merge Review + Enriched
const review = $input.first().json;
const enriched = $input.last().json;

return [{
  json: {
    // Review data
    review: review.review,
    recommendation: review.recommendation,
    approved: review.approved,

    // Enriched data (for DB insert)
    episode_title: enriched.episode_title,
    day_number: enriched.day_number,
    day_theme: enriched.day_theme,
    topic_title: enriched.topic_title,
    topic_category: enriched.topic_category,
    file_id: enriched.file_id,
    work_id: enriched.work_id,
    instagram_content: enriched.instagram_content,
    facebook_content: enriched.facebook_content,
    linkedin_content: enriched.linkedin_content,
    review_scores: review.review,
    review_summary: review.review.summary || ''
  }
}];
```

**Connections**:
- Input 1: `setupRouter` (review output)
- Input 2: `Parse Generated Content` (enriched data)
- Output: `Recommendation` Switch

---

### 5. Recommendation Switch Dead Ends
**Problem**: All 3 outputs (APPROVE, APPROVE_WITH_EDITS, REJECT) were empty (not connected to anything).

**Fix**: Connect outputs:
- **APPROVE** → `incrementCounter` → DB Insert Success
- **APPROVE_WITH_EDITS** → `incrementCounter` → DB Insert Success
- **REJECT** → `incrementCounter` → `UPSERT Failed Attempt`

---

### 6. Redundant MapperFunction Nodes
**Problem**: 6 inline `MapperFunction*` nodes were duplicating/overriding the Prompt Mapper subflow logic with broken code.

**Nodes to Delete**:
1. `MapperFunction` (Generator)
2. `MapperFunctionReviewer` (Expert Review)
3. `MapperFunctionReReviewer` (Re-Review)
4. `MapperFunctionInsta` (Instagram Optimizer)
5. `MapperFunctionFacebookOptimizer` (Facebook Optimizer)
6. `MapperFunctionLinkedInOptimizer` (LinkedIn Optimizer)

**Impact**: These were causing empty prompts and breaking the subflow replacements.

**Fix**: Delete all 6 nodes and connect `Call 'PromptMapper'*` directly to downstream nodes.

---

## Updated Flow Architecture

```
Parse Generated Content (has enriched data)
  ├→ setPromptVersionLLMS (preserves enriched)
  │    ↓
  │  SelectReviewerPrompt
  │    ↓
  │  packInputs4 (NOW preserves episode_title, day_number, etc.)
  │    ↓
  │  Call 'PromptMapper'1
  │    ↓
  │  Merge content + ReviewPrompts (NOW connected)
  │    ↓
  │  Expert Review
  │    ↓
  │  Parse Review JSON
  │    ↓
  │  WrapReview
  │    ↓
  │  cosile
  │    ↓
  │  setupRouter
  │    ↓
  │  [NEW] Merge Review + Enriched ← Parse Generated Content (input 2)
  │    ↓
  │  Recommendation (Switch) (NOW has outputs)
  │    ├→ APPROVE → incrementCounter → DB Insert
  │    ├→ APPROVE_WITH_EDITS → incrementCounter → DB Insert
  │    └→ REJECT → incrementCounter → UPSERT Failed Attempt
```

---

## Testing Checklist

- [ ] Brand voice rules enforced (no "Marcus", no I/me/my in output)
- [ ] Reviewer receives full context (persona, brand, enriched data)
- [ ] Review executes (Merge connected to Expert Review)
- [ ] DB insert succeeds (episode_title, day_number populated)
- [ ] APPROVE/APPROVE_WITH_EDITS routes correctly
- [ ] REJECT routes to failure handler
- [ ] All 6 MapperFunction nodes deleted
- [ ] 10 days × 3 platforms = 30 posts generated

---

## Related Files

- **Workflow JSON**: `/mnt/volume_nyc1_01/idudesRAG/json-flows/10-social-content-automation.json`
- **Fix Documentation**: `/mnt/volume_nyc1_01/idudesRAG/json-flows/farts.md`
- **Prompt Mapper Subflow**: Workflow ID `MEey0mO1avbFaAIJ`
- **Prompt DB**: `core.prompt_library` (Railway Postgres)

---

## Execution Analysis Script

Created `/mnt/volume_nyc1_01/idudesRAG/scripts/debug-n8n-execution.sh` for future debugging.

**Usage**:
```bash
./scripts/debug-n8n-execution.sh 151024
./scripts/debug-n8n-execution.sh <execution_id> <workflow_url>
```

**Features**:
- Connects to n8n Postgres DB
- Extracts failed node and error message
- Detects common failure patterns
- Generates actionable fix plan
- Saves markdown report

---

## Lessons Learned

1. **Always verify node connections** - Empty outputs cause silent failures
2. **Preserve upstream data explicitly** - Don't assume `$json` has everything
3. **Avoid inline mappers** - Use centralized subflows for consistency
4. **Test data flow end-to-end** - Missing fields cause DB constraint violations
5. **Use execution DB for debugging** - Postgres stores full execution history

---

## Next Steps

1. Deploy updated Prompt Mapper subflow to n8n
2. Update packInputs4 in workflow 10
3. Add "Merge Review + Enriched" node
4. Delete 6 MapperFunction nodes
5. Connect all empty node outputs
6. Run test execution with manual trigger
7. Verify 10-day campaign generates 30 posts
8. Monitor for NULL constraint violations

---

**Status**: Ready for deployment once nodes are updated in n8n UI.
