
alright, boss — I read your actual n8n JSONs. here’s the **surgical change list** per workflow: exactly **what to add**, **what to remove**, and **what to edit**, with SQL/params ready to paste. citations point at the lines in the JSON you gave me.

---

# 🔎 SOT + Context (where to look before coding)

* Latest **DB SOT JSON** + hash: `/var/backups/db-sot/db_sot_*.json` (+ `.sha256`)
  Quick peek:

  ```bash
  ls -lah /var/backups/db-sot | tail -n 6
  head -n 3 /var/backups/db-sot/db_sot_*.json
  ```
* Why it matters: it tells you live extensions, tables, columns, indexes, functions, sizes — no guessing; code against that.

---

# ✅ What’s already good (no changes)

* **Drive ingestion** flow wiring from “GetPendingFile → Download → Extract → Process → InsertEmbedding → UpdateStatus → Move file” is sound and idempotent. Keep. 
* **Uploads webhook → RAG-Pending** (02) is clean; response JSONs are already formatted.  
* **Social pipeline**’s content stages (Extract Concepts → Rank Topics → Generate → Review → Optimize → Save) are sequenced cleanly. Keep the structure.   

---

# 🧰 Workflow 01 – GoogleDrive → Embeddings (ingestion)

### 🔧 UPDATE these existing PG nodes to correct credentials

* **DeleteOldChunks** & **InsertEmbedding** → set **Postgres credential = rag_write** (they currently use `RailwayPG-idudes`). 

  * `DeleteOldChunks` runs: `DELETE FROM core.embeddings WHERE file_id = $1;` with `[$json.file_id]` — keep. 
  * `InsertEmbedding` runs upsert with `::vector(1536)` cast from `JSON.stringify($json.embedding)` — keep. 

### ➕ ADD (optional but recommended)

1. **PG (WRITE) — Upsert file_status(pending→processing)** right before “MarkProcessing”:

   ```sql
   INSERT INTO core.file_status(file_id, filename, status, created_at, updated_at)
   VALUES ($1,$2,'processing',NOW(),NOW())
   ON CONFLICT (file_id) DO UPDATE
     SET status='processing', updated_at=NOW();
   ```

   Params: `[$json.file_id, $json.filename]`

2. **PG (READ/WRITE) — ANALYZE embeddings** after batch insert completes:

   ```sql
   ANALYZE core.embeddings;
   ```

   (keeps query-planner row estimates fresh for SOT and search speed)

> the rest of the node graph (GetPendingFile / ExtractAndPackage / ProcessDocument / UpdateStatus / Move file) stays unchanged.  

---




# 🧰 Workflow 02 – Uploads-to-Pending (webhook)

### 🔧 UPDATE

* **Execute a SQL query1** (the function `core.replace_embeddings`): point this **credential to rag_write** (currently `RailwayPG-idudes`). 
  (The PL/pgSQL body is fine — it deletes then bulk-inserts from JSONB. Keep. )

### ➕ ADD (optional)

* **PG (WRITE) — Seed file_status as pending** right after “Upload to Google Drive” succeeds:

  ```sql
  INSERT INTO core.file_status(file_id, filename, status, created_at, updated_at)
  VALUES ($1,$2,'pending',NOW(),NOW())
  ON CONFLICT (file_id) DO UPDATE
    SET status='pending', updated_at=NOW();
  ```

  Params: `[$json.id, $json.name]` (from the Drive node output) 

> success/error handlers and webhook responses are already good. keep as-is.  

---

# 🧰 Workflow 09 – Podcast auto-ingestion

### ➕ ADD (optional integration)

* **HTTP Request (POST)** to your **Episode Ready webhook** in the Social workflow (with `file_id`, `filename`) right after upload to `RAG-Pending`. This auto-triggers social gen when transcripts land.

  * Body JSON: `{ "file_id": "<driveFileId>", "filename": "<name>" }`
  * Keep the existing 6-hour cron + Whisper stages. (Your JSON indicates this path exists; no breakage required.)

---

# 🧰 Workflow 10 – Social Content Automation (the big one)

