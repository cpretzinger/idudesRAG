# 🎯 idudesRAG Completion Plan - ADHD-Friendly Task Breakdown

**Project Status**: 70% Complete | Core RAG Working ✅  
**Estimated Total Time**: 3-4 hours  
**Last Updated**: October 6, 2025

---

## 📋 MASTER CHECKLIST (Quick Reference)

### 🔥 Priority 1: Critical Validation (30 min)
- [ ] 1.1 Verify Vercel deployment status (5 min)
- [ ] 1.2 Test document upload flow (10 min)
- [ ] 1.3 Test semantic search (10 min)
- [ ] 1.4 Verify n8n webhook connectivity (5 min)

### 🛡️ Priority 2: Security & Automation (90 min)
- [ ] 2.0 Confirm you are using n8n auth flows
- [ ] 2.1 Add API key middleware (15 min)
- [ ] 2.2 Create Google Drive n8n workflow (30 min)
- [ ] 2.3 Add master chat prompt (15 min)
- [ ] 2.4 Implement rate limiting (15 min)
- [ ] 2.5 Add error notifications (15 min)

### 🧹 Priority 3: Cleanup & Polish (60 min)
- [ ] 3.1 Archive old workflow JSONs (10 min)
- [ ] 3.2 Create usage analytics dashboard (30 min)
- [ ] 3.3 Add health check endpoint (10 min)
- [ ] 3.4 Update README documentation (10 min)

### 🚀 Priority 4: Optional Enhancements (60 min)
- [ ] 4.1 Add document processing queue (20 min)
- [ ] 4.2 Implement batch upload (20 min)
- [ ] 4.3 Add conversation history (20 min)

---

## 🔥 PRIORITY 1: CRITICAL VALIDATION (30 minutes total)

**Why This Matters**: Need to verify all core systems are working before building new features. This prevents wasting time on broken foundations.

---

### Task 1.1: Verify Vercel Deployment ⚡ Quick Win

**Time**: 5 min  
**Mode**: Ask  
**Files**: None (checking deployment)  
**Dependencies**: None

**Actions**:
- [ ] Visit https://ui-theta-black.vercel.app
- [ ] Verify homepage loads without errors
- [ ] Check Vercel dashboard for latest deployment timestamp
- [ ] Confirm environment variables are set

**Success Criteria**: 
- Homepage displays upload interface
- No 404 or 500 errors
- Vercel shows "Ready" status

**Troubleshooting**:
- If 404: Check vercel.json routes configuration
- If env errors: Review documentation/VERCEL-ENV-SETUP.md

---

### Task 1.2: Test Document Upload Flow

**Time**: 10 min  
**Mode**: Ask  
**Files**: `ui/app/api/upload/route.ts`  
**Dependencies**: Task 1.1

**Actions**:
- [ ] Upload a test PDF (< 5MB) via UI
- [ ] Check browser console for errors
- [ ] Verify n8n webhook receives the document
- [ ] Check PostgreSQL for new entries in `documents` table
- [ ] Verify embeddings table has new vectors

**Success Criteria**:
- Upload completes without errors
- Document appears in PostgreSQL within 30 seconds
- Embeddings are generated (check `document_embeddings`)

**Test SQL Query**:
```sql
SELECT id, filename, created_at, file_size 
FROM documents 
ORDER BY created_at DESC 
LIMIT 5;
```

**Files to Check**:
- `ui/app/api/upload/route.ts` - Upload handler
- `json-flows/01-doc-processor-rag.json` - n8n workflow

---

### Task 1.3: Test Semantic Search

**Time**: 10 min  
**Mode**: Ask  
**Files**: `ui/app/api/search/route.ts`, `queries/optimized-search-query.sql`  
**Dependencies**: Task 1.2

**Actions**:
- [ ] Use the UI search to query uploaded document
- [ ] Try query: "What is this document about?"
- [ ] Verify results return within 2 seconds
- [ ] Check relevance scores (should be > 0.5 for good matches)
- [ ] Test edge case: empty query, very long query

**Success Criteria**:
- Search returns relevant chunks
- Response time < 2 seconds
- No errors in console or logs

