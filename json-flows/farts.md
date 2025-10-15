# Workflow 10 Cache Integration - Node Configs

**Goal:** Add unified API caching to workflow 10 (social-content-automation) to reduce OpenAI costs.

**Strategy:** Start with **LLM Cache** (highest ROI), then expand to embeddings/review caches.

---

## Phase 1: LLM Generation Cache (Add These 7 Nodes)

### **Cache Integration Point: Before "Generate Content" Node**

---

### Node 1: Build Generation Cache Key
**Type:** Code (n8n-nodes-base.code)
**Name:** Build Gen Cache Key

**Connections:**
- **Input from:** "Combine Enrichment Data" (main output)
- **Output to:** "Check Gen Cache" (main)

**Parameters:**
- **Mode:** Run Once for All Items
- **Language:** JavaScript
- **Code:**
```javascript
const crypto = require('crypto');

const items = $input.all();
return items.map(item => {
  const model = 'gpt-5-nano';
  const system_prompt_id = 'insurance_dudes_social_gen_v3'; // FIXED identifier

  const user_content = {
    day_number: item.json.day_number,
    episode_title: item.json.episode_title,
    enriched_chunks: item.json.enriched_content_chunks
  };

  const key_hash = crypto.createHash('sha256')
    .update(JSON.stringify({model, system_prompt_id, user_content}))
    .digest('hex');

  return {
    json: {
      ...item.json,
      gen_cache_key: key_hash,
      gen_model: model,
      gen_prompt_version: system_prompt_id
    }
  };
});
```

**Notes:**
- Uses FIXED `system_prompt_id` instead of full prompt text
- Bump version string when prompt changes to invalidate cache
- Creates deterministic cache key from inputs

---

## 📋 DROP-IN: Generate Content Node Configuration

**⚠️ IMPORTANT:** After adding Node 1 (Build Gen Cache Key), you need to configure your existing "Generate Content" node.

### Node: Generate Content (YOUR EXISTING AI AGENT NODE)
**Type:** @n8n/n8n-nodes-langchain.agent
**Name:** Generate Content

**Connections:**
- **Input from:** "Cache Hit?" (false path) → **REWIRE FROM "Combine Enrichment Data"**
- **Output to:** "Format Fresh Generation" (main) → **REWIRE FROM "Parse Generated Content"**

**Parameters:**

#### Prompt Type
- **Setting:** Define (custom prompt)

#### Text (User Prompt)
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

#### Options → System Message
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

**Options:**
- **Model:** gpt-5-nano (or your preferred model)
- **Temperature:** 0.7 (adjust as needed)

**Notes:**
- This node only runs on CACHE MISS (false path from Node 3)
- Output goes to Node 5 (Format Fresh Generation) for normalization
- The system + user prompts above are YOUR ACTUAL PROMPTS from workflow 10

---

### Node 2: Check Gen Cache
**Type:** Postgres (n8n-nodes-base.postgres)
**Name:** Check Gen Cache

**Connections:**
- **Input from:** "Build Gen Cache Key" (main)
- **Output to:** "Cache Hit?" (main)

**Credentials:** Your Railway PostgreSQL connection

**Parameters:**
- **Operation:** Execute Query
- **Query:**
```sql
SELECT
  key_hash,
  response_data,
  hit_count,
  created_at
FROM core.api_cache
WHERE key_hash = $1
  AND cache_type = 'generation'
LIMIT 1;
```
- **Query Parameters:** `={{ $json.gen_cache_key }}`

**Options:**
- **Always Output Data:** Enabled (returns empty array on miss)

**Notes:**
- Checks if we've generated this exact content before
- Returns cached result if found

---

### Node 3: Cache Hit?
**Type:** IF (n8n-nodes-base.if)
**Name:** Cache Hit?

**Connections:**
- **Input from:** "Check Gen Cache" (main)
- **Output to (true):** "Use Cached Generation" (main)
- **Output to (false):** "Generate Content" (main) → **Your existing node**

**Parameters:**
- **Conditions:**
  - **Condition 1:**
    - **Value 1:** `={{ $json.response_data }}`
    - **Operation:** Is Not Empty
    - **Combine:** AND
  - **Condition 2:**
    - **Value 1:** `={{ $json.key_hash }}`
    - **Operation:** Is Not Empty

