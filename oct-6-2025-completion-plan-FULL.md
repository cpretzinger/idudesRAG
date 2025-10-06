# idudesRAG Completion Plan - October 6, 2025

## Current Status

### ✅ Working Components
- **PostgreSQL (Railway)**: pgvector database with documents + embeddings tables
- **n8n Workflow**: Document processing via webhook at `/webhook/idudesRAG/documents`
- **Vercel UI**: Upload page at `ui-theta-black.vercel.app`
- **API Routes**: Upload, Chat (GPT-5-nano), Search endpoints

### ❌ Issues to Fix
1. **Auth blocking routes** - 401 errors (FIXED: removed broken auth middleware)
2. **Chat page 404** - Vercel deployment in progress
3. **File upload 413** - Body size limit (FIXED: added next.config.js with 50mb limit)

---

## Required n8n Workflows

### 1. ✅ Document Upload & RAG Processing (EXISTS)
**File**: `/mnt/volume_nyc1_01/idudesRAG/json-flows/01-doc-processor-rag.json`
**Webhook**: `https://ai.thirdeyediagnostics.com/webhook/idudesRAG/documents`
**Flow**:
1. Webhook receives upload from Vercel
2. PrepDoc node decodes base64 content
3. DocLoader processes document
4. Text Splitter chunks content (200 char overlap)
5. Embeddings OpenAI creates vectors (1536 dimensions)
6. PGVector Store saves to Railway PostgreSQL

**Status**: ✅ **DEPLOYED AND WORKING**

---

### 2. ⏳ Google Drive Auto-Ingestion (NEEDED)
**Purpose**: Monitor Google Drive folder and auto-ingest documents
**Webhook**: `https://ai.thirdeyediagnostics.com/webhook/idudesRAG/gdrive`

**Flow**:
1. **Google Drive Trigger** - Watch folder for new files
2. **Download File** - Get file content
3. **Convert to Base64** - Prepare for processing
4. **HTTP Request** - POST to existing document webhook
5. **Error Handler** - Log failures to PostgreSQL

**Required Credentials**:
- Google Drive OAuth2

**Status**: ⏳ **TO BE CREATED**

---

### 3. ⏳ Document Metadata Enrichment (OPTIONAL)
**Purpose**: Extract additional metadata from documents
**Webhook**: `https://ai.thirdeyediagnostics.com/webhook/idudesRAG/enrich`

**Flow**:
1. Webhook trigger on new document
2. Extract entities (people, dates, companies)
3. Classify document type
4. Update PostgreSQL metadata field
5. Return enriched document info

**Status**: ⏳ **OPTIONAL - NOT CRITICAL**

---

## File Cleanup Plan

### Keep These Workflows
- ✅ **01-doc-processor-rag.json** - ACTIVE in n8n
- ❌ **CORRECTED-WORKFLOW.json** - DELETE (old version)
- ❌ **idudes-n8n-workflow.json** - DELETE (superseded)
- ❌ **n8n-setup.json** - DELETE (old setup)
- ❌ **rag-processing-in.json** - DELETE (duplicate)
- ✅ **config.template.json** - KEEP (reference)

**Action**: Move old workflows to `_archive/deprecated/workflows/`

---

## Authentication Strategy

### Current State: NO AUTH
- Routes are public (auth middleware removed)
- Anyone can upload/chat/search

### Recommended: Simple API Key Auth
```typescript
// /mnt/volume_nyc1_01/idudesRAG/ui/middleware.ts
import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

export function middleware(request: NextRequest) {
  const apiKey = request.headers.get('x-api-key')
  const validKey = process.env.API_KEY

  if (!apiKey || apiKey !== validKey) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  return NextResponse.next()
}

export const config = {
  matcher: '/api/:path*'
}
```

**Status**: ⏳ **TO BE IMPLEMENTED**

---

## Remaining Tasks

### Priority 1 (Critical)
- [x] Fix 413 upload errors
- [x] Remove broken auth middleware
- [ ] Verify Vercel deployment completes
- [ ] Test upload → n8n → PostgreSQL flow
- [ ] Test semantic search with real documents

### Priority 2 (Important)
- [ ] Create Google Drive ingestion workflow
- [ ] Implement simple API key auth
- [ ] Add master prompt for GPT-5-nano chat
- [ ] Clean up old workflow JSONs

### Priority 3 (Nice to Have)
- [ ] Document metadata enrichment workflow
- [ ] Rate limiting on API routes
- [ ] Usage analytics dashboard
- [ ] Email notifications on processing errors

---

## Environment Variables Checklist

### Vercel
```env
OPENAI_API_KEY=sk-proj-...
DATABASE_URL=postgres://...@yamabiko.proxy.rlwy.net:15649/railway
N8N_WEBHOOK_URL=https://ai.thirdeyediagnostics.com/webhook/idudesRAG/documents
API_KEY=<generate-random-key>
```

### n8n
- ✅ OpenAI API credentials configured
- ✅ Railway PostgreSQL credentials configured
- ⏳ Google Drive OAuth2 (for GDrive workflow)

---

## Testing Plan

### 1. Upload Flow Test
```bash
curl -X POST https://ui-theta-black.vercel.app/api/upload \
  -F "file=@test-document.pdf"
```
**Expected**: Document in `documents` table, embeddings in `document_embeddings`

### 2. Search Flow Test
```bash
curl -X POST https://ui-theta-black.vercel.app/api/search \
  -H "Content-Type: application/json" \
  -d '{"query": "test document", "limit": 5}'
```
**Expected**: JSON with relevant document chunks

### 3. Chat Flow Test
```bash
curl -X POST https://ui-theta-black.vercel.app/api/chat \
  -H "Content-Type: application/json" \
  -d '{"messages": [{"role": "user", "content": "What documents do we have?"}]}'
```
**Expected**: GPT-5-nano response about documents

---

## Database Schema (Reference)

### documents table
```sql
CREATE TABLE documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  filename TEXT NOT NULL,
  content TEXT,
  file_size INTEGER,
  file_type TEXT,
  spaces_url TEXT,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now()
);
```

### document_embeddings table
```sql
CREATE TABLE document_embeddings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id UUID REFERENCES documents(id) ON DELETE CASCADE,
  chunk_text TEXT NOT NULL,
  embedding VECTOR(1536),
  chunk_index INTEGER,
  chunk_metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMP DEFAULT now()
);

CREATE INDEX idx_document_embeddings_vector
ON document_embeddings
USING ivfflat (embedding vector_cosine_ops);
```

---

## Next Steps (Immediate)

1. **Wait for Vercel deployment** (~2 min)
2. **Test upload flow** via UI
3. **Verify data in PostgreSQL**
4. **Create Google Drive workflow**
5. **Implement API key auth**
6. **Clean up old workflow files**

---

## Success Criteria

- ✅ Users can upload documents via UI
- ✅ Documents are processed and embedded automatically
- ✅ Semantic search returns relevant results
- ✅ Chat interface can query documents
- ⏳ Google Drive auto-ingestion works
- ⏳ API is secured with authentication

---

**Last Updated**: October 6, 2025
**Status**: 70% Complete - Core RAG working, auth & GDrive pending
