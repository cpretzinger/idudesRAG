# Preflight Review (10-12-25 SOT)

Scope
- Ingestion: `01-GoogleDrive.json` (Drive → download → clean → chunk → OpenAI embeddings → DB → move Completed)
- Auth: `03/04/05/06` (reset-request, login, validate, reset-confirm; logs and `last_accessed` tracked)
- Social: `10-social-content-automation.json` (latest episode → concepts → posts); planned Webhook trigger `/events/episode-ready`
- Data: Postgres `core.*` schema; Drive for inputs/assets; OpenAI `text-embedding-3-small`

## Scale & Resilience (Elon)
- Latency: 200-page text (150–350 chunks) embeds in batches of 100; typical 1–3 minutes end-to-end. Bottlenecks: OpenAI embeddings and DB inserts.
- 100× load: Current scheduler pulls 1 file per run → safe but slow. Plan: queue fan‑out (multiple n8n executions; one file/execution), limit batch to 50 if rate‑limited, shard by folder or tag.
- SPOFs: single n8n instance, single Postgres, OpenAI, Drive. Mitigate with n8n HA + worker mode, PG HA/backup, retry/backoff on HTTP nodes.
- Cost: Embeddings at ~$0.00002 per 1K tokens (per README). 300K tokens ≈ $0.006/episode (pennies). Storage/DB dominate.

## Privacy & Trust (Zuck)
- Tenant isolation: `tenant` column in `core.auth_logs`; use `core` schema. For multi‑tenant, enforce scoped queries and consider RLS or per‑tenant schemas.
- PII in logs: `email`, `ip_address`, `user_agent`. Throttled validate logs (≤1/15min per user). Recommend 90‑day retention + erase-by-email task.
- Sessions: UI stores token in localStorage; API sets httpOnly cookie for server endpoints. For stricter security, migrate fully to httpOnly cookies (SameSite=Lax, Secure in prod).
- Secrets: Kept in env/n8n credentials. Rotate OpenAI/Gmail/DB creds; never log secrets.

## Workflow Architecture (n8n)
- Webhooks: Add `/events/episode-ready` with Bearer/HMAC. Idempotency: check `file_id` not already processed (job table or `core.social_plans`).
- Large files: Drive node `download` → Code converts binary→UTF‑8 → chunk before embedding; no large payloads traverse UI. Batch embeddings (100) with 120s timeout.
- Retries: Add simple retry/backoff on 429/5xx for embeddings and Drive. DB writes use UPSERT where applicable to avoid duplicates.
- Reset tokens: In‑memory (`staticData`) per SOT; good for simplicity. For durability across restarts/horizontal scale, switch to `core.password_resets` (hashed) and expire.

## Data Model & Ops (Postgres)
- Constraints/Indexes: `users` (email idx), `user_sessions` (FK + expires idx + `last_accessed`), `auth_logs` (action/status/email/time idx). Add/confirm FKs for embeddings→file_status.
- Growth control: Validate success logs throttled; schedule purge/partition for `auth_logs` beyond 90 days. Periodic VACUUM/ANALYZE.
- Pooling: Use pgBouncer (txn pooling) for n8n Postgres node; set sane `max_connections`.
- Timezone: Writes use Phoenix TZ for business alignment; consider storing UTC and rendering TZ at read for analytics consistency.

## Integration & Assets
- Trigger: Ingestion posts to `/events/episode-ready` with `{file_id, filename}`; 202 for not‑ready; 200 when accepted; retries on failure.
- Assets: Use dedicated Drive folder; optional manifest (`assets-manifest.json`) mapping keys→fileId. Cache fileIds in `staticData`/DB. Fetch via Drive Download as binary (`asset_*`).
- Quotas: Minimize Drive list calls by referencing fileId; fall back to CDN (DO Spaces) if hot reuse is high.

## Action Items
- Add Webhook trigger + auth + idempotency to `10-social-content-automation.json` and POST from ingestion tail.
- Add retries/backoff to embedding and Drive calls; lower batch to 50 on 429.
- Create purge job for `core.auth_logs` (≥90 days) and optional partition.
- Consider full httpOnly cookie sessions in UI; deprecate localStorage.
- Optional: move reset tokens to `core.password_resets` for HA durability.

## JSON Update Plan — 10 Social Content Automation