**Test SQL (Direct)**:
```sql
-- Test vector search manually
SELECT chunk_text, 
       1 - (embedding <=> '[your_vector_here]'::vector) as similarity
FROM document_embeddings
ORDER BY embedding <=> '[your_vector_here]'::vector
LIMIT 5;
```

---

### Task 1.4: Verify n8n Webhook Connectivity ⚡ Quick Win

**Time**: 5 min  
**Mode**: Ask  
**Files**: None  
**Dependencies**: None

**Actions**:
- [ ] Check n8n is accessible at https://ai.thirdeyediagnostics.com
- [ ] Verify webhook URLs in `.env` match n8n endpoints
- [ ] Test webhook with curl command
- [ ] Check n8n execution logs for recent activity

**Success Criteria**:
- n8n responds to webhook test
- Recent executions show in n8n logs
- No authentication errors

**Test Curl**:
```bash
curl -X POST https://ai.thirdeyediagnostics.com/webhook/idudesRAG/documents \
  -H "Content-Type: application/json" \
  -d '{"test": true}'
```

---

## 🛡️ PRIORITY 2: SECURITY & AUTOMATION (90 minutes total)

**Why This Matters**: Protects your API from abuse and automates document ingestion from Google Drive.

---

### Task 2.1: Add API Key Middleware

**Time**: 15 min  
**Mode**: Code  
**Files**: `ui/middleware.ts` (create new)  
**Dependencies**: None

**Actions**:
- [ ] Create `ui/middleware.ts`
- [ ] Add API key validation for `/api/*` routes
- [ ] Exclude `/api/auth/*` from key requirement
- [ ] Add `x-api-key` header check
- [ ] Return 401 if key missing or invalid

**Success Criteria**:
- API routes require valid key
- Auth routes remain public
- Clear error messages for invalid keys

**Code Template**:
```typescript
// ui/middleware.ts
import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

export function middleware(request: NextRequest) {
  // Protect /api/* except /api/auth/*
  if (request.nextUrl.pathname.startsWith('/api/') && 
      !request.nextUrl.pathname.startsWith('/api/auth/')) {
    
    const apiKey = request.headers.get('x-api-key');
    const validKey = process.env.API_KEY;
    
    if (!apiKey || apiKey !== validKey) {
      return NextResponse.json(
        { error: 'Unauthorized - Invalid API Key' },
        { status: 401 }
      );
    }
  }
  
  return NextResponse.next();
}

export const config = {
  matcher: '/api/:path*',
};
```

**Environment Variable**:
Add to `.env`: `API_KEY=your_secret_key_here`

---

### Task 2.2: Create Google Drive Ingestion Workflow

**Time**: 30 min  
**Mode**: Code  
**Files**: `json-flows/google-drive-ingestion.json` (create new)  
**Dependencies**: None

**Actions**:
- [ ] Open n8n workflow editor
- [ ] Create new workflow: "Google Drive Auto-Ingestion"
- [ ] Add Google Drive Trigger (watches specific folder)
- [ ] Add HTTP Request node (calls /api/upload)
- [ ] Add Error Handler node (sends notification on failure)
- [ ] Configure 5-minute polling interval
- [ ] Export to `json-flows/google-drive-ingestion.json`

**Success Criteria**:
- Workflow triggers when new file added to Drive folder
- File is downloaded and sent to upload API
- Errors are caught and logged

**Workflow Structure**:
```
Google Drive Trigger (Poll every 5 min)
  ↓
Download File
  ↓
HTTP Request → POST /webhook/idudesRAG/documents
  ↓
If Error → Send Email Notification
```

**n8n Nodes Needed**:
1. Google Drive Trigger (Watch Folder)
2. HTTP Request (File Download)
3. Code Node (Convert to Base64)
4. HTTP Request (Upload to webhook)
5. IF (Error Check)
6. Email (Send notification)

**Webhook URL**: `https://ai.thirdeyediagnostics.com/webhook/idudesRAG/gdrive`

---

### Task 2.3: Add Master Chat Prompt ⚡ Quick Win

**Time**: 15 min  
**Mode**: Code  
**Files**: `ui/app/api/chat/route.ts`  
**Dependencies**: None

**Actions**:
- [ ] Open `ui/app/api/chat/route.ts`
- [ ] Add system prompt before GPT-5-nano call
- [ ] Include document context injection
- [ ] Add response formatting instructions
- [ ] Test with sample query