**Notes:**
- Checks if cache returned a result
- True path = cache hit (skip LLM)
- False path = cache miss (call LLM)

---

### Node 4: Use Cached Generation
**Type:** Code (n8n-nodes-base.code)
**Name:** Use Cached Generation

**Connections:**
- **Input from:** "Cache Hit?" (true path)
- **Output to:** "Merge Cached + Fresh" (input 1)

**Parameters:**
- **Mode:** Run Once for All Items
- **Language:** JavaScript
- **Code:**
```javascript
const items = $input.all();
return items.map(item => {
  const cached = item.json.response_data;

  return {
    json: {
      ...item.json,
      generated_content: cached.content || cached,
      from_cache: true,
      cache_hit_count: item.json.hit_count || 0
    }
  };
});
```

**Notes:**
- Extracts cached content
- Marks as `from_cache: true` for tracking
- Bypasses expensive LLM call

---

### Node 5: Format Fresh Generation
**Type:** Code (n8n-nodes-base.code)
**Name:** Format Fresh Generation

**Connections:**
- **Input from:** "Generate Content" (main) → **Your existing node**
- **Output to:** "Store Gen Cache" (main)

**Parameters:**
- **Mode:** Run Once for All Items
- **Language:** JavaScript
- **Code:**
```javascript
const items = $input.all();
return items.map(item => {
  return {
    json: {
      ...item.json,
      generated_content: item.json.output || item.json, // Adjust based on your node output
      from_cache: false,
      cache_hit_count: 0
    }
  };
});
```

**Notes:**
- Normalizes LLM output format to match cached format
- Marks as `from_cache: false` for tracking
- Prepares data for cache storage

---

### Node 6: Store Gen Cache
**Type:** Postgres (n8n-nodes-base.postgres)
**Name:** Store Gen Cache

**Connections:**
- **Input from:** "Format Fresh Generation" (main)
- **Output to:** "Merge Cached + Fresh" (input 2)

**Credentials:** Your Railway PostgreSQL connection

**Parameters:**
- **Operation:** Execute Query
- **Query:**
```sql
INSERT INTO core.api_cache (
  key_hash,
  cache_type,
  model,
  model_version,
  request_payload,
  response_data,
  cost_usd,
  hit_count
) VALUES (
  $1,
  'generation',
  $2,
  $3,
  $4::jsonb,
  $5::jsonb,
  $6,
  0
)
ON CONFLICT (key_hash)
DO UPDATE SET
  hit_count = core.api_cache.hit_count + 1,
  response_data = EXCLUDED.response_data;
```
- **Query Parameters:**
```javascript
={{
  [
    $('Build Gen Cache Key').item.json.gen_cache_key,
    $('Build Gen Cache Key').item.json.gen_model,
    $('Build Gen Cache Key').item.json.gen_prompt_version,
    JSON.stringify($('Combine Enrichment Data').item.json),
    JSON.stringify($json.generated_content),
    0.001  // Estimate cost, update based on actual
  ]
}}
```