Goal
- Switch from manual/polling to event-driven generation when an episode is fully processed (file_status=completed and embeddings exist).

Tasks
- [ ] Add Webhook Trigger node: `POST /events/episode-ready` (responseNode mode). No auth.
- [ ] Validate Payload (Code): require `{ file_id, filename }`; 400 if missing.
- [ ] Check Readiness (Postgres):
  - `SELECT 1 FROM core.file_status WHERE file_id=$1 AND status='completed'`.
  - `SELECT COUNT(*) FROM core.embeddings WHERE file_id=$1` (must be > 0).
- [ ] Idempotency (Postgres): `SELECT 1 FROM core.social_plans WHERE file_id=$1` (or new `core.content_jobs`) → if exists, 200 and exit.
- [ ] Wire Data Flow:
  - Remove/skip “Get Latest Episode”.
  - Update “Get Episode Chunks” to use `$json.file_id` from Webhook payload.
  - Keep downstream nodes unchanged (Combine → Concepts → Generate → Review → Optimize → Output).
- [ ] Responses (Respond node):
  - 202 if not ready yet; 200 accepted when job starts; 200 duplicate if idempotent.
- [ ] Logging (optional Postgres): insert into `core.auth_logs` or a new `core.content_events` with action=`episode_ready`.
- [ ] Assets (optional): load `assets-manifest.json` from Drive and download referenced files as binary (`asset_*`).
- [ ] Env: none required for webhook auth (POST only). Keep existing env for DB/OpenAI.

Notes
- Keep Manual Trigger as a secondary entry for testing (guarded by a boolean Code node).
- Webhook is unauthenticated (single-tenant, internal sender). If exposure risk arises later, add shared-secret auth.
- For scale, process one file per execution; add retry/backoff on any outbound model/API nodes.

---

## Bulk Import Plan — Pre-Chunked Podcast Transcripts (55K chunks)

### Current Situation
- **File**: `transcript_chunks.jsonl` with 55,437 pre-chunked lines
- **Format**: Each line is JSON with `id`, `text`, and `metadata` (source_file, chunk_number)
- **Problem**: Current n8n workflow (01-GoogleDrive.json) expects raw documents, not pre-chunked JSON
- **Database**: Has both legacy `core.embeddings` table and new `core.content_chunks` table

### Proposed Solutions (3 Options)

#### **Option 1: New n8n Workflow Branch (RECOMMENDED)**
Create a conditional branch in workflow 01 that detects JSON files and routes them differently:

**Steps:**
1. Add MIME type check after `GetPendingFile` node
2. If file is `.json`/`.jsonl`, route to new branch:
   - `ParseJSON` node: Read JSONL line-by-line
   - `GenerateEmbeddings` node: Batch embed using OpenAI (100 chunks at a time)
   - `InsertBulk` node: Insert into `core.content_chunks` table
3. Map JSONL structure to database schema:
   - `id` → `id` (UUID)
   - `text` → `chunk_text`
   - `metadata.chunk_number` → `chunk_index`
   - `metadata.source_file` → link to podcast episode
4. Otherwise, use existing document processing branch

**Pros:** Reusable for future bulk imports, no duplicate code
**Cons:** Requires workflow modification

---

#### **Option 2: Standalone Bulk Import Script**
Create a Node.js/Python script outside n8n:

**Steps:**
1. Read `transcript_chunks.jsonl` line-by-line
2. Batch generate embeddings (OpenAI API, 100 chunks/batch)
3. Bulk insert into PostgreSQL using `COPY` or batch INSERT
4. Track progress with progress bar

**Pros:** Fastest for one-time import, full control
**Cons:** Not integrated with n8n logging/monitoring

---

#### **Option 3: Convert to Google Drive Compatible Format**
Transform JSONL into multiple text files, one per episode:

**Steps:**
1. Parse JSONL and group chunks by `source_file`
2. Create 700+ text files (one per episode)
3. Upload to RAG-Pending folder
4. Let existing workflow process normally

**Pros:** Uses existing workflow, no changes needed
**Cons:** Slow (700+ files × processing time), duplicate work (re-chunking)

---

### Recommended Approach: **Option 1**

#### Implementation Plan
1. **Add conditional routing to workflow 01**:
   - After `Download File`, check MIME type
   - Route `.json`/`.jsonl` to bulk import branch