**Success Criteria**:
- Chat responses include document context
- Answers are formatted consistently
- Model follows personality guidelines

**System Prompt Template**:
```typescript
const SYSTEM_PROMPT = `You are a helpful AI assistant with access to a document knowledge base.

Your role:
- Answer questions using ONLY information from the provided documents
- Cite specific document names when referencing information
- If information is not in documents, clearly state: "I don't have information about that in the knowledge base."
- Be concise but thorough
- Use bullet points for lists

User's query: {query}

Relevant document chunks:
{context}

Provide a clear, accurate answer based on the above context.`;
```

**File Location**: `ui/app/api/chat/route.ts` (modify existing)

---

### Task 2.4: Implement Rate Limiting

**Time**: 15 min  
**Mode**: Code  
**Files**: `ui/lib/rate-limiter.ts` (create new), `ui/middleware.ts` (update)  
**Dependencies**: Task 2.1

**Actions**:
- [ ] Create `ui/lib/rate-limiter.ts`
- [ ] Use in-memory Map for rate tracking
- [ ] Set limit: 100 requests/hour per IP
- [ ] Add rate limit headers to responses
- [ ] Update middleware to call rate limiter

**Success Criteria**:
- Rate limit enforced on all API routes
- Headers show remaining requests
- 429 error returned when limit exceeded

**Code Template**:
```typescript
// ui/lib/rate-limiter.ts
const rateLimitMap = new Map<string, { count: number; resetTime: number }>();

export function checkRateLimit(ip: string): { 
  allowed: boolean; 
  remaining: number; 
  resetTime: number 
} {
  const now = Date.now();
  const limit = rateLimitMap.get(ip);
  
  if (!limit || now > limit.resetTime) {
    rateLimitMap.set(ip, { count: 1, resetTime: now + 3600000 }); // 1 hour
    return { allowed: true, remaining: 99, resetTime: now + 3600000 };
  }
  
  if (limit.count >= 100) {
    return { allowed: false, remaining: 0, resetTime: limit.resetTime };
  }
  
  limit.count++;
  return { allowed: true, remaining: 100 - limit.count, resetTime: limit.resetTime };
}
```

---

### Task 2.5: Add Error Notifications

**Time**: 15 min  
**Mode**: Code  
**Files**: `ui/lib/notifications.ts` (create new)  
**Dependencies**: None

**Actions**:
- [ ] Create `ui/lib/notifications.ts`
- [ ] Add function to send email on processing errors
- [ ] Use Resend or SendGrid API
- [ ] Add error logging to upload/search routes
- [ ] Test with intentional error

**Success Criteria**:
- Email sent when upload fails
- Email sent when search times out
- Errors logged to console

**Code Template**:
```typescript
// ui/lib/notifications.ts
export async function notifyError(error: Error, context: string): Promise<void> {
  console.error(`[${context}]`, error);
  
  // Send email notification (if RESEND_API_KEY is set)
  if (!process.env.RESEND_API_KEY) return;
  
  try {
    await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${process.env.RESEND_API_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        from: 'errors@yourdomain.com',
        to: 'your@email.com',
        subject: `idudesRAG Error: ${context}`,
        text: `Error: ${error.message}\n\nStack: ${error.stack}`
      })
    });
  } catch (e) {
    console.error('Failed to send error notification:', e);
  }
}
```

---

## 🧹 PRIORITY 3: CLEANUP & POLISH (60 minutes total)

**Why This Matters**: Improves maintainability and provides visibility into system usage.

---

### Task 3.1: Archive Old Workflow JSONs ⚡ Quick Win

**Time**: 10 min  
**Mode**: Code  
**Files**: `json-flows/_archive/` (create new directory)  
**Dependencies**: None

**Actions**:
- [ ] Create `json-flows/_archive/` directory
- [ ] Move CORRECTED-WORKFLOW.json to archive
- [ ] Move idudes-n8n-workflow.json to archive
- [ ] Move rag-processing-in.json to archive
- [ ] Keep only 01-doc-processor-rag.json and config.template.json
- [ ] Add `.gitkeep` to archive folder

**Success Criteria**:
- Only active workflows in main folder
- Old workflows preserved in archive
- README updated with archive note

