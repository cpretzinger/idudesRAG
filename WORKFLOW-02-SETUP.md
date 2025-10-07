# Workflow 02 - Document Upload & Vectorization Setup

## SQL - Database Schema

```sql
-- Documents table (if not exists)
CREATE TABLE IF NOT EXISTS core.documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  filename TEXT NOT NULL UNIQUE,
  content TEXT NOT NULL,
  file_size BIGINT NOT NULL DEFAULT 0,
  file_type TEXT NOT NULL DEFAULT 'text/plain',
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() AT TIME ZONE 'America/Phoenix'),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() AT TIME ZONE 'America/Phoenix'),

  CONSTRAINT chk_filename_not_empty CHECK (filename IS NOT NULL AND filename != ''),
  CONSTRAINT chk_content_not_empty CHECK (content IS NOT NULL AND content != '')
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_documents_filename ON core.documents(filename);
CREATE INDEX IF NOT EXISTS idx_documents_file_type ON core.documents(file_type);
CREATE INDEX IF NOT EXISTS idx_documents_created_at ON core.documents(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_documents_metadata_gin ON core.documents USING gin(metadata);

-- Document embeddings table for PGVector
CREATE TABLE IF NOT EXISTS core.document_embeddings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  embedding vector(1536),
  document JSONB NOT NULL,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() AT TIME ZONE 'America/Phoenix')
);

-- Create vector index for similarity search
CREATE INDEX IF NOT EXISTS idx_document_embeddings_vector
  ON core.document_embeddings
  USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 100);

-- Grant permissions
GRANT ALL ON core.documents TO postgres;
GRANT ALL ON core.document_embeddings TO postgres;
```

## n8n Configuration

### Credentials Needed

1. **PostgreSQL** (Railway)
   - **Name:** `RailwayPG-idudes`
   - **Connection String:** `postgres://postgres:5Prl6LQokZHCIo59EOr3Tys0esF7ubao@trolley.proxy.rlwy.net:35195/railway`
   - **Used in nodes:** Execute a SQL query, PGVector Store

2. **OpenAI API**
   - **Name:** `ZARAapiKey`
   - **API Key:** Your OpenAI key with embedding access
   - **Used in nodes:** Embeddings OpenAI

### Webhook Configuration

**Webhook URL:** `https://ai.thirdeyediagnostics.com/webhook/documents`

**Method:** POST

**Request Body:**
```json
{
  "filename": "example.txt",
  "content": "Your document content here (or base64 encoded)",
  "type": "text/plain",
  "size": 1234,
  "source": "idudesRAG-upload"
}
```

**Example cURL - Plain Text:**
```bash
curl -X POST https://ai.thirdeyediagnostics.com/webhook/documents \
  -H "Content-Type: application/json" \
  -d '{
    "filename": "test-document.txt",
    "content": "This is a test document for the insurance RAG system.",
    "type": "text/plain",
    "size": 54,
    "source": "api-upload"
  }'
```

**Example cURL - Base64 Encoded:**
```bash
# First, encode your file
CONTENT=$(cat document.txt | base64)

curl -X POST https://ai.thirdeyediagnostics.com/webhook/documents \
  -H "Content-Type: application/json" \
  -d "{
    \"filename\": \"document.txt\",
    \"content\": \"$CONTENT\",
    \"type\": \"text/plain\",
    \"source\": \"api-upload\"
  }"
```

## Code Nodes

### 1. PrepDoc (node 324fe44a)

**Purpose:** Extract and decode document content from webhook payload

```javascript
const input = $input.first();
let content = '';
let filename = 'unknown';
let file_type = 'text/plain';
let file_size = 0;
let source = 'idudesRAG-upload';

// Extract metadata from webhook BODY
if (input.json.body?.filename) filename = input.json.body.filename;
if (input.json.body?.type) file_type = input.json.body.type;
if (input.json.body?.size) file_size = parseInt(input.json.body.size);
if (input.json.body?.source) source = input.json.body.source;

// Extract and DECODE content from body
if (input.json.body?.content) {
  content = input.json.body.content;
  // DECODE if base64 encoded
  if (content && /^[A-Za-z0-9+/=]+$/.test(content) && content.length > 50) {
    try {
      content = Buffer.from(content, 'base64').toString('utf-8');
    } catch (e) {
      // Not base64, keep original
    }
  }
}

return [{
  json: {
    pageContent: content,
    metadata: {
      filename: filename,
      file_type: file_type,
      file_size: file_size || content.length,
      source: source,
      timestamp: new Date().toISOString(),
      upload_source: 'webhook'
    }
  }
}];
```

### 2. map (node 2a6244bb)

**Purpose:** Normalize document structure for PGVector with database ID