**Options:**
- **Continue on Fail:** Enabled (don't break workflow if cache write fails)

**Notes:**
- Stores LLM response for future reuse
- Uses UPSERT to handle race conditions
- Passes through `$json` with formatted content (not DB metadata)
- Removed `RETURNING *` - we pass through the input data

---

### Node 7: Merge Cached + Fresh
**Type:** Merge (n8n-nodes-base.merge)
**Name:** Merge Cached + Fresh

**Connections:**
- **Input 1 from:** "Use Cached Generation" (main)
- **Input 2 from:** "Store Gen Cache" (main)
- **Output to:** "Parse Generated Content" (main) → **Your existing node**

**Parameters:**
- **Mode:** Append
- **Output Data:** Input 1 + Input 2

**Notes:**
- Combines cache hits and fresh generations
- Both inputs now have identical structure (generated_content, from_cache, etc.)
- Next node ("Parse Generated Content") receives all items in consistent format

---

## Connection Summary (What to Rewire)

### **OLD FLOW:**
```
Combine Enrichment Data → Generate Content → Parse Generated Content
```

### **NEW FLOW (CORRECTED):**
```
Combine Enrichment Data
  → Build Gen Cache Key (Node 1)
  → Check Gen Cache (Node 2)
  → Cache Hit? (Node 3)
        TRUE → Use Cached Generation (Node 4)
                  ↓
                Merge Cached + Fresh (Node 7)

        FALSE → Generate Content (existing)
                  → Format Fresh Generation (Node 5)
                  → Store Gen Cache (Node 6)
                      ↓
                    Merge Cached + Fresh (Node 7)

  → Parse Generated Content (existing)
```

**KEY INSIGHT:** Node 5 (Format Fresh Generation) ensures BOTH paths output the same data structure before merging. Without it, you'd be merging:
- Path 1: Cached content object
- Path 2: Database INSERT metadata ❌

Now both paths output:
```json
{
  "generated_content": "...",
  "from_cache": true/false,
  "cache_hit_count": 0
}
```

---

## Phase 2: Embedding Cache (Add Later)

**Integration Point:** Before "Build Query Embeddings" (HTTP Request node)

**Nodes Needed:** 7 similar nodes (Build Key, Check Cache, IF, Use Cached, Format Fresh, Store Cache, Merge)

**Same pattern, different cache_type:** `'embedding'`

---

## Phase 3: Review Cache (Add Later)

**Integration Point:** Before "Expert Review" (GPT-5-Nano node)

**Nodes Needed:** 7 similar nodes

**Same pattern, different cache_type:** `'review'`

---

## Testing Checklist

After adding cache nodes:

1. **First Run (Cache Miss):**
   - [ ] Workflow completes normally
   - [ ] Cache entry created in `core.api_cache`
   - [ ] `hit_count = 0`
   - [ ] `from_cache = false` in output

2. **Second Run (Same Input):**
   - [ ] "Cache Hit?" takes TRUE path
   - [ ] "Generate Content" node NOT executed
   - [ ] Result identical to first run
   - [ ] `hit_count = 1` in database
   - [ ] `from_cache = true` in output

3. **Different Input:**
   - [ ] Cache miss (new key_hash)
   - [ ] New LLM call made
   - [ ] New cache entry created

4. **Cost Tracking:**
   - [ ] Query total cache hits: `SELECT cache_type, SUM(hit_count) FROM core.api_cache GROUP BY cache_type;`
   - [ ] Calculate savings: `hits × avg_cost_per_call`

---

## Quick Reference: Node Types Needed

| Node # | Type | Name |
|--------|------|------|
| 1 | Code | Build Gen Cache Key |
| 2 | Postgres | Check Gen Cache |
| 3 | IF | Cache Hit? |
| 4 | Code | Use Cached Generation |
| 5 | Code | Format Fresh Generation |
| 6 | Postgres | Store Gen Cache |
| 7 | Merge | Merge Cached + Fresh |

**Total:** 7 nodes to add per cache integration point

**Priority Order:**
1. Generation cache (highest cost)
2. Embedding cache (moderate cost)
3. Review cache (lowest cost)

---

## Why 7 Nodes Instead of 6?

**Original problem:** Merging incompatible data types
- Cache hit path: Content object
- Cache miss path: Database INSERT response ❌

**Solution:** Node 5 (Format Fresh Generation)
- Normalizes LLM output BEFORE storing
- Ensures both paths have identical structure
- Merge node receives consistent data

**Alternative (not recommended):**
- Have Node 6 return `RETURNING *` and extract in Node 7
- More complex, adds DB overhead
- Current approach is cleaner

---

**Implementation Time Estimate:** 30-45 minutes per cache integration
**Testing Time Estimate:** 15 minutes per cache
**Expected Cost Reduction:** 50-80% on duplicate content generation

Yes—Cohere is a great fit for **Rank Topics**. Here’s the clean way to upgrade your current code-only ranking into a **hybrid** that uses Cohere’s **Rerank** (fast, cheap, purpose-built for ranking) while keeping your existing heuristics for tie-breakers.

---

## TL;DR Recommendation

* **Use Cohere Rerank** to semantically rank your 15–20 candidate concepts against your goals (query).
* Keep your **W-weights** (actionability, platform_fit, proof_type, hook_potential) as a **secondary scoring layer**.
* **Do not** change your pgvector/embeddings DB; this step is just picking the top concepts before enrichment.
* Add a tiny **cache wrapper** so repeated runs don’t pay again.

---

## Where it lives in your flow

```
Extractor / Concept List  →  Build Rerank Query (Code)
                           →  Cohere Rerank (HTTP)
                           →  Merge & Score (Code)  →  TOP N concepts
                           →  Generate Enrichment Queries  →  (your existing pipeline)
```

---

## 1) Build the Rerank query (Code node)

Create a **Code** node right after you have your concept array.

**Input expected:** `$json.concepts` = `[{ title, summary, tags, ... }]`

**Code (paste):**

```js
// Build a single query that reflects your ranking intent
const day  = $json.day_number || '';
const topic = $json.concept || $json.topic_title || '';
const goals = [
  'insurance P&C agency growth',
  'practical frameworks',
  'clear CTA potential',
  'telefunnel alignment (lead→call→booked→bind→retention)'
];

const query = `Rank concepts for Insurance Dudes content. Prioritize:
1) agency growth practicality, 2) clear framework, 3) CTA potential, 4) TeleFunnel mapping.
Context: Day ${day} — Topic: ${topic}.`;

const docs = ($json.concepts || []).map((c, i) => ({
  id: i,
  text: [
    c.title ? `TITLE: ${c.title}` : '',
    c.summary ? `SUMMARY: ${c.summary}` : '',
    (Array.isArray(c.tags) && c.tags.length) ? `TAGS: ${c.tags.join(', ')}` : ''
  ].filter(Boolean).join('\n')
}));

return [{ json: { ...$json, rerank_query: query, rerank_docs: docs } }];
```