**Files to Archive** (per completion plan):
- `CORRECTED-WORKFLOW.json` - old version
- `idudes-n8n-workflow.json` - superseded
- `rag-processing-in.json` - duplicate

**Command**:
```bash
mkdir -p json-flows/_archive
mv json-flows/CORRECTED-WORKFLOW.json json-flows/_archive/
mv json-flows/idudes-n8n-workflow.json json-flows/_archive/
mv json-flows/rag-processing-in.json json-flows/_archive/
```

---

### Task 3.2: Create Usage Analytics Dashboard

**Time**: 30 min  
**Mode**: Code  
**Files**: `ui/app/api/analytics/route.ts` (create new), `ui/app/analytics/page.tsx` (create new)  
**Dependencies**: None

**Actions**:
- [ ] Create analytics API endpoint
- [ ] Query PostgreSQL for usage stats
- [ ] Create simple dashboard page
- [ ] Show: total documents, searches today, avg embeddings
- [ ] Add chart for documents over time (optional)

**Success Criteria**:
- Dashboard shows real-time stats
- Queries execute in < 500ms
- UI is mobile-responsive

**Analytics SQL**:
```sql
-- Total documents
SELECT COUNT(*) as total FROM documents;

-- Documents today
SELECT COUNT(*) FROM documents 
WHERE created_at > NOW() - INTERVAL '24 hours';

-- Avg embeddings per document
SELECT AVG(chunk_count) as avg_chunks
FROM (
  SELECT document_id, COUNT(*) as chunk_count
  FROM document_embeddings
  GROUP BY document_id
) sub;
```

**Dashboard Route**: `/analytics`

---

### Task 3.3: Add Health Check Endpoint ⚡ Quick Win

**Time**: 10 min  
**Mode**: Code  
**Files**: `ui/app/api/health/route.ts` (create new)  
**Dependencies**: None

**Actions**:
- [ ] Create `/api/health` endpoint
- [ ] Check PostgreSQL connection
- [ ] Check n8n webhook availability
- [ ] Return status: healthy/degraded/down
- [ ] Add response time metrics

**Success Criteria**:
- Endpoint returns JSON status
- All dependencies checked
- Response time < 500ms

**Code Template**:
```typescript
// ui/app/api/health/route.ts
import { NextResponse } from 'next/server';

export async function GET() {
  const checks = {
    database: false,
    n8n: false,
    timestamp: new Date().toISOString()
  };
  
  try {
    // Check DB (use your actual DB client)
    const db = await fetch(process.env.DATABASE_URL!);
    checks.database = true;
    
    // Check n8n
    const n8n = await fetch(process.env.N8N_WEBHOOK_URL!);
    checks.n8n = n8n.ok;
  } catch (error) {
    console.error('Health check failed:', error);
  }
  
  const healthy = checks.database && checks.n8n;
  
  return NextResponse.json(checks, { 
    status: healthy ? 200 : 503 
  });
}
```

---

### Task 3.4: Update README Documentation

**Time**: 10 min  
**Mode**: Code  
**Files**: `README.md`  
**Dependencies**: All previous tasks

**Actions**:
- [ ] Update "Current Status" section to 100%
- [ ] Add new features to features list
- [ ] Document API key usage
- [ ] Add health check endpoint to docs
- [ ] Update deployment instructions

**Success Criteria**:
- README reflects all new features
- Setup instructions are clear
- API documentation is complete

**Sections to Update**:
1. Project Status → 100% Complete
2. Features → Add rate limiting, analytics, Google Drive
3. API Endpoints → Add /health, /analytics
4. Security → Document API key requirement
5. Testing → Update test commands

---

## 🚀 PRIORITY 4: OPTIONAL ENHANCEMENTS (60 minutes)

**Why This Matters**: Nice-to-have features that improve user experience but aren't critical.

---

### Task 4.1: Add Document Processing Queue

**Time**: 20 min  
**Mode**: Code  
**Files**: `ui/app/api/upload/route.ts`  
**Dependencies**: None

**Actions**:
- [ ] Implement simple in-memory queue
- [ ] Process documents sequentially
- [ ] Add status endpoint to check progress
- [ ] Return queue position to user
- [ ] Add timeout handling (5 min max)

