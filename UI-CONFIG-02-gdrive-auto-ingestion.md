# Google Drive Auto-Ingestion - UI Configuration Guide

## Workflow Overview
Automatically ingests documents from Google Drive into idudesRAG with vectorization and PostgreSQL storage.

**Flow**: `Google Drive Trigger → Download File → PrepDoc → SQL Insert → Edit Fields → Map → PGVector Store → Cleanup`

---

## Node Configuration

### 1. Google Drive Trigger
**Type**: `n8n-nodes-base.googleDriveTrigger` (v3)

**Parameters**:
```javascript
{
  folderId: "YOUR_GOOGLE_DRIVE_FOLDER_ID",
  triggerOn: "fileCreated",
  options: {
    includePermissions: false
  }
}
```

**Credentials**: Google Drive OAuth2 (`googleDriveOAuth2`)

---

### 2. Download File
**Type**: `n8n-nodes-base.googleDrive` (v3)

**Parameters**:
```javascript
{
  operation: "download",
  fileId: "={{ $json.id }}",
  options: {
    googleFileConversion: {
      conversion: {
        docsToFormat: "text/plain",
        sheetsToFormat: "text/csv",
        slidesToFormat: "text/plain"
      }
    }
  }
}
```

**Credentials**: Google Drive OAuth2 (`googleDriveOAuth2`)

**Critical**: Google Workspace files (Docs, Sheets, Slides) MUST be converted to standard formats or they return `[object Object]`

---

### 3. PrepDoc (Code Node)
**Type**: `n8n-nodes-base.code` (v2)

**JavaScript**:
```javascript
const input = $input.first();
let content = '';
let filename = 'unknown';
let file_type = 'text/plain';
let file_size = 0;
let source = 'google_drive';

// Extract metadata from Google Drive download node
if (input.json?.name) filename = input.json.name;
if (input.json?.mimeType) file_type = input.json.mimeType;
if (input.json?.size) file_size = parseInt(input.json.size);

// Extract and convert binary content to text
if (input.binary?.data) {
  const fileData = input.binary.data;

  // Handle Buffer object
  if (Buffer.isBuffer(fileData)) {
    try {
      content = fileData.toString('utf-8');
    } catch (e) {
      content = fileData.toString('base64');
    }
  }
  // Handle string
  else if (typeof fileData === 'string') {
    content = fileData;
  }
  // Handle object (Google Docs API response)
  else if (typeof fileData === 'object') {
    // Try to extract text from common Google API structures
    if (fileData.data) {
      content = Buffer.from(fileData.data, 'base64').toString('utf-8');
    } else {
      content = JSON.stringify(fileData);
    }
  }
  // Fallback
  else {
    content = String(fileData);
  }
}

// If still empty or [object Object], get from json.content or json.data
if (!content || content === '[object Object]') {
  if (input.json?.content) {
    content = typeof input.json.content === 'string'
      ? input.json.content
      : JSON.stringify(input.json.content);
  } else if (input.json?.data) {
    content = typeof input.json.data === 'string'
      ? input.json.data
      : JSON.stringify(input.json.data);
  }
}

return [{
  json: {
    pageContent: content,
    metadata: {
      filename: filename,
      spaces_url: null,
      file_type: file_type,
      file_size: file_size || content.length,
      source: source,
      timestamp: new Date().toISOString(),
      upload_source: 'google_drive',
      drive_file_id: input.json?.id || null
    }
  }
}];
```

**Handles**: Buffers, strings, objects, Google API responses, fallback to JSON stringify

---

### 4. Execute a SQL query
**Type**: `n8n-nodes-base.postgres` (v2.6)

**Parameters**:
```javascript
{
  operation: "executeQuery",
  query: `INSERT INTO core.documents (filename, spaces_url, content, file_size, file_type, metadata)
SELECT
  (j->'metadata'->>'filename')::text,
  (j->'metadata'->>'spaces_url')::text,
  (j->>'pageContent')::text,
  COALESCE(NULLIF(j->'metadata'->>'file_size','')::bigint, 0),
  (j->'metadata'->>'file_type')::text,
  COALESCE((j->'metadata')::jsonb, '{}'::jsonb)
FROM (SELECT $1::jsonb AS j) payload
ON CONFLICT (filename)
DO UPDATE SET
  spaces_url = EXCLUDED.spaces_url,
  content = EXCLUDED.content,
  file_size = EXCLUDED.file_size,
  file_type = EXCLUDED.file_type,
  metadata = EXCLUDED.metadata,
  updated_at = NOW() AT TIME ZONE 'America/Phoenix'
RETURNING id, filename, spaces_url, created_at, updated_at;`,
  options: {
    queryReplacement: "={{ JSON.stringify($json) }}"
  }
}
```

