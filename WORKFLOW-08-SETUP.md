# Workflow 08 - Chat & Knowledge Search Setup

## Overview

**Unified webhook** that handles both:
- **Chat queries** with conversation memory and RAG
- **Vector search** for document retrieval

**Webhook URL:** `https://ai.thirdeyediagnostics.com/webhook/chat-knowledge`

---

## Architecture

### Mode Detection (Auto-Route)
The workflow automatically detects the request type:

**Chat Mode** - When `messages` array is present:
```json
{
  "messages": [
    { "role": "user", "content": "What documents mention claims?" }
  ],
  "model": "gpt-5-nano"
}
```

**Search Mode** - When `query` string is present:
```json
{
  "query": "insurance policy documents",
  "limit": 10,
  "minSimilarity": 0.7
}
```

---

## n8n Workflow Configuration

### Credentials Needed

1. **PostgreSQL** (Railway)
   - **Name:** `RailwayPG-idudes`
   - **Connection:** `postgres://postgres:d7ToQHAA7VecTKi2DxFgNxtlj~xN_HnD@yamabiko.proxy.rlwy.net:15649/railway`
   - **Note:** Updated credentials from CLAUDE.md

2. **OpenAI API**
   - **Name:** `ZARAapiKey`
   - **API Key:** Your OpenAI key with GPT-5 and embeddings access

---

## Code Nodes

### 1. Parse Request (node: parse-request)

**Purpose:** Determine if request is chat or search mode

```javascript
// Parse webhook request and determine mode
const body = $input.first().json.body || {};
const messages = body.messages;
const query = body.query;
const model = body.model || 'gpt-5-nano';

if (messages && Array.isArray(messages)) {
  // CHAT MODE: Process conversation with memory
  const lastMessage = messages[messages.length - 1];
  const chatInput = lastMessage?.content || '';

  return [{
    json: {
      mode: 'chat',
      chatInput: chatInput,
      messages: messages,
      model: model,
      timestamp: new Date().toISOString()
    }
  }];

} else if (query && typeof query === 'string') {
  // SEARCH MODE: Pure vector search
  return [{
    json: {
      mode: 'search',
      query: query,
      limit: body.limit || 10,
      minSimilarity: body.minSimilarity || 0.7,
      filters: {
        startDate: body.startDate || null,
        endDate: body.endDate || null,
        fileTypes: body.fileTypes || null
      },
      timestamp: new Date().toISOString()
    }
  }];

} else {
  throw new Error('Request must include either "messages" array (chat) or "query" string (search)');
}
```

### 2. Format Chat Response (node: format-chat-response)

**Purpose:** Format AI agent output for webhook response

```javascript
// Format chat response
const agentOutput = $input.first().json.output || '';

return [{
  json: {
    success: true,
    message: agentOutput,
    model: 'gpt-5-nano',
    mode: 'chat',
    timestamp: new Date().toISOString()
  }
}];
```

### 3. Vector Search (node: vector-search-direct)

**Purpose:** Perform direct vector similarity search

```javascript
// Perform vector search using PGVector
const query = $json.query;
const limit = $json.limit || 10;
const minSimilarity = $json.minSimilarity || 0.7;

// Generate embedding for query
const embeddingResponse = await $('Embeddings OpenAI').execute();
const queryEmbedding = embeddingResponse[0].json.embedding;

// Query PGVector
const pgCredentials = $('PGVector Store').credentials.postgres;
const { Client } = require('pg');

const client = new Client({
  connectionString: pgCredentials.connectionString
});

try {
  await client.connect();

  const searchQuery = `
    SELECT
      id,
      document,
      metadata,
      1 - (embedding <=> $1::vector) AS similarity
    FROM core.document_embeddings
    WHERE 1 - (embedding <=> $1::vector) >= $2
    ORDER BY embedding <=> $1::vector
    LIMIT $3
  `;

  const result = await client.query(searchQuery, [
    JSON.stringify(queryEmbedding),
    minSimilarity,
    limit
  ]);

  const results = result.rows.map(row => ({
    id: row.id,
    content: row.document.pageContent || row.document,
    metadata: row.metadata,
    similarity: row.similarity
  }));

  return [{
    json: {
      success: true,
      query: query,
      results: results,
      count: results.length,
      mode: 'search',
      timestamp: new Date().toISOString()
    }
  }];

} finally {
  await client.end();
}
```