**Success Criteria**:
- Multiple uploads don't overwhelm n8n
- Users can check processing status
- Queue clears automatically

**Code Snippet**:
```typescript
const uploadQueue: Array<{ id: string; filename: string; status: string }> = [];

async function processQueue() {
  while (uploadQueue.length > 0) {
    const item = uploadQueue[0];
    // Process item
    uploadQueue.shift();
  }
}
```

---

### Task 4.2: Implement Batch Upload

**Time**: 20 min  
**Mode**: Code  
**Files**: `ui/app/api/upload/batch/route.ts` (create new)  
**Dependencies**: Task 4.1

**Actions**:
- [ ] Create batch upload endpoint
- [ ] Accept ZIP files with multiple documents
- [ ] Extract and process each file
- [ ] Return status for each file
- [ ] Handle partial failures gracefully

**Success Criteria**:
- ZIP files accepted
- Each file processed individually
- Clear error messages for failures

---

### Task 4.3: Add Conversation History

**Time**: 20 min  
**Mode**: Code  
**Files**: `ui/app/api/chat/route.ts`, `migrations/chat-history-schema.sql` (create new)  
**Dependencies**: None

**Actions**:
- [ ] Create chat_history table in PostgreSQL
- [ ] Store user queries and responses
- [ ] Add session management
- [ ] Show previous conversations in UI
- [ ] Add "clear history" button

**Success Criteria**:
- Conversations persisted
- History visible in UI
- Privacy controls in place

**Schema**:
```sql
CREATE TABLE IF NOT EXISTS chat_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL,
  user_message TEXT NOT NULL,
  assistant_message TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_chat_session ON chat_history(session_id, created_at DESC);
```

---

## 🎯 COMPLETION CHECKLIST

When all tasks are complete:

- [ ] All Priority 1 tasks done (deployment verified)
- [ ] All Priority 2 tasks done (security implemented)
- [ ] All Priority 3 tasks done (cleanup complete)
- [ ] Optional tasks completed (if time permits)
- [ ] README updated with final status
- [ ] All tests passing
- [ ] Production deployment verified

---

## 📊 SUCCESS METRICS

**Performance Goals**:
- Search response time: < 2 seconds
- Upload processing: < 30 seconds for 5MB file
- API availability: > 99%

**Quality Goals**:
- No critical security vulnerabilities
- All API routes have error handling
- Documentation is complete

**User Experience Goals**:
- Clear error messages
- Responsive UI
- Minimal downtime

---

## 🆘 TROUBLESHOOTING GUIDE

### Common Issues

**Upload fails**:
1. Check n8n webhook is accessible
2. Verify PostgreSQL connection
3. Check file size limits (max 50MB per next.config.js)

**Search returns no results**:
1. Verify embeddings were created
2. Check vector similarity threshold
3. Test with simpler query

**Rate limit errors**:
1. Check IP address detection
2. Verify Map is working
3. Adjust limits in `rate-limiter.ts`

**n8n webhook errors**:
1. Verify webhook URL in .env
2. Check n8n is running
3. Test with curl command

---

## 📝 NOTES FOR IMPLEMENTATION

- **Use GPT-5-nano** for all AI operations (fast, efficient)
- **Test locally first** before deploying to Vercel
- **Commit after each completed task** for easy rollback
- **Check Vercel logs** if deployment fails
- **Monitor PostgreSQL storage** (vector embeddings use space)
- **Database**: Railway PostgreSQL at yamabiko.proxy.rlwy.net:15649
- **n8n**: Running at ai.thirdeyediagnostics.com
- **Vercel**: ui-theta-black.vercel.app

---

## 🔗 KEY URLs & CREDENTIALS

**Vercel UI**: https://ui-theta-black.vercel.app  
**n8n Webhook**: https://ai.thirdeyediagnostics.com/webhook/idudesRAG/documents  
**Database**: Railway PostgreSQL (see .env for connection string)

**Environment Variables Required**:
- `OPENAI_API_KEY` - For embeddings
- `DATABASE_URL` - PostgreSQL connection
- `N8N_WEBHOOK_URL` - Document processing endpoint
- `API_KEY` - For API authentication (after Task 2.1)

---

**Ready to start? Begin with Priority 1, Task 1.1** ⚡