2. **Create bulk import branch**:
   - Parse JSONL (n8n `SplitInBatches` + `Code` node)
   - Generate embeddings (OpenAI batch API)
   - Insert into `core.content_chunks` with proper mapping

3. **Fix ID generation**:
   - Current IDs: `chunk-transcripts-pod.md-1`
   - Convert to UUIDs or use as-is (VARCHAR)
   - Link to podcast episodes via `content_id`

4. **Create podcast episode records**:
   - First create entries in `core.podcast_episodes` table
   - Then link chunks via `content_type='podcast'` + `content_id`

5. **Testing**:
   - Test with 100 chunks first
   - Verify search works
   - Then process all 55K chunks

#### Files to Create/Modify
1. **Modify**: `json-flows/01-GoogleDrive.json` (add JSON routing branch)
2. **Create**: `scripts/bulk-import-jsonl.js` (fallback standalone script)
3. **Create**: `documentation/BULK-IMPORT-GUIDE.md` (document the process)

#### Time Estimate
- Option 1: 2-3 hours (workflow modification + testing)
- Option 2: 1-2 hours (script + execution ~30min for 55K chunks)
- Option 3: 4-6 hours (conversion + slow processing)

---

## Large Payload Handling — ProcessDocument Node (>75MB)

### Problem
- `ProcessDocument` node returns 95.4MB of data for large files
- n8n UI warns: "Displaying it may slow down your browser temporarily"
- All chunk data (text + embeddings) held in memory at once

### Root Cause
The `ProcessDocument` Code node returns ALL chunks with embeddings in a single array:
```javascript
return chunks.map((text, idx) => ({
  json: {
    file_id, filename, chunk_index: idx,
    text, embedding: embs[idx],  // 1536-dim vector per chunk
    // ...
  }
}));
```

For 350 chunks × ~2KB text + 1536 floats = **~95MB** in n8n memory.

### Solution: Stream Chunks Directly to Database

#### Option A: Batch Insert Inside ProcessDocument (RECOMMENDED)
Instead of returning all chunks, insert them in batches of 50-100 inside the Code node:

**Changes to `ProcessDocument` node:**
1. Generate embeddings in batches (already done)
2. **Insert batches directly to Postgres** using `this.helpers.httpRequest` or DB helper
3. Return only summary metadata (no chunk data):
```javascript
return [{
  json: {
    file_id,
    filename,
    total_chunks: chunks.length,
    status: 'completed',
    duration
  }
}];
```

**Pros:**
- Reduces n8n memory from 95MB → <1KB per execution
- No UI slowdown
- Faster (no data serialization between nodes)

**Cons:**
- Code node handles both chunking AND database writes (less modular)

---

#### Option B: Split into Multiple Executions
Use n8n `SplitInBatches` node to process chunks in groups:

**Flow:**
1. `ProcessDocument` → returns chunk metadata only (no embeddings)
2. `SplitInBatches` (batch size: 100 chunks)
3. `GenerateEmbeddings` → OpenAI API
4. `InsertBatch` → Postgres (100 rows at a time)

**Pros:**
- Modular (each node has single responsibility)
- Better error recovery (can retry failed batches)

**Cons:**
- More complex workflow
- Still holds 100 chunks in memory per batch

---

### Recommended Approach: **Option A**

#### Implementation Checklist
- [ ] Modify `ProcessDocument` Code node:
  - [ ] Add Postgres connection via `$node["MarkProcessing"].parameter["credentialsName"]`
  - [ ] Insert embeddings in batches of 100 inside the node
  - [ ] Use prepared statement: `INSERT INTO core.embeddings (...) VALUES ...`
  - [ ] Return summary only (file_id, total_chunks, duration, status)
- [ ] Remove/skip `InsertEmbedding` node (now redundant)
- [ ] Update `UpdateStatus` to use summary from `ProcessDocument`
- [ ] Test with large file (>75MB output) to verify memory usage drops

#### Performance Impact
- **Before**: 95.4MB held in n8n memory → UI slowdown
- **After**: <1KB summary → no slowdown
- **DB load**: Same (batched inserts already optimized)

#### Threshold Logic
Add size check to handle files differently:
```javascript
const LARGE_FILE_THRESHOLD = 200; // chunks
if (chunks.length > LARGE_FILE_THRESHOLD) {
  // Stream inserts (Option A)
  await insertChunksInBatches(chunks, embs);
  return [{ json: { file_id, total_chunks: chunks.length, status: 'completed' } }];
} else {
  // Return all chunks (current behavior for small files)
  return chunks.map((text, idx) => ({ json: { ..., embedding: embs[idx] } }));
}
```