---

## 2) Cohere Rerank (HTTP Request)

**Node:** HTTP Request
**Method:** POST
**URL:** `https://api.cohere.ai/v2/rerank`
**Headers:**

* `Authorization: Bearer {{$env.COHERE_API_KEY}}`
* `Content-Type: application/json`

**Send Body as:** JSON
**Body (Expression ON → paste):**

```js
{{
JSON.stringify({
  model: "rerank-3.5",      // or "rerank-3" if you prefer
  query: $json.rerank_query,
  documents: $json.rerank_docs.map(d => ({ id: String(d.id), text: d.text })),
  top_n: 20,                 // same as docs length or just let Cohere return all
  return_documents: false
})
}}
```

**Response to keep:** `$.results` → an array like:
`[{ index: <int>, relevance_score: <float>, document: { id: "…" }}, …]`

---

## 3) Merge Cohere scores + your heuristics (Code)

Place this **after** the HTTP node.

**Code (paste):**

```js
// Input: $json has rerank_docs (with id) and HTTP response at $json.results (n8n attaches)
// If your HTTP node returns into a separate item, merge by position first or get it via $input.all()

const results = $json.results || $json.data || $json; // be flexible if provider shape differs
const byIdScore = new Map();

(results || []).forEach(r => {
  const id = r.document?.id || String(r.index);
  const score = Number(r.relevance_score || r.score || 0);
  byIdScore.set(String(id), score);
});

// Bring in original concepts
const concepts = $json.concepts || [];

// Your existing W-weights
const W = { a: 0.35, p: 0.25, r: 0.20, v: 0.15, e: 0.05 };

// Heuristic scorer (same as before, but we’ll blend with Cohere)
const hScore = (c) => {
  const actionability = String(c.actionability || 'medium');
  const proofType = String(c.proof_type || 'story');
  const platformFit = String(c.platform_fit || 'all');
  const hookPotential = Number(c.hook_potential || 7) || 7;
  const a = 7 + (actionability === 'high' ? 2 : actionability === 'medium' ? 1 : 0) + (proofType !== 'none' ? 1 : 0);
  const p = platformFit === 'all' ? 10 : 8;
  const r = proofType === 'data' ? 9 : (proofType === 'framework' ? 8 : 7);
  const v = Math.max(1, Math.min(10, hookPotential));
  const en = 7;
  return a * W.a + p * W.p + r * W.r + v * W.v + en * W.e; // ~1-10 scale
};

// Blend Cohere relevance (0–1) with heuristic (~1–10 normalized)
const blended = concepts.map((c, i) => {
  const cohere = byIdScore.get(String(i)) ?? 0;
  const heuristic = hScore(c);
  // Normalize heuristic to 0–1 by dividing by 10; blend weights: 0.7 cohere, 0.3 heuristic (tune as you like)
  const final = 0.7 * cohere + 0.3 * (heuristic / 10);
  return { ...c, scores: { cohere, heuristic, blended: Math.round(final * 1000) / 1000 } };
});

// Sort by blended descending, pick top N
const TOP_N = 10;
const top = blended.sort((a,b) => b.scores.blended - a.scores.blended).slice(0, TOP_N);

// Pass forward (keep episode meta, file_id for enrichment)
return [{ json: { ...$json, concepts_ranked: top } }];
```

