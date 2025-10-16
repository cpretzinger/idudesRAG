Workflow 01 ALREADY:
  1. ✅ Classifies content (episode vs book)
  2. ✅ Chunks + embeds
  3. ✅ Stores in core.embeddings with content_type
  4. ✅ Triggers Workflow 10 via webhook!

  THIS MEANS:
  - You DON'T need to rebuild classifier in Workflow 10
  - Workflow 10 receives { file_id, filename } from Workflow 01
  - Workflow 10 just needs to check content_type from DB

  ---
  ⚡ REVISED 1HR 48MIN PLAN

  PHASE 1: MINIMAL WORKFLOW 10 CHANGES (35 MIN)

  Step 1: Remove Redundant Classifier (5 min)

  WHAT YOU DO:
  - Workflow 10 already receives file_id from Workflow 01 webhook
  - Delete any classifier code you were going to add
  - Instead, add DB query to check content_type

  Node: "Get Content Type" (Postgres - FIRST node after webhook)
  SELECT content_type, filename, chunk_index, text
  FROM core.embeddings
  WHERE file_id = $1
  LIMIT 1;
  Query Parameters: {{ [$json.file_id] }}

  ---
  Step 2: Route by Content Type (3 min)

  Node: "Route by Type" (Switch)
  - Input: Get Content Type
  - Output 1: content_type equals episode → continue to social generation
  - Output 2: content_type equals book → Stop (respond with "RAG only")

  ---
  Step 3: Fix CTA Injection (7 min)

  Node: "Inject CTAs" (Code - after Parse Generated Content)

  // Inject CTAs - Drop into Code node
  const day = Number($json.day_number || 1);

  // Days 1-5: Engagement CTA
  // Days 6-10: Skool CTA
  const cta = (day <= 5)
    ? "\n\n👉 Like, comment, and subscribe for more!"
    : "\n\n👉 Join our FREE Skool community: https://www.skool.com/agentelite/about";

  const addCTA = (content) => {
    if (!content) return content;
    const hasSkool = content.includes('skool.com');
    const hasSubscribe = content.toLowerCase().includes('subscribe');

    // Don't duplicate CTAs
    if (hasSkool || hasSubscribe) return content;

    return content + cta;
  };

  return [{
    json: {
      ...$json,
      instagram_content: addCTA($json.instagram_content),
      facebook_content: addCTA($json.facebook_content),
      linkedin_content: addCTA($json.linkedin_content),
      cta_applied: cta,
      cta_type: day <= 5 ? 'engagement' : 'skool'
    }
  }];

  ---
  Step 4: Update Prompt to v4 (10 min)

  Run in Railway Postgres:

  INSERT INTO core.prompt_library (prompt_key, version, role, content, tags)
  VALUES (
    'social_generator',
    'v4',
    'system',
    'You are a world-class social copy generator for The Insurance Dudes.

  ## BRAND VOICE
  - Clear, confident, practical
  - Helpful teacher, not hype
  - NO first-person (I/me/my)
  - NO "Marcus" references
  - Concrete outcomes, not jargon

  ## OUTPUT FORMAT (STRICT)
  ### INSTAGRAM REEL
  <1-3 punchy lines>
  <3-6 hashtags>

  ### FACEBOOK POST
  <2-4 sentences or bullets>

  ### LINKEDIN POST
  <professional, 2-4 bullets>

  ## CTA RULES
  - CTA added automatically by system
  - Days 1-5: engagement focus
  - Days 6-10: Skool community

  ## PROHIBITED
  - Medical/financial/legal claims beyond source
  - Politics, disparagement
  - Placeholders like [insert]
  - Making up data/metrics',
    ARRAY['social', 'v4']
  )
  ON CONFLICT (prompt_key, version, role)
  DO UPDATE SET content = EXCLUDED.content, updated_at = NOW();

  Update setPromptVersion node:
  Change version from v3 → v4

  ---
  Step 5: Fix ALL Known Bugs (10 min)

  Fix 1: Parse Generated Content (JSON unwrapping)
  // REPLACE existing code with this
  const readFromInputs = () => {
    const all = $input.all();
    for (const it of all) {
      const j = it.json || {};
      let candidate = j.response_data || j.generated_content || j.strict_output || j.output || j.text;

      if (typeof candidate === 'string') {
        candidate = candidate.trim();
        if (candidate) {
          // FIX: Unwrap JSON-encoded cache responses
          try {
            const parsed = JSON.parse(candidate);
            if (typeof parsed === 'string') return parsed;
          } catch {}
          return candidate;
        }
      }
    }
    return '';
  };

  const content = readFromInputs();
  const ig = (content.match(/###\s*INSTAGRAM REEL\s*\n([\s\S]*?)(?=###|$)/i) || [])[1] || '';
  const fb = (content.match(/###\s*FACEBOOK POST\s*\n([\s\S]*?)(?=###|$)/i) || [])[1] || '';
  const li = (content.match(/###\s*LINKEDIN POST\s*\n([\s\S]*?)(?=###|$)/i) || [])[1] || '';

  return [{
    json: {
      ...$json,
      instagram_content: ig.trim(),
      facebook_content: fb.trim(),
      linkedin_content: li.trim()
    }
  }];

  Fix 2: Delete Merge1 (just delete the node)

  Fix 3: Delete 6 MapperFunction nodes (delete them all)

  Fix 4: Fix packInputs4
  // REPLACE with this
  const upstream = $('setPromptVersionLLMS').first().json || {};
  const prompts = $input.all().map(it => it.json);

  return [{
    json: {
      prompt_key: upstream.prompt_key,
      version: upstream.prompt_version,
      prompts,
      // PRESERVE ALL enriched data
      episode_title: upstream.episode_title,
      day_number: upstream.day_number,
      day_theme: upstream.day_theme,
      topic_title: upstream.topic_title,
      file_id: upstream.file_id,
      work_id: upstream.work_id,
      instagram_content: upstream.instagram_content,
      facebook_content: upstream.facebook_content,
      linkedin_content: upstream.linkedin_content,
      persona: upstream.persona || {},
      brand: upstream.brand || {},
      enriched: upstream.enriched || {}
    }
  }];

  Fix 5: Connect Recommendation Switch outputs
  - APPROVE → incrementCounter → UpsertApproved
  - APPROVE_WITH_EDITS → ApplyReviewFixes → Parse 3 Sections → incrementCounter → UpsertApproved
  - REJECT → incrementCounter → UPSERT Failed Attempt

  Fix 6: Add Merge Review + Enriched (before Recommendation)
  // Merge Review + Enriched
  const review = $input.first().json;
  const enriched = $input.last().json;

  return [{
    json: {
      review: review.review || review,
      recommendation: review.recommendation,
      approved: review.approved,
      episode_title: enriched.episode_title,
      day_number: enriched.day_number,
      topic_title: enriched.topic_title,
      file_id: enriched.file_id,
      work_id: enriched.work_id,
      instagram_content: enriched.instagram_content,
      facebook_content: enriched.facebook_content,
      linkedin_content: enriched.linkedin_content
    }
  }];