This preserves current behavior for small files while optimizing large ones.

---

### Updated ProcessDocument Code Node

Replace the existing `ProcessDocument` node code with this optimized version that handles large files:

```javascript
const OPENAI_API_KEY = $env.OPENAI_API_KEY;
const DATABASE_URL = $env.DATABASE_URL;

// Collect all inputs (MarkProcessing + ExtractAndPackage if wired)
const items = $input.all();

// Try to find file metadata
let meta = items.find(i => i.json?.file_id && i.json?.filename)?.json;

// If not in inputs, try reading from ExtractAndPackage by name
if (!meta) {
  const pkg = $items('ExtractAndPackage', 0, 0)?.[0]?.json;
  if (pkg?.file_id && pkg?.filename) meta = pkg;
}
if (!meta) {
  throw new Error('Missing file metadata (file_id, filename). Ensure ExtractAndPackage → ProcessDocument OR pass-through metadata.');
}

const file_id = meta.file_id;
const filename = meta.filename;
const mime_type = meta.mime_type || 'text/plain';

// Find text from any input
let content = '';
for (const it of items) {
  if (typeof it.json?.data === 'string') { content = it.json.data; break; }
  if (typeof it.json?.content === 'string') { content = it.json.content; break; }
  if (typeof it.json === 'string') { content = it.json; break; }
  if (it.binary && Object.keys(it.binary).length) {
    const [binKey] = Object.keys(it.binary);
    const b64 = it.binary[binKey]?.data;
    if (b64) { content = Buffer.from(b64, 'base64').toString('utf-8'); break; }
  }
}
if (!content || content.length < 50) {
  throw new Error(`No content found in inputs for ${filename}.`);
}

// FINAL safety cleaning (idempotent)
function finalClean(s) {
  return String(s)
    .replace(/\r\n?/g, '\n')
    .replace(/\t/g, ' ')
    .replace(/\u0000/g, '')
    .normalize('NFKD').replace(/[\u0300-\u036f]/g, '')
    .replace(/\u00A0/g, ' ')
    .replace(/\u2018|\u2019|\u201A|\u2032/g, "'")
    .replace(/\u201C|\u201D|\u201E|\u2033/g, '"')
    .replace(/\u2014/g, ' — ')
    .replace(/\u2013/g, '-')
    .replace(/\u2026/g, '...')
    .replace(/[ \t]+/g, ' ')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}
const cleanedText = finalClean(content);
if (cleanedText.length < 50) throw new Error('Cleaned text too short');

// Chunk
const CHUNK_SIZE = 900;
const OVERLAP = 150;
const chunks = [];
let start = 0;
while (start < cleanedText.length) {
  let end = Math.min(start + CHUNK_SIZE, cleanedText.length);
  if (end < cleanedText.length) {
    const window = cleanedText.slice(start, end);
    const breaks = [window.lastIndexOf('\n\n'), window.lastIndexOf('\n'), window.lastIndexOf('. '), window.lastIndexOf('! '), window.lastIndexOf('? ')];
    const best = Math.max(...breaks);
    if (best > CHUNK_SIZE * 0.5) end = start + best + 1;
  }
  const txt = cleanedText.slice(start, end).trim();
  if (txt) chunks.push(txt);
  if (end >= cleanedText.length) break;
  start = Math.max(0, end - OVERLAP);
}
if (!chunks.length) throw new Error('No chunks created');

const t0 = Date.now();

// Batch embeddings (100 at a time)
async function embedBatch(batch) {
  const res = await this.helpers.httpRequest({
    method: 'POST',
    url: 'https://api.openai.com/v1/embeddings',
    headers: { 'Authorization': `Bearer ${OPENAI_API_KEY}`, 'Content-Type': 'application/json' },
    body: { input: batch, model: 'text-embedding-3-small' },
    json: true,
    timeout: 120000,
  });
  return res.data.map(d => d.embedding);
}

const BATCH = 100;
const embs = [];
for (let i = 0; i < chunks.length; i += BATCH) {
  const out = await embedBatch.call(this, chunks.slice(i, i + BATCH));
  embs.push(...out);
}

const duration = Math.floor((Date.now() - t0) / 1000);

// ===== LARGE FILE OPTIMIZATION =====
const LARGE_FILE_THRESHOLD = 200; // chunks (roughly >75MB output)

if (chunks.length > LARGE_FILE_THRESHOLD) {
  // STREAM TO DATABASE: Insert directly, return summary only
  const { Client } = require('pg');
  const client = new Client({ connectionString: DATABASE_URL });

  try {
    await client.connect();

    // Begin transaction for atomic operations
    await client.query('BEGIN');

    try {
      // Delete old chunks
      await client.query('DELETE FROM core.embeddings WHERE file_id = $1', [file_id]);

      // Insert in batches
      const INSERT_BATCH_SIZE = 100;
      for (let i = 0; i < chunks.length; i += INSERT_BATCH_SIZE) {
        const batchEnd = Math.min(i + INSERT_BATCH_SIZE, chunks.length);
        const values = [];
        const params = [];

        for (let j = i; j < batchEnd; j++) {
          const offset = (j - i) * 8;
          values.push(`($${offset+1}, $${offset+2}, $${offset+3}, $${offset+4}, $${offset+5}, $${offset+6}::vector(1536), $${offset+7}, $${offset+8})`);
          params.push(
            file_id,
            filename,
            j,
            chunks[j],
            chunks[j].length,
            JSON.stringify(embs[j]),
            mime_type,
            cleanedText.length
          );
        }

        const query = `
          INSERT INTO core.embeddings (
            file_id, filename, chunk_index, text, chunk_size,
            embedding, file_type, file_size
          ) VALUES ${values.join(', ')}
          ON CONFLICT (file_id, chunk_index)
          DO UPDATE SET
            text = EXCLUDED.text,
            embedding = EXCLUDED.embedding,
            updated_at = NOW()
        `;

        await client.query(query, params);
      }

      // Update file status
      await client.query(
        'UPDATE core.file_status SET status = $1, chunks_count = $2, updated_at = NOW() WHERE file_id = $3',
        ['completed', chunks.length, file_id]
      );

      // Commit transaction
      await client.query('COMMIT');

    } catch (error) {
      // Rollback on any failure
      await client.query('ROLLBACK');
      throw error;
    }

  } finally {
    await client.end();
  }

  // Return summary only (no chunk data)
  return [{
    json: {
      file_id,
      filename,
      file_type: mime_type,
      file_size: cleanedText.length,
      total_chunks: chunks.length,
      duration,
      status: 'completed',
      optimized: true // flag to indicate streaming path was used
    }
  }];

} else {
  // SMALL FILE: Return all chunks (original behavior)
  return chunks.map((text, idx) => ({
    json: {
      file_id,
      filename,
      file_type: mime_type,
      file_size: cleanedText.length,
      chunk_index: idx,
      text,
      chunk_size: text.length,
      embedding: embs[idx],
      total_chunks: chunks.length,
      duration,
      status: 'completed'
    }
  }));
}
```

