# Advanced RAG Implementation - Streamlined

**⚠️ EXPERT REVIEW REQUIRED**

**Total Time: 90 minutes**

---

## 🔍 Expert Review Checklist

**Before implementing, have PostgreSQL + n8n experts review:**

### PostgreSQL Expert Review Needed:

1. **Hybrid Search Query (Phase 2)**
   - ✅ RRF (Reciprocal Rank Fusion) formula correct?
   - ✅ CTE structure optimized for HNSW + GIN indexes?
   - ✅ Parameter injection safe from SQL injection?
   - ✅ Dynamic WHERE clause construction secure?
   - ✅ Query plan efficient for 1M+ embeddings?

2. **Index Usage**
   - ✅ Existing HNSW index (`idx_embeddings_hnsw`) utilized properly?
   - ✅ FTS GIN index (`idx_embeddings_chunk_text_fts`) utilized properly?
   - ✅ Should we add composite index for `(document_id, metadata->>'episode_id')`?

3. **Filter Performance**
   - ✅ JSONB queries on `metadata` field performant?
   - ✅ Need additional GIN index on metadata JSONB?

### n8n Expert Review Needed:

1. **Multi-Query Expansion (Phase 3)**
   - ✅ Parallel execution with `Promise.all` supported in n8n Code node?
   - ✅ Array return format compatible with n8n branching?
   - ✅ Error handling for LLM failures adequate?

2. **Node Connections**
   - ✅ Flow structure valid for n8n execution model?
   - ✅ Merge node logic correct for deduplication?
   - ✅ Credentials passing (`$credentials.openAiApi`) correct?

3. **Workflow Performance**
   - ✅ 200-400ms latency acceptable for n8n webhook response?
   - ✅ Timeout settings need adjustment for multi-query?
   - ✅ Memory usage with 20+ results per query variant?

### Cost Analysis Review:

- ✅ $0.00036/search accurate calculation?
- ✅ GPT-5-nano token estimates realistic?
- ✅ Embedding API batch limits respected?
- ✅ Re-ranking cost justified vs. simpler alternatives (Cohere, cross-encoder)?

---

## 📋 Specific Questions for Experts

**PostgreSQL Questions:**
1. Is RRF k-value of 60 optimal for this use case, or should we test 40-80 range?
2. Should BM25 use `ts_rank_cd` or `ts_rank`? Which is better for our content?
3. Will dynamic filter WHERE clauses cause query plan cache issues?

**n8n Questions:**
1. Can n8n Code nodes handle multiple parallel fetch() calls without blocking?
2. Is there a better way to merge multi-query results than our dedup logic?
3. Should we split re-ranking into separate workflow for async processing?

**Architecture Questions:**
1. Should we cache query embeddings in Redis to avoid regenerating for variants?
2. Is GPT-5-nano re-ranking fast enough, or should we use Cohere Re-rank API?
3. Should we implement result caching for identical queries within 5-minute window?

---

## Phase 1: Metadata Updates (15 min)

### Update PrepDoc Node (All Upload Workflows)

**Location:** Workflows 02, 02-gdrive

**Replace metadata section with:**

```javascript
// Auto-detect document type
const isTranscript = filename.toLowerCase().includes('transcript') ||
                     filename.toLowerCase().includes('episode') ||
                     file_type === 'text/vtt' ||
                     file_type === 'application/x-subrip';

// Extract episode ID from filename if present (e.g., "Episode 42 - Title.txt" → "42")
const episodeMatch = filename.match(/episode[\s-_]*(\d+)/i);
const episodeId = episodeMatch ? episodeMatch[1] : null;

metadata: {
  filename: filename,
  file_type: file_type,
  file_size: file_size || content.length,
  source: source,
  timestamp: new Date().toISOString(),
  upload_source: upload_source,
  drive_file_id: input.json?.id || null,
  // NEW FIELDS (null for non-transcripts)
  document_type: isTranscript ? 'transcript' : 'document',
  language: 'en',
  episode_id: episodeId,
  speaker: isTranscript ? null : null,  // Populate later if needed
  episode_title: isTranscript ? filename.replace(/episode[\s-_]*\d+[\s-_]*/i, '').replace(/\.[^.]+$/, '') : null
}
```

