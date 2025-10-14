# Generate Content Node - EXACT CONFIG FROM WORKFLOW 10

## Node Details
**Type:** @n8n/n8n-nodes-langchain.agent (AI Agent)
**Name:** Generate Content

---

## Parameters

### Prompt Type
- **Setting:** Define (custom prompt)

### Text (User Prompt)
```
You are a world-class social copy generator for The Insurance Dudes.

CONTEXT
DAY: {{ $json.day_number }}
Category:
EPISODE: {{ $json.episode_title }} ({{ $json.episode_number }})
TOPIC: {{ $('Generate Enrichment Queries').item.json.tags }}
Score: {{ $json.scores.weighted_total }}/10

PRIMARY SOURCE (truncated):
{{ $node["Combine Episode Content"].json.episode_content.substring(0, 3000) }}

ENRICHMENT:
{{ $json.enriched_content_chunks }}

BRAND/TONE
- Clear, confident, practical. Teacher > hype.
- Use concrete outcomes from the sources; do NOT invent metrics.
- Plain language; skim-friendly.

OUTPUT FORMAT (EXACTLY — no extra text, no code fences)
### INSTAGRAM REEL
<1–3 punchy lines; include micro-CTA (Save/Share/Listen); 3–6 relevant hashtags>

### FACEBOOK POST
<2–4 sentences or 2–4 short bullets; one clear CTA; links allowed>

### LINKEDIN POST
<professional, concise; optional 2–4 bullets; leadership framing; one clear CTA; links allowed>

GUARDRAILS
- Preserve provided links exactly.
- No medical/financial/legal/political claims beyond the sources.
- No placeholders like [insert].
- All three sections MUST be non-empty.
```

### System Message (Options → System Message)
```
You are a formatting-strict social copy generator for The Insurance Dudes.

OUTPUT CONTRACT (MUST PASS ALL)
1) Output EXACTLY three sections, in this order, with these exact headers:
   ### INSTAGRAM REEL
   ### FACEBOOK POST
   ### LINKEDIN POST
2) No text before the first header or after the last section.
3) Each section MUST be non-empty text (may include newlines). Do not include code fences.
4) Do not invent facts. Preserve links as given.

FORMAT (OUTPUT EXACTLY LIKE THIS)
### INSTAGRAM REEL
<instagram copy here>

### FACEBOOK POST
<facebook copy here>

### LINKEDIN POST
<linkedin copy here>

SELF-CHECK (STRICT)
- If any header is missing, or any section is empty, REWRITE UNTIL ALL CHECKS PASS.
- If any extra text exists outside the three sections, REMOVE IT.
- When finished, ensure the output starts with "### INSTAGRAM REEL" and ends with the LinkedIn section text (no trailing blank lines beyond one newline).
```

---

## Expression Variables Used

### In User Prompt:
1. `{{ $json.day_number }}` - Day number from input
2. `{{ $json.episode_title }}` - Episode title
3. `{{ $json.episode_number }}` - Episode number
4. `{{ $('Generate Enrichment Queries').item.json.tags }}` - Tags from enrichment
5. `{{ $json.scores.weighted_total }}` - Quality score
6. `{{ $node["Combine Episode Content"].json.episode_content.substring(0, 3000) }}` - Truncated episode content
7. `{{ $json.enriched_content_chunks }}` - Enriched content from RAG

---

## For Cache Key Construction (Node 1)

**What to hash:**
```javascript
const model = 'gpt-5-nano';  // ← USER CHANGED THIS (was gpt-4o-mini)
const system_prompt_id = 'insurance_dudes_social_gen_v3'; // FIXED identifier

const user_content = {
  day_number: item.json.day_number,
  episode_title: item.json.episode_title,
  episode_number: item.json.episode_number,
  enriched_chunks: item.json.enriched_content_chunks,
  tags: $('Generate Enrichment Queries').item.json.tags,
  score: item.json.scores?.weighted_total,
  episode_content_preview: $node["Combine Episode Content"].json.episode_content?.substring(0, 3000)
};

const key_hash = crypto.createHash('sha256')
  .update(JSON.stringify({model, system_prompt_id, user_content}))
  .digest('hex');
```

---

## Output Structure

The node outputs structured content that gets parsed by "Parse Generated Content" node:
```json
{
  "strict_output": "### INSTAGRAM REEL\n...\n\n### FACEBOOK POST\n...\n\n### LINKEDIN POST\n...",
  "day_number": 1,
  "episode_title": "Episode 123",
  "topic_title": "..."
}
```

---

## Notes
- **Model:** User changed to `gpt-5-nano` (from default gpt-4o-mini)
- **Prompt ID:** Use `insurance_dudes_social_gen_v3` as fixed string
- **Bump version** when you change either system or user prompt text
- **System message** enforces strict formatting (3 sections, no code fences)
- **User prompt** provides context + brand voice + output template