---

## LangChain Components

### AI Agent Configuration
- **Model:** gpt-5-nano (cost optimized)
- **System Message:** "You are the Insurance Dudes AI Assistant..."
- **Memory:** Buffer Window (8 messages)
- **Tools:** Vector Search Tool

### Vector Search Tool
- **Description:** "Search Insurance Dudes documents using vector similarity"
- **Top-K:** 4 results
- **Distance Strategy:** Cosine

### PGVector Store
- **Table:** `core.document_embeddings`
- **Embedding Dimensions:** 1536
- **Distance:** Cosine similarity

---

## Workflow Flow

### Chat Mode
```
Webhook (POST /chat-knowledge)
  ↓
Parse Request (detect chat mode)
  ↓
Route by Mode → Chat Path
  ↓
AI Agent (with memory + vector tool)
  ↓
Format Chat Response
  ↓
Respond to Webhook
```

### Search Mode
```
Webhook (POST /chat-knowledge)
  ↓
Parse Request (detect search mode)
  ↓
Route by Mode → Search Path
  ↓
Vector Search (direct PGVector query)
  ↓
Respond to Webhook
```

---

## API Integration (UI)

### Environment Variables

Create `.env` in project root:
```bash
# n8n Webhooks (Required - UI calls these endpoints)
N8N_DOCUMENTS_WEBHOOK_URL=https://ai.thirdeyediagnostics.com/webhook/documents
N8N_CHAT_WEBHOOK_URL=https://ai.thirdeyediagnostics.com/webhook/chat-knowledge
N8N_SEARCH_WEBHOOK_URL=https://ai.thirdeyediagnostics.com/webhook/chat-knowledge

# Next.js (Optional)
NEXT_PUBLIC_APP_URL=http://localhost:3000
```

**Note:** PostgreSQL and Redis are NOT needed in `.env` - n8n workflows handle all database access!

### Chat API Usage

**File:** `/ui/app/api/chat/route.ts`

**Request:**
```typescript
POST /api/chat
{
  "messages": [
    { "role": "user", "content": "What is the claim process?" }
  ],
  "model": "gpt-5-nano"
}
```

**Response:**
```typescript
{
  "success": true,
  "message": "The claim process involves...",
  "model": "gpt-5-nano",
  "usage": { ... }
}
```

### Search API Usage

**File:** `/ui/app/api/search/route.ts`

**Request:**
```typescript
POST /api/search
{
  "query": "insurance policy documents",
  "limit": 10,
  "minSimilarity": 0.7,
  "startDate": "2025-01-01",
  "endDate": "2025-12-31",
  "fileTypes": ["pdf", "docx"]
}
```

**Response:**
```typescript
{
  "success": true,
  "query": "insurance policy documents",
  "results": [
    {
      "id": "uuid",
      "content": "Document content...",
      "metadata": {
        "filename": "policy.pdf",
        "file_type": "application/pdf"
      },
      "similarity": 0.85
    }
  ],
  "count": 5
}
```

---

## Testing

### Test 1: Chat Query
```bash
curl -X POST https://ai.thirdeyediagnostics.com/webhook/chat-knowledge \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      { "role": "user", "content": "What documents do we have about claims?" }
    ],
    "model": "gpt-5-nano"
  }'
```

**Expected Response:**
```json
{
  "success": true,
  "message": "Based on the documents, we have several claim-related files including...",
  "model": "gpt-5-nano",
  "mode": "chat",
  "timestamp": "2025-10-07T08:00:00.000Z"
}
```

### Test 2: Vector Search
```bash
curl -X POST https://ai.thirdeyediagnostics.com/webhook/chat-knowledge \
  -H "Content-Type: application/json" \
  -d '{
    "query": "insurance claims process",
    "limit": 5,
    "minSimilarity": 0.7
  }'
```

