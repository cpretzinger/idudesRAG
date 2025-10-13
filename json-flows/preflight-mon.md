alright babe — internal automations engineer hat on, hood up. here’s the crisp, zero-fluff plan to vectorize episodes & docs and crank out elite social, using **Tools Agents + pgvector nodes** with **GPT-5-Nano (reasoning: medium) only**. no Supabase. no drama. just work.

---

# TL;DR (what we’re building)

**Drive-first ingestion → pgvector cache → Tools Agent RAG → Social generation → Review → Optimize → DB save & schedule.**
Backed by your live schema (vector ext present, `core.embeddings` with ivfflat, social tables solid) and a few surgical fixes. 

---

# 1) Reality check: your DB is already >80% there

* **Postgres 16**, extensions include **pgvector 0.8.1**, `search_path = core, public`. ✔︎ 
* **Core RAG cache**: `core.embeddings(id bigserial, file_id text, chunk_index int, text, embedding vector(1536), ... )` with **ivfflat** index (`vector_cosine_ops`) and GIN full-text on `text`, `filename`. ✔︎ 
* **Social layer** already modeled: `social_content_generated`, `social_post_performance`, `social_scheduling`, plus **file_status** and metrics. ✔︎ 
* Found one mismatch: your **reindex function** references `idx_embeddings_hnsw`/`_l2` that don’t exist; actual vector index is `idx_embeddings_vector` (ivfflat). We’ll fix that. 

Your current n8n flow already uses Tools/PG + GPT-5-Nano across nodes (nice), but some nodes have **reasoningEffort: high** — we’ll drop all to **medium** per the rule. Also the flow already does semantic enrichment against `core.embeddings` → combine → generate → review → optimize → save. ✔︎ 

---

# 2) Golden path architecture (Drive → Vector cache → Tools Agent)

**Why**: Live source of truth is Drive, but we want speed + cross-episode enrichment. So we keep a **light pgvector cache** (no document table) for chunks. You already have it.

**Pipeline**

1. **Ingest (Drive event)**

   * Receive `{file_id, filename}` via webhook.
   * If not chunked/embedded, run your embedder to write `core.embeddings` rows (`ON CONFLICT (file_id, chunk_index)` upsert).
   * Update `core.file_status` (`processing → completed/failed`). (Already present.) 

2. **Semantic Enrichment**

   * For each day/topic: build 3 query embeddings (Nano-compatible HTTP) → `SELECT ... 1 - (embedding <=> $1::vector(1536)) AS similarity ... LIMIT 5` (you’re already doing this). 

3. **Content Gen & Review** (Tools Agent using GPT-5-Nano only, reasoning: medium)

   * Extract concepts → rank → generate 3 posts → review → apply fixes → per-platform optimize. (All nodes exist; we’ll tighten prompts and settings). 

4. **Persist & schedule**

   * Insert into `core.social_content_generated` (already implemented) + metric log. Later, a scheduler reads rows with `status='pending_schedule'` and posts via your GHL/LinkedIn/FB connectors. 

---

# 3) Surgical DB fixes & helpers (copy-paste safe SQL)

## 3.1 Fix the broken reindex helper

```sql
-- Replace stale function that points to non-existent indexes
CREATE OR REPLACE FUNCTION core.reindex_vectors()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  -- actual vector index name present in DB (ivfflat)
  PERFORM 1 FROM pg_class WHERE relname = 'idx_embeddings_vector';
  IF FOUND THEN
    EXECUTE 'REINDEX INDEX CONCURRENTLY core.idx_embeddings_vector';
  END IF;
END;
$$;
```

(Old body referenced `idx_embeddings_hnsw` / `_l2` which aren’t in your index list.) 

## 3.2 Bullet-proof match function for Tools Agent (cosine)

```sql
-- One-function RAG search for Tools Agent nodes
CREATE OR REPLACE FUNCTION core.match_embeddings(
  q vector(1536),
  top_k int DEFAULT 5,
  exclude_file_id text DEFAULT NULL
)
RETURNS TABLE (
  file_id text,
  filename text,
  chunk_index int,
  text text,
  similarity double precision
)
LANGUAGE sql
STABLE
AS $$
  SELECT e.file_id, e.filename, e.chunk_index, e.text,
         1 - (e.embedding <=> q) AS similarity
  FROM core.embeddings e
  WHERE (exclude_file_id IS NULL OR e.file_id <> exclude_file_id)
  ORDER BY e.embedding <=> q
  LIMIT top_k;
$$;
```

Matches your index opclass (`vector_cosine_ops`) and dim (1536). 

> **Heads-up:** One query in your SOT shows vector dim derived as **1532** — that’s a calculation bug in the dimension query, not the actual type (it’s `vector(1536)`). Keep using **1536**. If you want a safe introspection:

```sql
-- safer: parse from formatted_type
SELECT (regexp_match(format_type(a.atttypid, a.atttypmod), '\((\d+)\)'))[1]::int AS dim
FROM pg_attribute a
JOIN pg_class c ON c.oid = a.attrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname='core' AND c.relname='embeddings' AND a.attname='embedding';
```