```javascript
// n8n Code node: map/normalize doc → PGVector-ready

// --- helpers ---
const toInt = (v) => {
  if (v === null || v === undefined) return 0;
  const n = parseInt(String(v), 10);
  return Number.isNaN(n) ? 0 : n;
};

const asIso = (v) => {
  try {
    if (!v) return new Date().toISOString();
    const d = new Date(v);
    return isNaN(d.getTime()) ? new Date().toISOString() : d.toISOString();
  } catch {
    return new Date().toISOString();
  }
};

const isUuid = (v) =>
  typeof v === 'string' &&
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(v);

// try to read DB id from the SQL node; safe if missing
let dbId;
try {
  dbId = $('Execute a SQL query').first().json?.id;
} catch (_) {
  dbId = undefined;
}

// accept current items or fall back to PrepDoc
let raw = $input.all().map(i => i.json);
if (raw.length === 0) {
  try {
    const p = $('PrepDoc').first().json;
    if (p) raw = [p];
  } catch (_) {}
}

const out = [];

for (const doc of raw) {
  const md = doc?.metadata ?? {};
  const pageContent = String(doc?.pageContent ?? '');

  // choose document_id priority: DB id → existing metadata
  let document_id = dbId ?? md.document_id;
  if (!isUuid(document_id)) document_id = undefined; // or throw if you want to hard-fail

  const mapped = {
    pageContent,
    metadata: {
      filename: md.filename ?? 'unknown',
      file_type: md.file_type ?? 'text/plain',
      file_size: toInt(md.file_size ?? pageContent.length),
      source: md.source ?? 'idudesRAG-upload',
      timestamp: asIso(md.timestamp),
      upload_source: md.upload_source ?? 'webhook',
      ...(document_id ? { document_id } : {})
    }
  };

  out.push({ json: mapped });
}

console.log('Mapped docs →', JSON.stringify(out.map(i => i.json), null, 2));
return out;
```

### 3. Code in JavaScript (Cleanup - node 734ec10a)

**Purpose:** Clean up database connections after workflow completes

```javascript
// FINAL VERSION - CLOSE DB CONNECTIONS NODE FOR n8n
// Copy this entire code into a Code node (JavaScript) at the end of your workflow
// This version works without external modules

// 1. Clean up any global connection objects
const globalCleanup = () => {
  const targets = ['pgPool', 'pgClient', 'dbConn', 'redisClient'];
  let cleaned = 0;

  targets.forEach(name => {
    if (global[name]) {
      try {
        delete global[name];
        cleaned++;
      } catch (e) {
        // Silent fail
      }
    }
  });

  return cleaned;
};

// 2. Generate cleanup report
const generateReport = (cleaned) => {
  return {
    workflow: $workflow.name || 'Unknown',
    workflowId: $workflow.id,
    execution: $execution.id,
    timestamp: new Date().toISOString(),
    connectionsCleared: cleaned,
    status: 'success'
  };
};

// 3. Execute cleanup
const cleaned = globalCleanup();
const report = generateReport(cleaned);

// 4. Log the results
console.log('🧹 Cleanup Complete:', JSON.stringify(report, null, 2));

// 5. Pass through the data with cleanup metadata
return $input.all().map(item => ({
  ...item,
  json: {
    ...item.json,
    _cleanup: report
  }
}));
```

## SQL Queries

### Execute a SQL query (node 3f1777d2)

**Purpose:** Insert or update document in PostgreSQL

```sql
INSERT INTO core.documents (filename, content, file_size, file_type, metadata)
SELECT
  (j->'metadata'->>'filename')::text,
  (j->>'pageContent')::text,
  COALESCE(NULLIF(j->'metadata'->>'file_size','')::bigint, 0),
  (j->'metadata'->>'file_type')::text,
  COALESCE((j->'metadata')::jsonb, '{}'::jsonb)
FROM (SELECT $1::jsonb AS j) payload
ON CONFLICT (filename)
DO UPDATE SET
  content = EXCLUDED.content,
  file_size = EXCLUDED.file_size,
  file_type = EXCLUDED.file_type,
  metadata = EXCLUDED.metadata,
  updated_at = NOW() AT TIME ZONE 'America/Phoenix'
RETURNING id, filename, created_at, updated_at;
```

**Query Replacement:** `={{ JSON.stringify($json) }}`

## Set Node Configuration

### Edit Fields (node 9595598f)

**Mode:** Raw (JSON)

**JSON Output:**
```
={
  "pageContent": "{{ $('PrepDoc').first().json.pageContent }}",
  "metadata": {
    "filename": "{{ $('PrepDoc').first().json.metadata.filename }}",
    "file_type": "{{ $('PrepDoc').first().json.metadata.file_type }}",
    "file_size": "{{ $('PrepDoc').first().json.metadata.file_size }}",
    "source": "{{ $('PrepDoc').first().json.metadata.source }}",
    "timestamp": "{{ $('PrepDoc').first().json.metadata.timestamp }}",
    "upload_source": "{{ $('PrepDoc').first().json.metadata.upload_source }}",
    "document_id": "{{ $('Execute a SQL query').first().json.id }}"
  }
}
```

