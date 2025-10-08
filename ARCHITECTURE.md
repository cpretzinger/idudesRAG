# idudesRAG - System Architecture

## 🏗️ Simple & Clean Architecture

```
┌─────────────────────────────────────────────────┐
│  ai.thirdeyediagnostics.com                     │
│  (Traefik Reverse Proxy)                        │
└─────────────────────────────────────────────────┘
                        │
        ┌───────────────┴───────────────┐
        │                               │
        ▼                               ▼
┌──────────────┐              ┌──────────────────┐
│   Next.js UI │              │   n8n Workflows  │
│              │              │                  │
│ /            │              │ /webhook/*       │
│ /chat        │──────────────▶                  │
│              │  Direct Call │ - documents      │
│              │              │ - chat-knowledge │
└──────────────┘              └──────────────────┘
                                        │
                        ┌───────────────┴────────────────┐
                        │                                │
                        ▼                                ▼
                ┌──────────────┐              ┌──────────────────┐
                │ PostgreSQL   │              │ OpenAI API       │
                │ (Railway)    │              │                  │
                │              │              │ - GPT-5-nano     │
                │ - documents  │              │ - Embeddings     │
                │ - embeddings │              └──────────────────┘
                └──────────────┘
```

## 🔄 Data Flow

### 1. Document Upload
```
User uploads file
  ↓
UI: POST /webhook/documents
  ↓
n8n: Decode → Store in PG → Vectorize → Store embeddings
  ↓
Return success to UI
```

### 2. Chat with RAG
```
User asks question
  ↓
UI: POST /webhook/chat-knowledge {"messages": [...]}
  ↓
n8n:
  - Generate embedding for query
  - Search PGVector for similar docs
  - Send to GPT-5-nano with context
  - Return response
  ↓
UI displays answer
```

### 3. Vector Search
```
User searches
  ↓
UI: POST /webhook/chat-knowledge {"query": "..."}
  ↓
n8n:
  - Generate embedding
  - Query PGVector
  - Return ranked results
  ↓
UI displays results
```

## 🎯 Key Design Principles

### 1. **No Unnecessary Layers**
- UI calls n8n webhooks directly (same domain)
- No `/api/*` proxy routes
- No environment variables needed

### 2. **n8n as Single Backend**
- All database access through n8n
- All AI requests through n8n
- UI is pure frontend (no backend logic)

### 3. **Security via Traefik**
- All services behind reverse proxy
- SSL/TLS termination at Traefik
- Internal network for service-to-service

## 📦 Components

### Frontend (Next.js)
- **Purpose:** User interface only
- **Routes:** `/`, `/chat`
- **Calls:** n8n webhooks
- **No access to:** PostgreSQL, Redis, OpenAI

### Backend (n8n)
- **Purpose:** All business logic
- **Webhooks:** `/webhook/documents`, `/webhook/chat-knowledge`
- **Connects to:** PostgreSQL, OpenAI
- **Handles:** File processing, vectorization, AI, search

### Database (PostgreSQL on Railway)
- **Tables:**
  - `core.documents` - Uploaded files
  - `core.document_embeddings` - Vector embeddings
  - `core.enrichment_logs` - Metadata enrichment
- **Extension:** pgvector for similarity search

### AI (OpenAI)
- **Models:**
  - GPT-5-nano (chat, cost-optimized)
  - text-embedding-3-small (vectors)
- **Usage:** All via n8n (cached)

## 🔒 Security Model

### Network Isolation
```
Internet → Traefik → UI (public)
                  → n8n (public webhooks only)

n8n → PostgreSQL (Railway - internal)
    → OpenAI API (HTTPS)
```

### Authentication
- n8n webhooks: Can add HMAC signature validation
- PostgreSQL: Credential-based (in n8n only)
- OpenAI: API key (in n8n only)

### Data Flow
- User never sees database credentials
- User never sees OpenAI keys
- All secrets stored in n8n

## 💰 Cost Optimization

### GPT-5-nano Pricing
- Input: $0.050 / 1M tokens
- Cached: $0.005 / 1M tokens (90% off!)
- Output: $0.400 / 1M tokens

### Estimated Costs
- **100 chats/day:** ~$0.50/month
- **1000 documents/month:** ~$0.10/month
- **Total for small team:** <$1/month

### Why So Cheap?
1. GPT-5-nano (vs GPT-4: 20x cheaper)
2. Prompt caching (90% savings)
3. Efficient embeddings (batch processing)

## 📊 Scalability

### Current Capacity
- **Documents:** Unlimited (PostgreSQL scales)
- **Embeddings:** Millions (pgvector optimized)
- **Chat:** Concurrent users limited by n8n workers

### Scale-Up Path
1. **More docs:** Increase Railway PostgreSQL plan
2. **More users:** Scale n8n horizontally
3. **Faster search:** Add more vector indexes

## 🛠️ Technology Choices

### Why n8n?
- Visual workflow editor
- No-code AI pipelines
- Built-in LangChain support
- Easy to modify/debug

### Why pgvector?
- Native PostgreSQL extension
- No separate vector DB to manage
- Hybrid search (vector + SQL)
- Mature and stable

### Why GPT-5-nano?
- 20x cheaper than GPT-4
- Fast response times
- Sufficient for classification/search
- Prompt caching support

### Why Next.js?
- Modern React framework
- Server + client components
- Easy deployment (Vercel/Docker)
- Great DX

## 🔄 Deployment Flow

```
1. Build UI (Next.js)
   cd ui && pnpm build

2. Deploy to Docker/Vercel
   (Traefik routes ai.thirdeyediagnostics.com → UI)

3. Import n8n workflows
   (Traefik routes ai.thirdeyediagnostics.com/webhook → n8n)

4. Done!
   (No environment variables, no config files)
```

## 🎉 Benefits of This Architecture

✅ **Simple** - No unnecessary proxy layers
✅ **Secure** - Credentials only in n8n
✅ **Cheap** - GPT-5-nano + caching
✅ **Fast** - Direct webhook calls
✅ **Maintainable** - Clear separation of concerns
✅ **Scalable** - Each component scales independently

---

**Bottom line:** UI shows data, n8n does everything else. Clean and simple! 🚀