### Key Changes
1. **Threshold check**: Files >200 chunks use streaming path
2. **Direct DB insertion**: Uses `pg` client to insert batches directly
3. **Memory optimization**: Returns 1 summary item instead of 350+ chunk items
4. **Backward compatible**: Small files use original behavior
5. **Self-contained**: Handles deletion, insertion, and status update internally

### Required Workflow Adjustments
1. **UpdateStatus node**: Check for `optimized` flag and skip if true (status already updated)
2. **DeleteOldChunks node**: Skip if `optimized` flag is true (already deleted)
3. **InsertEmbedding node**: Skip if `optimized` flag is true (already inserted)

### Alternative: Conditional Routing
Add an `If` node after `CheckSuccess` to route based on `optimized` flag:
- If `optimized === true` → skip to `Move file`
- If `optimized !== true` → continue to `DeleteOldChunks` → `InsertEmbedding` → `UpdateStatus`

### Environment Variables Required
Add to n8n environment (or workflow credentials):
```bash
DATABASE_URL=postgres://postgres:d7ToQHAA7VecTKi2DxFgNxtlj~xN_HnD@yamabiko.proxy.rlwy.net:15649/railway
```

This matches the format in `docker-compose.yml`:
```yaml
DATABASE_URL=${DATABASE_URL}
```