> Now wire **Generate Enrichment Queries** to read `concepts_ranked[0]` (or allow user to pick). You can still use your old code as fallback if the Cohere call errors.

---

## 4) (Optional) Cache the rerank call (tiny PG table)

**Why:** ranking the same list day-to-day should be free.

```sql
CREATE TABLE IF NOT EXISTS core.rerank_cache (
  key_hash  text PRIMARY KEY,   -- sha256(model+query+doc_fingerprints)
  model     text NOT NULL,
  query     text NOT NULL,
  result    jsonb NOT NULL,
  created_at timestamptz DEFAULT now()
);
```

**Key builder (Code before HTTP):**

```js
const crypto = require('crypto');
const model = 'rerank-3.5';
const query = $json.rerank_query;
const fp = ($json.rerank_docs || []).map(d => d.text.slice(0, 256)).join('\n---\n');
const key_hash = crypto.createHash('sha256').update(JSON.stringify({model,query,fp})).digest('hex');
return [{ json: { ...$json, rerank_model: model, rerank_key_hash: key_hash } }];
```

**PG check:** `SELECT result FROM core.rerank_cache WHERE key_hash=$1 LIMIT 1;`
**On hit:** set `$json.results = row.result.results` and **skip HTTP**.
**On miss:** call Cohere, then **upsert**:

```sql
INSERT INTO core.rerank_cache(key_hash, model, query, result)
VALUES ($1, $2, $3, $4::jsonb)
ON CONFLICT (key_hash) DO NOTHING;
```

---

## 5) Alternative: Cohere Command-R for multi-criteria scoring

If you want the model to output **per-criterion scores** (voice fit, TeleFunnel alignment, hook strength), you can add a **second pass** using **Command-R** to produce a small JSON per concept and then sort. It’s slower/costlier than Rerank, so I recommend **Rerank → (optional) Command-R on the top 15** only.

**HTTP Request → POST `https://api.cohere.ai/v2/chat`**

* Headers: `Authorization: Bearer {{$env.COHERE_API_KEY}}`, `Content-Type: application/json`
* Body (per batch or per concept):

```js
{{
JSON.stringify({
  model: "command-r",
  temperature: 0,
  messages: [
    { role: "system", content:
      "You are scoring concept ideas for The Insurance Dudes. Return JSON only." },
    { role: "user", content:
      `Score this concept on 0-10:
       - tele_funnel_fit (lead->call->booked->bind->retention)
       - practicality
       - hook_strength
       - leadership/brand voice
       Concept:
       TITLE: ${$json.title}
       SUMMARY: ${$json.summary}
       TAGS: ${($json.tags||[]).join(', ')}

       Return: {"tele_funnel_fit":int,"practicality":int,"hook_strength":int,"voice_fit":int,"notes":"string"}`
    }
  ],
  response_format: { type: "json_object" }
})
}}
```

Collect scores, average/weight them, and blend with the Cohere Rerank score if you like.

---

## 6) Costs & performance

* **Rerank-3.5** is purpose-built: very good **semantic ordering**, faster/cheaper than doing a full chat LLM score on each item.
* Hybrid scoring (0.7 * rerank + 0.3 * heuristics) gives you **stable, controllable** results. Tune to taste.
* Cache the rerank result with a key on **model + query + doc fingerprints** and you basically pay once.

---

## 7) Minimal changes to the rest of your pipeline

* Keep embeddings + pgvector as-is.
* Keep enrichment, generation, review, router, and UPSERT logic exactly the same.
* The only new parts: **Build Rerank Query → Cohere Rerank → Merge & Score → pick top concept(s).**

If you want, I can hand you a tiny n8n export fragment for the three new nodes (Query Builder → Rerank (HTTP) → Merge & Score) that plugs right into your existing “Rank Topics” location.