**SQL Breakdown**:
- **Upsert pattern**: `INSERT ... ON CONFLICT ... DO UPDATE`
- **JSON processing**: Extracts fields from JSONB using `->>` operator
- **Conflict resolution**: Updates on duplicate filename
- **Timezone**: America/Phoenix for timestamp
- **Returns**: Database record with generated `id`

**Credentials**: RailwayPG-idudes (`jd4YBgZXwugV4pZz`)

---

### 5. Edit Fields
**Type**: `n8n-nodes-base.set` (v3.4)

**Parameters**:
```javascript
{
  mode: "raw",
  jsonOutput: `={
    "pageContent": "{{ $('PrepDoc').first().json.pageContent }}",
    "metadata": {
      "filename": "{{ $('PrepDoc').first().json.metadata.filename }}",
      "file_type": "{{ $('PrepDoc').first().json.metadata.file_type }}",
      "file_size": "{{ $('PrepDoc').first().json.metadata.file_size }}",
      "source": "{{ $('PrepDoc').first().json.metadata.source }}",
      "timestamp": "{{ $('PrepDoc').first().json.metadata.timestamp }}",
      "upload_source": "{{ $('PrepDoc').first().json.metadata.upload_source }}",
      "drive_file_id": "{{ $('PrepDoc').first().json.metadata.drive_file_id }}",
      "document_id": "{{ $('Execute a SQL query').first().json.id }}"
    }
  }`,
  options: {
    dotNotation: true
  }
}
```

**Expression Mode**: `raw` with mustache template syntax
**Key Addition**: Merges DB `id` as `document_id` into metadata

---

### 6. map (Code Node)
**Type**: `n8n-nodes-base.code` (v2)

**JavaScript**:
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
  if (!isUuid(document_id)) document_id = undefined;

  const mapped = {
    pageContent,
    metadata: {
      filename: md.filename ?? 'unknown',
      spaces_url: md.spaces_url ?? null,
      file_type: md.file_type ?? 'text/plain',
      file_size: toInt(md.file_size ?? pageContent.length),
      source: md.source ?? 'google_drive',
      timestamp: asIso(md.timestamp),
      upload_source: md.upload_source ?? 'google_drive',
      drive_file_id: md.drive_file_id ?? null,
      ...(document_id ? { document_id } : {})
    }
  };

  out.push({ json: mapped });
}

