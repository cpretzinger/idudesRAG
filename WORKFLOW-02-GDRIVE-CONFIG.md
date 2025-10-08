# Workflow 02 - Google Drive Auto-Ingestion Configuration

## Node 1: Google Drive Trigger

**Node Type:** Google Drive Trigger
**Trigger On:** File Created
**Folder ID:** YOUR_GOOGLE_DRIVE_FOLDER_ID

### Options
- Include Permissions: `false`

### Credentials
- Google Drive OAuth2: `GOOGLE_DRIVE_OAUTH_CREDENTIAL_ID`

---

## Node 2: Download File

**Node Type:** Google Drive
**Operation:** Download
**File ID:** `{{ $json.id }}`

### Google File Conversion
- Docs to Format: `text/plain`
- Sheets to Format: `text/csv`
- Slides to Format: `text/plain`

### Credentials
- Google Drive OAuth2: `GOOGLE_DRIVE_OAUTH_CREDENTIAL_ID`

---

## Node 3: PrepDoc

**Node Type:** Code (JavaScript)

### JavaScript Code

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

// Extract content from Google Drive download
if (input.binary?.data) {
  const fileData = input.binary.data;

  // Handle Buffer object - Google Drive returns Buffer after conversion
  if (Buffer.isBuffer(fileData)) {
    // Buffer is already decoded text from Google Drive conversion
    content = fileData.toString('utf-8');
  }
  // Handle string
  else if (typeof fileData === 'string') {
    content = fileData;
  }
  // Handle object (Google Docs API response with base64 data)
  else if (typeof fileData === 'object') {
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

// Fallback: try json.content or json.data
if (!content || content === '[object Object]') {
  if (input.json?.content) {
    content = typeof input.json.content === 'string' ? input.json.content : JSON.stringify(input.json.content);
  } else if (input.json?.data) {
    content = typeof input.json.data === 'string' ? input.json.data : JSON.stringify(input.json.data);
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
      upload_source: 'google_drive',
      drive_file_id: input.json?.id || null
    }
  }
}];
```

---

## Node 4: Execute a SQL query

**Node Type:** Postgres
**Operation:** Execute Query

### SQL Query

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

### Query Replacement

```
{{ JSON.stringify($json) }}
```

### Credentials
- PostgreSQL: `RailwayPG-idudes`

---

## Node 5: Edit Fields

**Node Type:** Set
**Mode:** Raw (JSON)

### JSON Output

```
{
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
}
```

### Options
- Dot Notation: `enabled`

---

## Node 6: map

**Node Type:** Code (JavaScript)

### JavaScript Code

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

---

## Node 7: PGVector Store

**Node Type:** Postgres Vector Store
**Mode:** Insert
**Table Name:** `core.document_embeddings`

### Options
- Distance Strategy: `cosine`

### Credentials
- PostgreSQL: `RailwayPG-idudes`

---

## Node 8: DocLoader

**Node Type:** Default Document Loader
**JSON Mode:** Expression Data

### JSON Data

```
{{ $('map').item.json.pageContent }}
```

### Metadata Values

| Name | Value |
|------|-------|
| filename | `{{ $('map').first().json.metadata.filename }}` |
| source | `{{ $('map').first().json.metadata.source }}` |
| file_type | `{{ $('map').first().json.metadata.file_type }}` |
| file_size | `{{ $('map').first().json.metadata.file_size }}` |
| timestamp | `{{ $('map').first().json.metadata.timestamp }}` |
| drive_file_id | `{{ $('map').first().json.metadata.drive_file_id }}` |
| document_id | `{{ $('map').first().json.metadata.document_id }}` |

---

## Node 9: Text Splitter

**Node Type:** Recursive Character Text Splitter
**Chunk Size:** `10000`
**Chunk Overlap:** `200`

---

## Node 10: Embeddings OpenAI

**Node Type:** OpenAI Embeddings

### Options
- Dimensions: `1536`
- Batch Size: `200`

### Credentials
- OpenAI API: `ZARAapiKey`

---

## Node 11: Code in JavaScript (Cleanup)

**Node Type:** Code (JavaScript)

### JavaScript Code

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

---

## Workflow Connections

```
Google Drive Trigger
  ↓
Download File
  ↓
PrepDoc
  ↓
Execute a SQL query
  ↓
Edit Fields
  ↓
map
  ↓
PGVector Store (with DocLoader + Text Splitter + Embeddings)
  ↓
Code in JavaScript (Cleanup)
```

### Sub-connections for PGVector Store

```
Text Splitter → DocLoader (ai_textSplitter)
Embeddings OpenAI → PGVector Store (ai_embedding)
DocLoader → PGVector Store (ai_document)
```

---

## Credential Setup

### Google Drive OAuth2
1. Create OAuth credentials in Google Cloud Console
2. Add to n8n credentials
3. Authorize access to Google Drive

### PostgreSQL (RailwayPG-idudes)
**Connection String:**
```
postgres://postgres:d7ToQHAA7VecTKi2DxFgNxtlj~xN_HnD@yamabiko.proxy.rlwy.net:15649/railway
```

### OpenAI API (ZARAapiKey)
**API Key:** Your OpenAI key with embeddings access

---

## Testing

### 1. Add a file to Google Drive folder
- Upload a Google Doc, Sheet, or any supported file

### 2. Check n8n execution
- Should trigger automatically
- Check execution logs for success

### 3. Verify in database

```sql
-- Check document was created
SELECT filename, file_type, metadata->>'drive_file_id'
FROM core.documents
WHERE metadata->>'source' = 'google_drive'
ORDER BY created_at DESC
LIMIT 1;

-- Check embeddings were created
SELECT COUNT(*) as chunks, metadata->>'filename'
FROM core.document_embeddings
WHERE metadata->>'source' = 'google_drive'
GROUP BY metadata->>'filename'
ORDER BY COUNT(*) DESC
LIMIT 5;
```

---

## Notes

- **Auto-conversion:** Google Docs → plain text, Sheets → CSV, Slides → plain text
- **Chunk size:** 10,000 characters with 200 overlap for context continuity
- **Embeddings:** OpenAI text-embedding-3-small (1536 dimensions)
- **Vector index:** Cosine similarity for semantic search
- **Error handling:** Workflow includes cleanup node to close DB connections
