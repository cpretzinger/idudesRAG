# Workflow Table Reference Updates - Oct 13, 2025

## DEPRECATED TABLES (DO NOT USE)
- `core.documents` - SUNSET
- `core.document_embeddings` - SUNSET

## CURRENT ACTIVE TABLES
- `core.embeddings` - Vector embeddings storage (1536 dimensions)
- `core.file_status` - Document metadata and processing status

---

## NODES REQUIRING UPDATES

###  COMPLETED UPDATES

#### 1. **Workflow:** `12-Chat-and-Search-Embeddings.json`
   - **Node Name:** `Postgres PGVector Store1`
   - **Parameter:** `tableName`
   - **Change:** `core.document_embeddings` � `core.embeddings`
   - **Status:**  Fixed in JSON (line 32)
   - **Action Required:** Re-import workflow in n8n UI to activate

#### 2. **Config File:** `config.template.json`
   - **Property:** `infrastructure.database.vectorTable`
   - **Change:** `document_embeddings` � `embeddings`
   - **Status:**  Fixed in JSON (line 16)

---

## UI DROP-IN REPLACEMENT INSTRUCTIONS

### For Workflow: 12-Chat-and-Search-Embeddings

**Steps to Apply Fix in n8n UI:**

1. Open n8n at: https://ai.thirdeyediagnostics.com/
2. Navigate to workflow: **"Chat and Search Embeddings"**
3. Click on node: **"Postgres PGVector Store1"**
4. In the parameters panel, locate field: **"Table Name"**
5. Change value:
   - FROM: `core.document_embeddings`
   - TO: `core.embeddings`
6. Click **Save** button
7. Activate the workflow

**Alternative: Re-import entire workflow:**
1. Open workflow in n8n
2. Click "..." menu � "Import from File"
3. Upload: `/mnt/volume_nyc1_01/idudesRAG/json-flows/12-Chat-and-Search-Embeddings.json`
4. Confirm import
5. Save and activate

---

## VERIFICATION CHECKLIST

- [x] Search all active workflows for deprecated table names
- [x] Fix `12-Chat-and-Search-Embeddings.json` table reference
- [x] Fix `config.template.json` vectorTable property
- [ ] Re-import workflow in n8n UI
- [ ] Test semantic search endpoint: `/webhook/chat-knowledge`
- [ ] Verify embeddings are retrieved correctly

---

## TEST COMMAND

```bash
# Test semantic search after re-importing workflow
curl -X POST https://ai.thirdeyediagnostics.com/webhook/chat-knowledge \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{"role": "user", "content": "What are the 3 pillars of agent retention?"}],
    "model": "gpt-5-nano",
    "session_id": "test-123"
  }'
```

**Expected Response:**
```json
{
  "success": true,
  "message": "[Insurance Dudes response about genuine care, real training, and clear growth path]",
  "model": "gpt-5-nano",
  "mode": "chat",
  "timestamp": "2025-10-13T..."
}
```

---

## DATABASE SCHEMA REFERENCE

### Current Active Schema

```sql
-- Embeddings table (ACTIVE)
CREATE TABLE core.embeddings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  file_id TEXT NOT NULL REFERENCES core.file_status(id),
  chunk_index INTEGER NOT NULL,
  text TEXT NOT NULL,
  embedding VECTOR(1536) NOT NULL,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(file_id, chunk_index)
);

-- File status table (ACTIVE)
CREATE TABLE core.file_status (
  id TEXT PRIMARY KEY,
  filename TEXT NOT NULL,
  status TEXT CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
  chunks_count INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

---

## NOTES

- All deprecated table references exist only in `_deprecated/` folder (intentionally preserved for historical reference)
- No active workflows reference `core.documents` or `core.document_embeddings` except the fixed ones above
- The workflow was failing because it couldn't find `core.document_embeddings` table
- Vector dimensions are 1536 (OpenAI text-embedding-3-small model)

---

**Last Updated:** 2025-10-13 21:30 MST
**Updated By:** Claude (Automated fix)