**Options:** Enable "Dot Notation"

## LangChain Nodes Configuration

### DocLoader (node bebc8bdd)

**Type:** Default Document Loader
**JSON Mode:** Expression Data
**JSON Data:** `={{ $('map').item.json.pageContent }}`

**Metadata Values:**
- `filename`: `={{ $('map').first().json.metadata.filename }}`
- `source`: `={{ $('map').first().json.metadata.source }}`
- `file_type`: `={{ $('map').first().json.metadata.file_type }}`
- `file_size`: `={{ $('map').first().json.metadata.file_size }}`
- `timestamp`: `={{ $('map').first().json.metadata.timestamp }}`
- `document_id`: `={{ $('map').first().json.metadata.document_id }}`

### Text Splitter (node ab0c7333)

**Type:** Recursive Character Text Splitter
- **Chunk Size:** 10000
- **Chunk Overlap:** 200

### Embeddings OpenAI (node 4402f494)

**Type:** OpenAI Embeddings
- **Dimensions:** 1536
- **Batch Size:** 200
- **Credential:** ZARAapiKey

### PGVector Store (node 5e9d245f)

**Type:** PGVector
- **Mode:** Insert
- **Table Name:** `core.document_embeddings`
- **Credential:** RailwayPG-idudes

## Workflow Flow

```
Webhook
  ↓
PrepDoc (decode content)
  ↓
Execute SQL Query (insert to documents table, get ID)
  ↓
Edit Fields (add document_id to metadata)
  ↓
map (normalize for vectorization)
  ↓
PGVector Store (with Text Splitter + Embeddings)
  ↓
Code in JavaScript (cleanup)
```

## Testing

### Test 1: Simple Text Upload
```bash
curl -X POST https://ai.thirdeyediagnostics.com/webhook/documents \
  -H "Content-Type: application/json" \
  -d '{
    "filename": "claim-summary.txt",
    "content": "Claim number: CLM-2025-001. Policyholder John Doe filed a claim for vehicle damage on 2025-01-15. Estimated damage: $5,000.",
    "type": "text/plain",
    "source": "claim-intake"
  }'
```

### Test 2: Base64 Encoded File
```bash
# Create test file
echo "Insurance policy document for customer ABC-123" > policy.txt

# Encode and upload
CONTENT=$(cat policy.txt | base64 -w 0)
curl -X POST https://ai.thirdeyediagnostics.com/webhook/documents \
  -H "Content-Type: application/json" \
  -d "{
    \"filename\": \"policy-ABC-123.txt\",
    \"content\": \"$CONTENT\",
    \"type\": \"text/plain\",
    \"source\": \"policy-upload\"
  }"
```

## Verification Queries

### Check uploaded documents
```sql
SELECT
  id,
  filename,
  file_type,
  file_size,
  LENGTH(content) as content_length,
  metadata->>'source' as source,
  metadata->>'upload_source' as upload_source,
  created_at,
  updated_at
FROM core.documents
ORDER BY created_at DESC
LIMIT 10;
```

### Check embeddings
```sql
SELECT
  id,
  metadata->>'filename' as filename,
  metadata->>'document_id' as document_id,
  LENGTH(document::text) as doc_size,
  created_at
FROM core.document_embeddings
ORDER BY created_at DESC
LIMIT 10;
```

### Count chunks per document
```sql
SELECT
  metadata->>'filename' as filename,
  COUNT(*) as chunk_count,
  AVG(LENGTH(document->>'pageContent')) as avg_chunk_size
FROM core.document_embeddings
GROUP BY metadata->>'filename'
ORDER BY chunk_count DESC;
```

## Troubleshooting

### Error: "violates check constraint chk_content_not_empty"
**Cause:** Document content is empty or whitespace only
**Fix:** Ensure content is being decoded properly in PrepDoc node. Check base64 decoding logic.

### Error: "duplicate key value violates unique constraint"
**Cause:** Document with same filename already exists
**Solution:** The workflow uses `ON CONFLICT` to update existing documents. This should work automatically.

### No embeddings created
**Check:**
1. PGVector Store credential is correct
2. OpenAI API key has embedding permissions
3. Text Splitter is connected to DocLoader
4. Map node is passing data correctly

## Performance Notes

- **Chunk Size:** 10,000 characters balances context vs. granularity
- **Overlap:** 200 characters ensures continuity across chunks
- **Batch Size:** 200 embeddings per API call optimizes throughput
- **Vector Index:** `ivfflat` with 100 lists suitable for <1M vectors

## Cost Optimization

- Use OpenAI text-embedding-3-small (1536 dimensions) for cost efficiency
- Consider batching uploads if processing many documents
- Monitor token usage in OpenAI dashboard