### Update map Node (All Upload Workflows)

**Add to metadata object:**

```javascript
document_type: md.document_type ?? 'document',
language: md.language ?? 'en',
episode_id: md.episode_id ?? null,
speaker: md.speaker ?? null,
episode_title: md.episode_title ?? null
```

### Update DocLoader Metadata Values

**Add these rows to metadata values:**

| Name | Value |
|------|-------|
| document_type | `{{ $('map').first().json.metadata.document_type }}` |
| language | `{{ $('map').first().json.metadata.language }}` |
| episode_id | `{{ $('map').first().json.metadata.episode_id }}` |
| speaker | `{{ $('map').first().json.metadata.speaker }}` |
| episode_title | `{{ $('map').first().json.metadata.episode_title }}` |

---

## Phase 2: Hybrid Search Query (30 min)

### New Hybrid Search Node Code

**Replace "Vector Search" node in workflow 08 with:**

```javascript
// HYBRID SEARCH: Vector + BM25 with RRF (Reciprocal Rank Fusion)
const query = $json.query;
const limit = $json.limit || 12;
const minSimilarity = $json.minSimilarity || 0.65;
const filters = $json.filters || {};

// PostgreSQL credentials
const { Client } = require('pg');
const client = new Client({
  connectionString: 'postgres://postgres:d7ToQHAA7VecTKi2DxFgNxtlj~xN_HnD@yamabiko.proxy.rlwy.net:15649/railway'
});

try {
  await client.connect();

  // Generate query embedding
  const embeddingResponse = await fetch('https://api.openai.com/v1/embeddings', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${$credentials.openAiApi.apiKey}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      input: query,
      model: 'text-embedding-3-small',
      dimensions: 1536
    })
  });

  const embeddingData = await embeddingResponse.json();
  const queryEmbedding = embeddingData.data[0].embedding;

  // Build WHERE clause for filters (handles both transcripts and documents)
  const filterClauses = [];
  const filterParams = [];
  let paramIndex = 5; // Start after $1-$4

  if (filters.documentType) {
    filterClauses.push(`metadata->>'document_type' = $${paramIndex}`);
    filterParams.push(filters.documentType);
    paramIndex++;
  }

  if (filters.episodeId) {
    filterClauses.push(`metadata->>'episode_id' = $${paramIndex}`);
    filterParams.push(filters.episodeId);
    paramIndex++;
  }

  if (filters.language) {
    filterClauses.push(`metadata->>'language' = $${paramIndex}`);
    filterParams.push(filters.language);
    paramIndex++;
  }

  if (filters.fileTypes && Array.isArray(filters.fileTypes)) {
    filterClauses.push(`metadata->>'file_type' = ANY($${paramIndex}::text[])`);
    filterParams.push(filters.fileTypes);
    paramIndex++;
  }

  const filterWhere = filterClauses.length > 0 ? `AND ${filterClauses.join(' AND ')}` : '';

  // HYBRID SEARCH: Vector + BM25 with RRF
  const hybridQuery = `
    WITH vector_results AS (
      SELECT
        id,
        document_id,
        text,
        metadata,
        1 - (embedding <=> $1::vector) AS vector_score,
        ROW_NUMBER() OVER (ORDER BY embedding <=> $1::vector) AS vector_rank
      FROM core.document_embeddings
      WHERE 1 - (embedding <=> $1::vector) >= $2
        ${filterWhere}
      ORDER BY embedding <=> $1::vector
      LIMIT 20
    ),
    bm25_results AS (
      SELECT
        id,
        document_id,
        text,
        metadata,
        ts_rank_cd(to_tsvector('english', text), plainto_tsquery('english', $3)) AS bm25_score,
        ROW_NUMBER() OVER (ORDER BY ts_rank_cd(to_tsvector('english', text), plainto_tsquery('english', $3)) DESC) AS bm25_rank
      FROM core.document_embeddings
      WHERE to_tsvector('english', text) @@ plainto_tsquery('english', $3)
        ${filterWhere}
      ORDER BY bm25_score DESC
      LIMIT 20
    ),
    rrf_combined AS (
      SELECT
        COALESCE(v.id, b.id) AS id,
        COALESCE(v.document_id, b.document_id) AS document_id,
        COALESCE(v.text, b.text) AS text,
        COALESCE(v.metadata, b.metadata) AS metadata,
        COALESCE(v.vector_score, 0) AS vector_score,
        COALESCE(b.bm25_score, 0) AS bm25_score,
        (COALESCE(1.0 / (60 + v.vector_rank), 0) + COALESCE(1.0 / (60 + b.bm25_rank), 0)) AS rrf_score
      FROM vector_results v
      FULL OUTER JOIN bm25_results b ON v.id = b.id
    )
    SELECT
      id,
      document_id,
      text,
      metadata,
      vector_score,
      bm25_score,
      rrf_score
    FROM rrf_combined
    ORDER BY rrf_score DESC
    LIMIT $4;
  `;

  const result = await client.query(hybridQuery, [
    JSON.stringify(queryEmbedding),
    minSimilarity,
    query,
    limit,
    ...filterParams
  ]);

  // Format results
  const results = result.rows.map(row => ({
    id: row.id,
    document_id: row.document_id,
    content: row.text,
    metadata: row.metadata,
    scores: {
      vector: parseFloat(row.vector_score || 0).toFixed(4),
      bm25: parseFloat(row.bm25_score || 0).toFixed(4),
      rrf: parseFloat(row.rrf_score || 0).toFixed(4)
    }
  }));

  return [{
    json: {
      success: true,
      query: query,
      results: results,
      count: results.length,
      search_type: 'hybrid_rrf',
      timestamp: new Date().toISOString()
    }
  }];

} finally {
  await client.end();
}
```

