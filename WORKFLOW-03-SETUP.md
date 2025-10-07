# Workflow 03 - Document Metadata Enrichment Setup

## SQL - Create enrichment_logs table

```sql
CREATE TABLE IF NOT EXISTS core.enrichment_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant TEXT NOT NULL DEFAULT 'idudes',
  document_id UUID NOT NULL REFERENCES core.documents(id) ON DELETE CASCADE,
  status TEXT NOT NULL CHECK (status IN ('success', 'error', 'pending')),
  metadata_extracted JSONB,
  error_message TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() AT TIME ZONE 'America/Phoenix'),

  -- Indexes for performance
  INDEX idx_enrichment_logs_tenant (tenant),
  INDEX idx_enrichment_logs_document_id (document_id),
  INDEX idx_enrichment_logs_status (status),
  INDEX idx_enrichment_logs_created_at (created_at DESC)
);

-- Grant permissions
GRANT ALL ON core.enrichment_logs TO postgres;
```

## n8n Configuration

### Credentials Needed

1. **PostgreSQL** (Railway)
   - Name: `RailwayPG-idudes` or `iDudes PGVector Railway`
   - Connection String: `postgres://postgres:5Prl6LQokZHCIo59EOr3Tys0esF7ubao@trolley.proxy.rlwy.net:35195/railway`

2. **OpenAI API**
   - Name: `OpenAI API - idudesRAG` or `ZARAapiKey`
   - API Key: Your OpenAI key with GPT-5 access

### Webhook Configuration

**Webhook URL:** `https://ai.thirdeyediagnostics.com/webhook/idudesRAG/enrich`

**Method:** POST

**Request Body:**
```json
{
  "document_id": "uuid-of-document-to-enrich"
}
```

**Example cURL:**
```bash
curl -X POST https://ai.thirdeyediagnostics.com/webhook/idudesRAG/enrich \
  -H "Content-Type: application/json" \
  -d '{"document_id": "20a92112-b9bc-4a55-8bd5-959f61b1b11d"}'
```

## Code Nodes

### 1. Prepare Enrichment (node c3c4d5e0)

```javascript
// Extract metadata from document content using GPT-5-nano
const content = $input.first().json.content;
const filename = $input.first().json.filename;

// Prepare enrichment request
const enrichmentPrompt = `Analyze this document and extract metadata. Return JSON only.

Document: ${filename}
Content: ${content.substring(0, 2000)}...

Extract:
1. document_type (email, contract, report, memo, policy, claim, etc.)
2. entities: {people: [], companies: [], dates: [], amounts: [], policies: []}
3. tags: [relevant keywords]
4. summary: brief description
5. priority: low|medium|high
6. confidence: 0-1 score

Return as clean JSON object only.`;

return [{
  json: {
    document_id: $input.first().json.id,
    filename: filename,
    content_preview: content.substring(0, 500),
    enrichment_prompt: enrichmentPrompt,
    tenant: 'idudes'
  }
}];
```

### 2. Process Metadata (node e5e6f7g0)

```javascript
// Process GPT response and prepare database update
const gptResponse = $input.first().json.choices[0].message.content;
const documentId = $('Prepare Enrichment').item.json.document_id;

try {
  // Parse GPT JSON response
  const extractedMetadata = JSON.parse(gptResponse);

  // Create enriched metadata object
  const enrichedMetadata = {
    ...extractedMetadata,
    enriched_at: new Date().toISOString(),
    enrichment_version: '1.0',
    tenant: 'idudes',
    model_used: 'gpt-5-nano'
  };

  return [{
    json: {
      document_id: documentId,
      enriched_metadata: enrichedMetadata,
      success: true
    }
  }];

} catch (error) {
  // Handle JSON parse errors
  return [{
    json: {
      document_id: documentId,
      enriched_metadata: {
        document_type: 'unknown',
        entities: {},
        tags: [],
        summary: 'Failed to extract metadata',
        priority: 'low',
        confidence: 0,
        error: error.message,
        raw_response: gptResponse,
        enriched_at: new Date().toISOString(),
        tenant: 'idudes'
      },
      success: false,
      error: error.message
    }
  }];
}
```

## GPT-5 Enrichment Node Configuration

**Node Settings:**
- **Resource:** Chat
- **Operation:** Create
- **Model:** `gpt-5-nano`
- **Temperature:** 0.1
- **Max Tokens:** 1000

**System Message:**
```
You are a document metadata extraction expert. Extract structured metadata from insurance and business documents. Return only valid JSON.
```

**User Message:**
```
={{ $json.enrichment_prompt }}
```

## SQL Queries

### Get Document (node b2b3c4d0)
```sql
SELECT id, filename, content, metadata
FROM documents
WHERE id = $1
```
**Parameters:** `={{ $json.body.document_id }}`

### Update Document (node f6f7g8h0)
```sql
UPDATE documents
SET metadata = metadata || $2::jsonb,
    updated_at = NOW()
WHERE id = $1
```
**Parameters:**
- `$1`: `={{ $json.document_id }}`
- `$2`: `={{ JSON.stringify($json.enriched_metadata) }}`

### Log Enrichment (node 18192021)
```sql
INSERT INTO enrichment_logs
  (tenant, document_id, status, metadata_extracted, error_message, created_at)
VALUES
  ($1, $2, $3, $4, $5, NOW())
```
**Parameters:**
- `$1`: `idudes`
- `$2`: `={{ $('Process Metadata').item.json.document_id }}`
- `$3`: `={{ $('Process Metadata').item.json.success ? 'success' : 'error' }}`
- `$4`: `={{ JSON.stringify($('Process Metadata').item.json.enriched_metadata) }}`
- `$5`: `={{ $('Process Metadata').item.json.error || null }}`

## Response Format

**Success Response:**
```json
{
  "success": true,
  "document_id": "20a92112-b9bc-4a55-8bd5-959f61b1b11d",
  "metadata": {
    "document_type": "policy",
    "entities": {
      "people": ["John Doe"],
      "companies": ["Acme Insurance"],
      "dates": ["2025-01-15"],
      "amounts": ["$50,000"],
      "policies": ["POL-12345"]
    },
    "tags": ["auto insurance", "claim", "liability"],
    "summary": "Auto insurance policy claim document",
    "priority": "high",
    "confidence": 0.95,
    "enriched_at": "2025-10-07T07:30:00.000Z",
    "enrichment_version": "1.0",
    "tenant": "idudes",
    "model_used": "gpt-5-nano"
  },
  "message": "Document metadata enriched successfully"
}
```

## Testing

1. Upload a document first using workflow 02
2. Get the document ID from the response
3. Call the enrichment endpoint:

```bash
DOCUMENT_ID="your-document-uuid-here"

curl -X POST https://ai.thirdeyediagnostics.com/webhook/idudesRAG/enrich \
  -H "Content-Type: application/json" \
  -d "{\"document_id\": \"$DOCUMENT_ID\"}"
```

## Monitoring

Check enrichment logs:
```sql
SELECT
  el.id,
  el.tenant,
  d.filename,
  el.status,
  el.metadata_extracted->>'document_type' as doc_type,
  el.error_message,
  el.created_at
FROM core.enrichment_logs el
JOIN core.documents d ON el.document_id = d.id
ORDER BY el.created_at DESC
LIMIT 20;
```