(Prevents wrong math on typmod.) 

## 3.3 Query-time tuning for ivfflat (optional but juicy)

At runtime in your PG nodes before calling `match_embeddings`:

```sql
SET ivfflat.probes = 10;  -- trade recall vs. latency; 10–20 is a solid start
```

(Keep index `WITH (lists=100)` as is for now.) 

## 3.4 Idempotency on generated content (avoid dup days)

```sql
ALTER TABLE core.social_content_generated
ADD CONSTRAINT ux_social_episode_day UNIQUE (episode_title, day_number);
```

(Your flow already does some in-memory idempotency; this nails it at the DB.) 

---

# 4) Tools Agent + n8n upsides (precise changes)

## 4.1 Enforce **GPT-5-Nano ONLY**, reasoning **medium**

In your flow JSON:

* Nodes named **Extract Concepts**, **Generate Content**, **Expert Review**, **Optimize Instagram/Facebook/LinkedIn** already declare `model: "gpt-5-nano"` but a few set `reasoningEffort: "high"`.
  Set for all LM nodes:

```json
"model": "gpt-5-nano",
"options": { "reasoningEffort": "medium" }
```

(Apply to node IDs: `e3dcc61f-...`, `db8b5715-...`, `b7ba7693-...`, `717e4ba8-...`, `2e91c972-...`, and any other LM nodes.) 

## 4.2 Replace raw SQL similarity call with function call (cleaner)

Change your **Search Similar (Q1)** node query from the inline `SELECT ... 1 - (embedding <=> $1::vector(1536))` to:

```sql
SELECT * FROM core.match_embeddings($1::vector(1536), 5, $2);
```

And keep your `queryReplacement` as `[ JSON.stringify(q1), $json.file_id ]`. 

## 4.3 Keep the HTTP embeddings step (Nano-friendly)

You’re using `text-embedding-3-small` (1536 dims) — aligns with the table. ✅ No change needed. 

## 4.4 Tighten the episode assembly

Your **Combine Episode Content** + **cleanAndPrep** nodes already sanitize, normalize title/episode number, and cap text. Good. Keep. (Minor nit: ensure `episode_title` normalization maps typos like “Episaode” — you already regex that. 😘) 

---

# 5) Ingestion contract (Drive → embeddings → status)

**Recommended n8n sub-workflow** (keeps main clean):

1. **Drive fetch**: download/transcript.
2. **Chunk** (300–1200 tokens), output `{file_id, chunk_index, text}`.
3. **Embed** via HTTP (Nano-friendly).
4. **UPSERT**:

```sql
INSERT INTO core.embeddings (file_id, filename, chunk_index, text, chunk_size, embedding)
VALUES ($1,$2,$3,$4,$5,$6::vector(1536))
ON CONFLICT (file_id, chunk_index)
DO UPDATE SET text=EXCLUDED.text,
              chunk_size=EXCLUDED.chunk_size,
              embedding=EXCLUDED.embedding,
              updated_at=now();
```

5. **Update status** in `core.file_status` → `completed` or `failed`.
   (Your schema & indexes already support this pattern.) 

---

# 6) Agent prompts (pre-set, crisp, Nano-happy)

You’ve got solid prompt scaffolding in the JSON: **Extract Concepts → Generate → Expert Review → Per-platform Optimize**. Keep the exact JSON-only outputs for parsing (already done), just ensure all are **Nano + medium**. 

---

# 7) Safety & observability

* **Metrics**: you already log `social_content_batch_completed` with tags — keep & expand (add `file_id`, `episode_number`). 
* **Search health**: add a quick “smoke test” node calling `core.match_embeddings` with a static query (e.g., “lead generation framework”) on deploy.
* **Vacuum/Analyze**: schedule weekly `ANALYZE core.embeddings;` and call `core.reindex_vectors()` if index bloat creeps.

---

# 8) Acceptance checklist (what “done” looks like)

* [ ] All LM nodes use **gpt-5-nano** / **reasoningEffort=medium**. 
* [ ] `core.reindex_vectors()` fixed to real index names. 
* [ ] `core.match_embeddings()` created; all search calls use it.
* [ ] Ingestion sub-flow writes/updates `core.embeddings` with `ON CONFLICT` and updates `core.file_status`. 
* [ ] `ux_social_episode_day` unique constraint added.
* [ ] Social content saved with `status='pending_schedule'`, then scheduled by a downstream job. 

---

# 9) One live doc to prove the pipe’s wired

Your `file_status` shows a **completed** episode:
`Episaode_733_HOW_YOU_CAN_SPEND_MORE_TO_ACQUIRE_INSURANCE_CLIENTS` with a valid `file_id`. Perfect seed for a dry run of the social pipeline. 

---

you bring the episodes; I’ll make the content machines hum. flip those LM nodes to Nano/medium, drop in the SQL above, and your Tools Agent’s about to run like a thief in Nike Vaporflys. let’s ship it, sexy. 🚀

**Sources (live SOT + current flow):**  