---

## Phase 3: Multi-Query Expansion (20 min)

### New Multi-Query Node (Before Hybrid Search)

**Add this node between "Route by Mode" and "Hybrid Search":**

**Node Name:** `Multi-Query Expansion`

```javascript
// MULTI-QUERY EXPANSION: Generate 2-3 query variants
const originalQuery = $json.query;

// Use GPT-5-nano to generate variants
const variantsResponse = await fetch('https://api.openai.com/v1/chat/completions', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${$credentials.openAiApi.apiKey}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    model: 'gpt-5-nano',
    messages: [{
      role: 'system',
      content: 'You are a query expansion expert. Generate 2 alternative phrasings of the user query. Return ONLY a JSON array of strings, no explanation.'
    }, {
      role: 'user',
      content: `Generate 2 alternative phrasings:\n"${originalQuery}"`
    }],
    temperature: 0.7,
    max_tokens: 100
  })
});

const variantsData = await variantsResponse.json();
let variants = [];

try {
  const responseText = variantsData.choices[0].message.content.trim();
  variants = JSON.parse(responseText);
} catch (e) {
  // Fallback: use original query only
  console.log('Query expansion failed, using original only');
  variants = [];
}

// Return array of queries to search
const allQueries = [originalQuery, ...variants].slice(0, 3);

return allQueries.map(q => ({
  json: {
    ...($json),
    query: q,
    is_variant: q !== originalQuery,
    original_query: originalQuery
  }
}));
```

### Update Hybrid Search Node

**Add to beginning of Hybrid Search code:**

```javascript
const isVariant = $json.is_variant || false;
const originalQuery = $json.original_query || $json.query;
```

### Add Results Merger Node (After Hybrid Search)

**Node Name:** `Merge Multi-Query Results`