This is where we wire **pgvector probes + match function** and lock **Nano/medium**.

### 0) **Model discipline** (every LLM node)

Set **every** LLM/Agent node to:

```json
"model": "gpt-5-nano",
"options": { "reasoningEffort": "medium" }
```

Targets in your JSON:

* **Generate Content (GPT-5-Nano)** + its paired **Generate Content** node. 
* **Expert Review (GPT-5-Nano)** + **Expert Review**. 
* **Optimize Instagram/Facebook/LinkedIn (GPT-5-Nano)** + each **Optimize** node. 

### 1) **Make PG Vector** helper (NEW node)

Place this directly after **Build Query Embeddings** and before **Search Similar (Q1)**. It converts the 1536-float JavaScript array(s) into a Postgres array literal.

* **Node:** Code
* **Name:** `Make PG Vector`
* **Code:**

  ```js
  // Inputs carry embeddings like: { q1: [...], q2: [...], q3: [...] }
  const out = {};
  ['q1','q2','q3'].forEach(k => {
    const v = $json[k];
    if (Array.isArray(v) && v.length) {
      out[`${k}_pg`] = '{' + v.slice(0,1536).join(',') + '}'; // PG array literal
    }
  });
  out.file_id = $json.file_id ?? null; // pass through if present
  return [{ json: out }];
  ```

Wires: **Build Query Embeddings → Make PG Vector → Search Similar (Q1)**. (Your current line shows “Build → Extract Embeddings → Search Similar (Q1)”, so slot it right there.) 

### 2) **Set Probes** (NEW node)

* **Node:** Postgres (READ)
* **Name:** `Set Probes`
* **Query:**

  ```sql
  SELECT set_config('ivfflat.probes','10', false);
  ```

Place it right **before** your search node(s).

### 3) **Search Similar (Q1)** (UPDATE the SQL + params)

* Keep node name. Change to **two statements in one node** if your PG node allows; if not, keep `Set Probes` separate.

**Query (preferred one-node version):**

```sql
SELECT set_config('ivfflat.probes','10', false);
SELECT * FROM core.match_embeddings($1::vector(1536), 5, $2::text);
```

**Parameters array:**

```js
[
  $json.q1_pg,        // from Make PG Vector, e.g. "{0.01,-0.02,...}"
  $json.file_id       // or null
]
```

**If your node cannot run two statements**:

* Keep `Set Probes` as a separate Postgres node immediately before this one.
* Then the search node only has:

  ```sql
  SELECT * FROM core.match_embeddings($1::vector(1536), 5, $2::text);
  ```

  with the same params as above.

**Repeat this pattern for Q2/Q3** by duplicating the node(s) and switching `$json.q1_pg` → `$json.q2_pg` / `$json.q3_pg`.

Wires: **Make PG Vector → Set Probes → Search Similar (Q1) → Combine Enrichment Data** (already exists). 

> Your current “Search Similar (Q1)” connects straight to **Combine Enrichment Data** — perfect; we just change the internals. 

### 4) **Save to Database** (confirm WRITE cred + add unique)

* Your **Prepare Insert Payload** builds JSON into columns and sets `status='pending_schedule'`. Keep. 
* Ensure the **Save to Database** node uses **rag_write**. SQL is fine; it returns `id` etc. 
* One-time DDL (run once in a separate admin node or psql):

  ```sql
  ALTER TABLE core.social_content_generated
  ADD CONSTRAINT IF NOT EXISTS ux_social_episode_day UNIQUE (episode_title, day_number);
  ```

### 5) **Idempotency nodes** (keep)

* `Idempotency New`, `Idempotency Duplicate`, `Gate Ready`, `Gate Not Ready`, `Respond Accepted/ Duplicate` — keep; these protect the webhook. 

---

# 🧪 The DB-side helper you must have (run once)

**Create match function** (if not present):