**Expected Response:**
```json
{
  "success": true,
  "query": "insurance claims process",
  "results": [
    {
      "id": "...",
      "content": "The claims process begins with...",
      "metadata": { "filename": "claims-guide.pdf" },
      "similarity": 0.92
    }
  ],
  "count": 5,
  "mode": "search",
  "timestamp": "2025-10-07T08:00:00.000Z"
}
```

### Test 3: UI Chat Page
1. Navigate to `http://localhost:3000/chat`
2. Type: "What documents are available?"
3. Verify: AI responds with document list using RAG

### Test 4: UI Search (if search page exists)
1. Navigate to search page
2. Search: "policy documents"
3. Verify: Results show relevant documents with similarity scores

---

## Verification Queries

### Check recent chat requests
```sql
SELECT
  created_at,
  metadata->>'mode' as mode,
  metadata->>'model' as model,
  LEFT(metadata->>'query', 50) as query_preview
FROM core.api_logs
WHERE endpoint = '/webhook/chat-knowledge'
ORDER BY created_at DESC
LIMIT 20;
```

### Monitor vector search performance
```sql
SELECT
  COUNT(*) as total_searches,
  AVG((metadata->>'count')::int) as avg_results_returned,
  AVG((metadata->>'similarity')::float) as avg_similarity
FROM core.api_logs
WHERE endpoint = '/webhook/chat-knowledge'
  AND metadata->>'mode' = 'search'
  AND created_at >= NOW() - INTERVAL '24 hours';
```

---

## Troubleshooting

### Issue: Chat not working
**Check:**
1. Webhook path is `/chat-knowledge`
2. UI sends `messages` array
3. AI Agent is connected to OpenAI Chat Model
4. Memory node is connected

**Test:**
```bash
# Direct webhook test
curl -X POST https://ai.thirdeyediagnostics.com/webhook/chat-knowledge \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"test"}]}'
```

### Issue: Search returns no results
**Check:**
1. Documents are properly embedded in `core.document_embeddings`
2. `minSimilarity` threshold isn't too high (try 0.5)
3. Embeddings OpenAI node has correct credentials

**Verify embeddings exist:**
```sql
SELECT COUNT(*) FROM core.document_embeddings;
```

### Issue: Slow response times
**Optimize:**
1. Reduce `topK` from 4 to 2 for faster searches
2. Use batch embeddings (already set to 512)
3. Consider caching frequent queries

---

## Cost Optimization

### GPT-5-nano Pricing
- **Input:** $0.050 / 1M tokens
- **Cached Input:** $0.005 / 1M tokens (90% cheaper!)
- **Output:** $0.400 / 1M tokens

### Recommendations
1. **Use caching** - System messages and document context can be cached
2. **Limit context** - Keep memory window at 8 messages (already configured)
3. **Batch processing** - For bulk searches, use Batch API (50% discount)

### Example Costs
- 100 chat messages (avg 500 tokens each): **$0.02**
- 1000 vector searches (with embeddings): **$0.03**
- Daily operation (50 chats + 200 searches): **$0.05/day = $1.50/month**

---

## Next Steps

1. ✅ Import workflow 08 to n8n
2. ✅ Update UI `.env.local` with webhook URLs
3. ✅ Test chat functionality
4. ✅ Test search functionality
5. ⏳ Monitor usage and costs
6. ⏳ Consider adding search page to UI (currently only chat exists)

---

## Advanced Features (Optional)

### Add Date Filtering to Search
Modify Vector Search code node to filter by date:

```javascript
// Add to WHERE clause
AND (metadata->>'timestamp')::timestamptz >= $4::timestamptz
AND (metadata->>'timestamp')::timestamptz <= $5::timestamptz
```

### Add File Type Filtering
```javascript
// Add to WHERE clause
AND metadata->>'file_type' = ANY($6::text[])
```

### Implement Hybrid Search
Combine vector search with keyword matching:

```sql
SELECT
  id,
  document,
  metadata,
  (
    (1 - (embedding <=> $1::vector)) * 0.7 +  -- Vector score (70%)
    ts_rank(to_tsvector('english', document->>'pageContent'),
            plainto_tsquery('english', $4)) * 0.3  -- Keyword score (30%)
  ) AS hybrid_score
FROM core.document_embeddings
WHERE ...
ORDER BY hybrid_score DESC
```