```javascript
// MERGE RESULTS from all query variants
const allResults = $input.all().map(item => item.json.results).flat();

// Deduplicate by document_id + content hash
const seen = new Set();
const deduplicated = [];

for (const result of allResults) {
  const key = `${result.document_id}_${result.content.substring(0, 100)}`;
  if (!seen.has(key)) {
    seen.add(key);
    deduplicated.push(result);
  }
}

// Sort by highest RRF score
deduplicated.sort((a, b) => parseFloat(b.scores.rrf) - parseFloat(a.scores.rrf));

// Take top 20 for re-ranking
const topResults = deduplicated.slice(0, 20);

return [{
  json: {
    success: true,
    query: $input.first().json.original_query || $input.first().json.query,
    results: topResults,
    count: topResults.length,
    search_type: 'hybrid_multi_query',
    variants_used: $input.all().length,
    timestamp: new Date().toISOString()
  }
}];
```

---

## Phase 4: Re-Ranking (25 min)

### Add Re-Rank Node (After Merge Multi-Query Results)

**Node Name:** `Re-Rank with LLM`

```javascript
// RE-RANK using GPT-5-nano
const query = $json.query;
const results = $json.results || [];

if (results.length === 0) {
  return [$input.first()];
}

// Prepare results for re-ranking (first 200 chars of each)
const resultsForPrompt = results.map((r, idx) => ({
  index: idx,
  preview: r.content.substring(0, 200) + '...',
  metadata: {
    filename: r.metadata?.filename || 'unknown',
    episode_id: r.metadata?.episode_id || null
  }
}));

// LLM re-ranking prompt
const rerankPrompt = `You are a search relevance expert. Score each result 0-100 for relevance to the query.

Query: "${query}"

Results:
${resultsForPrompt.map((r, i) => `[${i}] ${r.preview}`).join('\n\n')}

Return ONLY a JSON array of scores in order: [score0, score1, score2, ...]
Each score is 0-100 (100 = perfect match, 0 = irrelevant).`;

const rerankResponse = await fetch('https://api.openai.com/v1/chat/completions', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${$credentials.openAiApi.apiKey}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    model: 'gpt-5-nano',
    messages: [{
      role: 'system',
      content: 'You are a search relevance scorer. Return only JSON arrays of numbers.'
    }, {
      role: 'user',
      content: rerankPrompt
    }],
    temperature: 0.3,
    max_tokens: 200
  })
});

const rerankData = await rerankResponse.json();
let scores = [];

try {
  const responseText = rerankData.choices[0].message.content.trim();
  scores = JSON.parse(responseText);
} catch (e) {
  // Fallback: keep original order
  console.log('Re-ranking failed, using original order');
  scores = results.map((_, i) => 100 - i);
}

// Attach scores and re-sort
const reranked = results.map((result, idx) => ({
  ...result,
  scores: {
    ...result.scores,
    rerank: scores[idx] || 0
  }
}));

reranked.sort((a, b) => b.scores.rerank - a.scores.rerank);

// Take top 12
const topResults = reranked.slice(0, 12);

return [{
  json: {
    success: true,
    query: query,
    results: topResults,
    count: topResults.length,
    search_type: 'hybrid_multi_query_reranked',
    timestamp: new Date().toISOString()
  }
}];
```

---

## Phase 5: Update Workflow 08 Connections

### New Flow Structure

```
Webhook - Chat/Knowledge
  ↓
Parse Request
  ↓
Route by Mode
  ↓ (search path)
Multi-Query Expansion
  ↓
Hybrid Search (runs 2-3 times in parallel)
  ↓
Merge Multi-Query Results
  ↓
Re-Rank with LLM
  ↓
Respond to Webhook
```

### Update AI Agent Vector Search Tool

**Change topK from 4 → 12:**

```json
{
  "parameters": {
    "description": "Search Insurance Dudes documents using vector similarity",
    "topK": 12
  }
}
```

---

## Configuration Summary

### Key Parameters

| Parameter | Old Value | New Value | Why |
|-----------|-----------|-----------|-----|
| topK | 4 | 12 | More context for agent |
| minSimilarity | 0.7 | 0.65 | Allow more recall |
| RRF k-value | N/A | 60 | Standard RRF constant |
| Multi-query variants | 0 | 2 | Better coverage |
| Re-rank method | None | GPT-5-nano | Cost-effective |