console.log('Mapped docs →', JSON.stringify(out.map(i => i.json), null, 2));
return out;
```

**Purpose**: Normalizes document structure for PGVector ingestion

---

### 7. DocLoader
**Type**: `@n8n/n8n-nodes-langchain.documentDefaultDataLoader` (v1.1)

**Parameters**:
```javascript
{
  jsonMode: "expressionData",
  jsonData: "={{ $('map').item.json.pageContent }}",
  textSplittingMode: "custom",
  options: {
    metadata: {
      metadataValues: [
        {
          name: "filename",
          value: "={{ $('map').first().json.metadata.filename }}"
        },
        {
          name: "source",
          value: "={{ $('map').first().json.metadata.source }}"
        },
        {
          name: "file_type",
          value: "={{ $('map').first().json.metadata.file_type }}"
        },
        {
          name: "file_size",
          value: "={{ $('map').first().json.metadata.file_size }}"
        },
        {
          name: "timestamp",
          value: "={{ $('map').first().json.metadata.timestamp }}"
        },
        {
          name: "document_id",
          value: "={{ $('map').first().json.metadata.document_id }}"
        },
        {
          name: "drive_file_id",
          value: "={{ $('map').first().json.metadata.drive_file_id }}"
        }
      ]
    }
  }
}
```

**Connection**: Links to Text Splitter via `ai_textSplitter`

---

### 8. Text Splitter
**Type**: `@n8n/n8n-nodes-langchain.textSplitterRecursiveCharacterTextSplitter` (v1)

**Parameters**:
```javascript
{
  chunkSize: 10000,
  chunkOverlap: 200,
  options: {}
}
```

**Connection**: Links to DocLoader via `ai_textSplitter`

---

### 9. Embeddings OpenAI
**Type**: `@n8n/n8n-nodes-langchain.embeddingsOpenAi` (v1.2)

**Parameters**:
```javascript
{
  options: {
    dimensions: 1536,
    batchSize: 200
  }
}
```

**Model**: `text-embedding-3-small` (1536 dimensions)
**Credentials**: ZARAapiKey (`EQYdxPEgshiwvESa`)
**Connection**: Links to PGVector Store via `ai_embedding`

---

### 10. PGVector Store
**Type**: `@n8n/n8n-nodes-langchain.vectorStorePGVector` (v1.3)

**Parameters**:
```javascript
{
  mode: "insert",
  tableName: "core.document_embeddings",
  options: {}
}
```

**Credentials**: RailwayPG-idudes (`jd4YBgZXwugV4pZz`)
**Connections**:
- **Input (main)**: map node
- **Input (ai_document)**: DocLoader
- **Input (ai_embedding)**: Embeddings OpenAI
- **Output (main)**: Cleanup Connections

---

### 11. Cleanup Connections (Code Node)
**Type**: `n8n-nodes-base.code` (v2)

**JavaScript**:
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

**Purpose**: Prevents memory leaks by cleaning up global DB connection objects

---

## Connection Map

```
Google Drive Trigger (main) → Download File
Download File (main) → PrepDoc
PrepDoc (main) → Execute a SQL query
Execute a SQL query (main) → Edit Fields
Edit Fields (main) → map
map (main) → PGVector Store
Text Splitter (ai_textSplitter) → DocLoader
DocLoader (ai_document) → PGVector Store
Embeddings OpenAI (ai_embedding) → PGVector Store
PGVector Store (main) → Cleanup Connections
```

---

## Critical Configuration Notes

### Expression Syntax
- **Mustache templates**: `{{ $('NodeName').first().json.field }}`
- **JSON stringify in SQL**: `={{ JSON.stringify($json) }}`
- **Item iteration**: `{{ $('map').item.json.pageContent }}`

### PostgreSQL Patterns
1. **JSONB operators**:
   - `->>`: Extract as text
   - `->`: Extract as JSONB
   - `COALESCE()`: Null handling

2. **Query replacement**:
   ```javascript
   options: {
     queryReplacement: "={{ JSON.stringify($json) }}"
   }
   ```

3. **Timezone**: Always use `NOW() AT TIME ZONE 'America/Phoenix'`

### Vector Store Requirements
- **Dimensions**: 1536 (matches OpenAI `text-embedding-3-small`)
- **Table**: `core.document_embeddings`
- **Schema**: Must have pgvector extension enabled

### Credentials Required
1. **Google Drive OAuth2**: For Drive Trigger + Download
2. **RailwayPG-idudes** (`jd4YBgZXwugV4pZz`): PostgreSQL connection
3. **ZARAapiKey** (`EQYdxPEgshiwvESa`): OpenAI embeddings

---

## Testing Checklist

- [ ] Google Drive folder ID configured
- [ ] OAuth credentials active
- [ ] PostgreSQL `core.documents` table exists
- [ ] PostgreSQL `core.document_embeddings` table exists with pgvector
- [ ] OpenAI API key valid
- [ ] Test file upload to Drive folder
- [ ] Verify DB insert in `core.documents`
- [ ] Verify vector insert in `core.document_embeddings`
- [ ] Check metadata includes `drive_file_id` and `document_id`

---

## Database Schema Requirements

### core.documents
```sql
CREATE TABLE core.documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  filename TEXT UNIQUE NOT NULL,
  spaces_url TEXT,
  content TEXT NOT NULL,
  file_size BIGINT DEFAULT 0,
  file_type TEXT DEFAULT 'text/plain',
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW() AT TIME ZONE 'America/Phoenix',
  updated_at TIMESTAMPTZ DEFAULT NOW() AT TIME ZONE 'America/Phoenix'
);
```

### core.document_embeddings
```sql
CREATE TABLE core.document_embeddings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id UUID REFERENCES core.documents(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  metadata JSONB DEFAULT '{}'::jsonb,
  embedding vector(1536),
  created_at TIMESTAMPTZ DEFAULT NOW() AT TIME ZONE 'America/Phoenix'
);

-- Index for similarity search
CREATE INDEX idx_document_embeddings_vector
ON core.document_embeddings
USING ivfflat (embedding vector_cosine_ops);
```

---

## Performance Optimizations

1. **Batch Processing**: Set `batchSize: 200` in OpenAI embeddings
2. **Chunk Optimization**: 10k characters with 200 overlap
3. **Connection Cleanup**: Mandatory final node to prevent memory leaks
4. **Upsert Logic**: Prevents duplicate entries on re-ingestion

---

## Winning Logic from Flow 01

✅ **PrepDoc normalization**: Standardized pageContent + metadata structure
✅ **SQL upsert with RETURNING**: Captures DB-generated ID
✅ **Edit Fields merge**: Combines PrepDoc + SQL results
✅ **map validation**: UUID checking, type coercion, safe fallbacks
✅ **DocLoader expression mode**: `jsonMode: "expressionData"` + `jsonData` with stringify
✅ **Metadata preservation**: All fields flow through to vector store
✅ **Connection cleanup**: Prevents n8n workflow memory leaks

---

## Environment Variables (if needed)

```bash
# Google Drive
GOOGLE_DRIVE_FOLDER_ID="your-folder-id-here"

# PostgreSQL (Railway)
DATABASE_URL="postgres://postgres:5Prl6LQokZHCIo59EOr3Tys0esF7ubao@trolley.proxy.rlwy.net:35195/railway"

# OpenAI
OPENAI_API_KEY="your-openai-key"
```