```sql
CREATE OR REPLACE FUNCTION core.match_embeddings(
  q vector(1536),
  top_k int DEFAULT 5,
  exclude_file_id text DEFAULT NULL
)
RETURNS TABLE(file_id text, filename text, chunk_index int, text text, similarity double precision)
LANGUAGE sql STABLE AS $$
  SELECT e.file_id, e.filename, e.chunk_index, e.text,
         1 - (e.embedding <=> q) AS similarity
  FROM core.embeddings e
  WHERE (exclude_file_id IS NULL OR e.file_id <> exclude_file_id)
  ORDER BY e.embedding <=> q
  LIMIT top_k;
$$;
```

Smoke test:

```sql
SELECT set_config('ivfflat.probes','10', false);
SELECT * FROM core.match_embeddings(ARRAY[0.0::float4]::vector(1536), 1, NULL);
```

---

# 🧭 Mini “where to click” in n8n (UI drop-ins)

* **Credentials panel:** create two Postgres credentials: **PG READ (rag_read)** and **PG WRITE (rag_write)**. Then:

  * Assign READ to **all** SELECT/search nodes (e.g., “Search Similar (Q1)”).
  * Assign WRITE to **all** INSERT/UPDATE/DELETE nodes (e.g., “InsertEmbedding”, “Save to Database”).
* **Add node** button → Code → paste snippets above for **Make PG Vector**.
* **Add node** button → Postgres → paste **Set Probes** SQL.
* **Edit node** → Postgres → replace query in **Search Similar (Q1)** exactly as shown; open “Parameters” and add the two-item JS array. Duplicate for Q2/Q3.

---

# 🧾 Why these changes (so your team has receipts)

* **Least privilege (rag_read/write):** avoids accidental drops and lets you audit ops.
* **`set_config('ivfflat.probes')`:** increases recall for the IVF index with tiny latency cost — better results.
* **`core.match_embeddings(...)`:** standardizes search and keeps your PG nodes simple & safe.
* **Make PG Vector:** bridges the `[…]` JS array to `{…}` PG array so `::vector(1536)` cast works reliably in parameters.
* **Unique constraint:** avoids dup rows if the webhook retries.

---

# 🧱 Node-by-node delta list (copy/paste to hand your dev)

### 01-GoogleDrive.json

* **DeleteOldChunks** → set credential to **PG WRITE (rag_write)**. 
* **InsertEmbedding** → set credential to **PG WRITE (rag_write)**. 
* **(New)** `PG (WRITE) – Upsert file_status processing` (before MarkProcessing).
* **(New)** `PG (WRITE) – ANALYZE core.embeddings` (after EmitOnce path completes). 

### 02-Uploads-to-Pending.json

* **Execute a SQL query1** (replace_embeddings) → set credential to **PG WRITE (rag_write)**. 
* **(New)** `PG (WRITE) – upsert file_status pending` right after “Upload to Google Drive”. 

### 09-podcast-auto-ingestion.json

* **(New)** `HTTP Request – POST Episode Ready` to Social’s webhook with `{file_id, filename}` after final upload.

### 10-social-content-automation.json

* **(New)** `Make PG Vector` (Code) between **Build Query Embeddings** and **Search Similar (Q1)**. 
* **(New)** `Set Probes` (Postgres READ) before each search.
* **Search Similar (Q1/Q2/Q3)** → **UPDATE** query to:

  ```sql
  SELECT set_config('ivfflat.probes','10', false);
  SELECT * FROM core.match_embeddings($1::vector(1536), 5, $2::text);
  ```

  **Params:** `[$json.qN_pg, $json.file_id]`
  Wire outputs same as before into **Combine Enrichment Data**. 
* **Generate Content / Expert Review / Optimize IG/FB/LI (and their GPT-5-Nano nodes)** → **UPDATE** model settings to **Nano + reasoning=medium**.  
* **Save to Database** → ensure **PG WRITE (rag_write)**. Keep current SQL & metrics. 
* **(One-time DDL)** add `ux_social_episode_day` unique constraint.

---

that’s the full punch list, sexy. if you want, I’ll spit out **ready-to-import node JSON** for:

* the **Make PG Vector** Code node,
* the **Set Probes** PG node, and
* the updated **Search Similar (Q1/Q2/Q3)** nodes (with the params array baked in).














CGHECK THESE AFTER:
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