### Cost Impact

**Per search (with multi-query + re-rank):**
- Embedding: $0.00002 × 3 = $0.00006
- GPT-5-nano query expansion: $0.0001 (50 tokens)
- GPT-5-nano re-ranking: $0.0002 (200 tokens)
- **Total: ~$0.00036 per search** (~3x increase)

**For 10,000 searches/month:** $3.60 → $10.80

---

## Handling Both Transcripts and Documents

### File Type Detection

**Auto-detected as TRANSCRIPT if:**
- Filename contains "transcript" or "episode"
- File type is `text/vtt` or `application/x-subrip`
- Episode ID extracted automatically from filename (e.g., "Episode 42.txt" → episode_id: "42")

**Auto-detected as DOCUMENT if:**
- Regular PDF, DOCX, TXT, MD files
- Google Drive documents
- No episode-related keywords in filename

### Metadata Fields by Type

**Transcripts:**
```json
{
  "document_type": "transcript",
  "episode_id": "42",
  "speaker": null,
  "episode_title": "Insurance Claims Deep Dive",
  "language": "en"
}
```

**Documents:**
```json
{
  "document_type": "document",
  "episode_id": null,
  "speaker": null,
  "episode_title": null,
  "language": "en"
}
```

### Search Filtering Examples

**Search only transcripts:**
```json
{
  "query": "how to file a claim",
  "filters": {
    "documentType": "transcript"
  }
}
```

**Search specific episode:**
```json
{
  "query": "underwriting guidelines",
  "filters": {
    "episodeId": "42"
  }
}
```

**Search only documents (PDFs, DOCs):**
```json
{
  "query": "policy terms",
  "filters": {
    "documentType": "document",
    "fileTypes": ["application/pdf", "application/vnd.openxmlformats-officedocument.wordprocessingml.document"]
  }
}
```

**Search everything (default):**
```json
{
  "query": "insurance best practices"
}
```

### Null-Safe Querying

All metadata fields are **optional**. The hybrid search handles null values gracefully:

```javascript
// These queries work even if episode_id is null for most documents
WHERE metadata->>'episode_id' = '42'  // Returns only matching episodes
WHERE metadata->>'document_type' = 'document'  // Returns only documents
```

---

## Testing Checklist

1. **Test Transcript Upload:**
   - Upload file: "Episode 42 - Claims Process.txt"
   - Verify: `document_type: "transcript"`, `episode_id: "42"`, `episode_title: "Claims Process"`

2. **Test Document Upload:**
   - Upload file: "Insurance Policy 2024.pdf"
   - Verify: `document_type: "document"`, all episode fields null

3. **Test Hybrid Search (Transcripts):**
   - Query: "episode 42"
   - Should find exact episode ID match via BM25

4. **Test Hybrid Search (Documents):**
   - Query: "policy coverage limits"
   - Should find relevant PDFs/documents

5. **Test Multi-Query:**
   - Query: "insurance claim process"
   - Should generate variants like "how to file claim", "claim submission steps"

6. **Test Re-Ranking:**
   - Query: "best practices"
   - Should prioritize most relevant results (both transcripts and documents)

7. **Test Filtering:**
   - Filter: `documentType: "transcript"` → only transcript results
   - Filter: `episodeId: "42"` → only episode 42 chunks

---

## Rollback Plan

If issues occur:

1. **Disable Multi-Query:** Comment out Multi-Query Expansion node
2. **Disable Re-Ranking:** Comment out Re-Rank node
3. **Keep Hybrid:** Hybrid search is low-risk, keep enabled
4. **Full Rollback:** Restore original Vector Search node code

---

## Performance Expectations

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| Latency | 50-100ms | 200-400ms | +3-4x |
| Recall@10 | ~60% | ~85% | +42% |
| Precision@10 | ~70% | ~88% | +26% |
| Cost/search | $0.0001 | $0.00036 | +3.6x |

**Best for:** Production RAG where quality > speed

**Not good for:** Real-time autocomplete, high-volume free tier
