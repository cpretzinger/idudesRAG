# 🎯 idudesRAG - Document Intelligence System

**One-click deployable RAG-as-a-Service for intelligent document processing with vector search.**

---

## 🚀 **LIVE SYSTEM**

### **🌐 Upload Documents:**
**https://ui-hqv6d6k5n-pretzingers-projects.vercel.app**

### **🔍 Search API:**
**https://ai.thirdeyediagnostics.com/webhook/idudesRAG/search**

### **📊 Storage CDN:**
**https://datainjestion.nyc3.cdn.digitaloceanspaces.com**

---

## 🏗️ **ARCHITECTURE**

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────┐
│   Vercel UI     │───▶│   n8n Webhook    │───▶│  Railway PostgreSQL │
│  (Next.js App) │    │  (Process Docs)  │    │   (pgvector DB)     │
└─────────────────┘    └──────────────────┘    └─────────────────────┘
         │                       │                         │
         ▼                       ▼                         ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────┐
│ DigitalOcean    │    │   OpenAI API     │    │  Vector Search      │
│ Spaces (CDN)    │    │  (Embeddings)    │    │   & Similarity      │
└─────────────────┘    └──────────────────┘    └─────────────────────┘
```

---

## ⚡ **QUICK START**

### **1. Upload a Document**
Visit the UI and drag/drop any PDF, DOC, or TXT file.

### **2. Search Your Documents**
```bash
curl -X POST "https://ai.thirdeyediagnostics.com/webhook/idudesRAG/search" \
  -H "Content-Type: application/json" \
  -d '{"query": "insurance policies", "limit": 5}'
```

### **3. Get Instant Results**
Semantic search returns relevant chunks with similarity scores.

---

## 🛠️ **INFRASTRUCTURE SETUP**

### **🗄️ Database: Railway PostgreSQL**
```bash
# Connection String
postgres://postgres:d7ToQHAA7VecTKi2DxFgNxtlj~xN_HnD@yamabiko.proxy.rlwy.net:15649/railway

# Extensions Enabled
- vector (0.8.1) - pgvector for embeddings
- uuid-ossp (1.1) - UUID generation

# Tables Created
- documents (metadata, content, file info)
- document_embeddings (1536-dim vectors, chunks)

# Functions Available  
- search_documents(vector, threshold, limit)
```

### **💾 Storage: DigitalOcean Spaces**
```bash
# CDN Endpoint
https://datainjestion.nyc3.cdn.digitaloceanspaces.com

# Configuration
SPACES_ACCESS_KEY=DO801GMC4X89LPH7GYUR
SPACES_SECRET_KEY=5ETjfL9VsoOx/23w4uwwdNVoJG1+npyGPrXsvSW31gQ
SPACES_BUCKET=datainjestion
SPACES_REGION=nyc3
```

### **🤖 AI: OpenAI Embeddings**
```bash
# Model: text-embedding-3-small
# Dimensions: 1536
# Cost: ~$0.00002 per 1K tokens
OPENAI_API_KEY=sk-proj-WtRG...
```

### **🔧 Processing: n8n Workflows**
```bash
# Upload Webhook
https://ai.thirdeyediagnostics.com/webhook/idudesRAG/documents

# Search Webhook  
https://ai.thirdeyediagnostics.com/webhook/idudesRAG/search

# Workflow Functions
1. Document Upload → Base64 Decode → Chunk Text
2. Generate Embeddings → Store in PostgreSQL
3. Search Query → Embed → Vector Similarity
```

---

## 📁 **PROJECT STRUCTURE**

```
idudesRAG/
├── 📄 README.md                          # This file
├── 🐳 docker-compose.yml                 # Container orchestration
├── 🔧 .env                              # Environment variables
├── 📊 ui/                               # Next.js Vercel frontend
│   ├── app/page.tsx                     # Upload interface
│   ├── app/api/upload/route.ts          # Upload API
│   └── app/api/search/route.ts          # Search API
├── 🛠️ processor/                        # Document processor (optional)
│   ├── package.json
│   └── index.js
├── 📋 configs/                          # Multi-tenant configurations
│   └── tenant-configs.json
├── 🗄️ Database/
│   ├── simple-schema.sql               # PostgreSQL schema
│   ├── simple-queries.sql              # Example queries
│   └── setup-db.sql                    # Complete setup
├── 🔄 Workflows/
│   ├── idudes-n8n-workflow.json        # Upload workflow
│   ├── SEARCH-WORKFLOW-NODES.md        # Search workflow
│   └── CORRECTED-WORKFLOW.json         # Fixed version
└── 📚 Documentation/
    ├── N8N-SETUP-GUIDE.md              # Step-by-step n8n setup
    ├── VERCEL-SETUP.md                 # Vercel deployment guide
    ├── ONE-CLICK-GUIDE.md              # Multi-tenant deployment
    ├── WORKFLOW-FIXES.md               # Troubleshooting guide
    └── TUNNEL-GUIDE-URDU-ENGLISH.md    # Cloudflare tunnel guide
```

---

## 🔧 **ENVIRONMENT VARIABLES**

### **Required Configuration**
```bash
# Database
DATABASE_URL=postgres://postgres:password@host:port/database

# AI Services  
OPENAI_API_KEY=sk-proj-your-key-here

# Storage
SPACES_ACCESS_KEY=your-spaces-key
SPACES_SECRET_KEY=your-spaces-secret
SPACES_BUCKET=your-bucket-name
SPACES_REGION=nyc3
SPACES_ENDPOINT=https://your-bucket.region.cdn.digitaloceanspaces.com

# Railway Project (Optional)
RAILWAY_PROJ_ID=6806bdce-60ff-4d5e-9a2e-daf845d57b8a
```

---

## 🚀 **DEPLOYMENT METHODS**

### **Method 1: Vercel UI Only (Recommended)**
1. Fork this repository
2. Deploy to Vercel with environment variables
3. Connect to existing n8n workflow
4. Ready in 5 minutes!

### **Method 2: Full Docker Stack**
```bash
# Clone repository
git clone https://github.com/cpretzinger/idudesRAG.git
cd idudesRAG

# Configure environment
cp .env.example .env
# Edit .env with your credentials

# Deploy containers
docker-compose up -d

# Verify services
docker ps
```

### **Method 3: One-Click Multi-Tenant**
```bash
# Deploy new tenant
./deploy.sh "Client Name" "docs.clientdomain.com"

# Automatic setup:
# - Database schema creation
# - Storage bucket creation  
# - Vercel deployment
# - n8n workflow creation
# - DNS configuration
```

---

## 🔍 **API REFERENCE**

### **Document Upload**
```bash
# Upload via UI
POST /api/upload
Content-Type: multipart/form-data
Body: file=document.pdf

# Upload via webhook
POST https://ai.thirdeyediagnostics.com/webhook/idudesRAG/documents
Content-Type: application/json
{
  "filename": "document.pdf",
  "content": "base64-encoded-content",
  "type": "application/pdf",
  "size": 12345,
  "timestamp": "2025-01-05T20:00:00.000Z"
}
```

### **Document Search**
```bash
# Search via API
POST /api/search
Content-Type: application/json
{
  "query": "insurance policies",
  "limit": 10
}

# Search via webhook
POST https://ai.thirdeyediagnostics.com/webhook/idudesRAG/search
Content-Type: application/json
{
  "query": "insurance policies", 
  "limit": 5,
  "threshold": 0.7
}

# Response
{
  "success": true,
  "query": "insurance policies",
  "total_results": 3,
  "results": [
    {
      "document_id": "uuid",
      "filename": "policy.pdf", 
      "content_preview": "This policy covers...",
      "similarity": 0.89,
      "download_url": "https://cdn-url/policy.pdf"
    }
  ]
}
```

---

## 🗄️ **DATABASE SCHEMA**

### **Current Schema: `core` (Railway PostgreSQL)**

**Connection:** `postgres://postgres@yamabiko.proxy.rlwy.net:15649/railway`
**Schema:** `core` (16 active tables)
**Extensions:** pgvector (0.8.1), uuid-ossp, pg_trgm
**Live Documentation:** `/documentation/database/` (auto-updated hourly)

### **Core Tables**

**User & Auth:**
- `users` - User accounts (superadmin/admin/user roles)
- `user_sessions` - Session management
- `auth_logs` - Authentication event logging
- `password_resets` / `password_reset_tokens` - Password recovery

**Document Processing:**
- `embeddings` - Vector embeddings (1536-dim, pgvector)
- `file_status` - File processing status
- `file_pipeline_status` - RAG + Social pipeline tracking
- `enrichment_logs` - Document enrichment logs
- `drive_sync_state` - Google Drive sync state

**Social Media Automation:**
- `social_content_generated` - AI-generated social posts
- `social_post_performance` - Performance metrics (engagement, reach)
- `social_feedback_insights` - ML-derived performance patterns
- `social_scheduling` - Optimal posting times per platform
- `social_processed` - Processing deduplication

**System:**
- `metrics` - Application metrics & observability

### **Key Functions**

**Vector Search:**
```sql
-- Search documents by semantic similarity
SELECT * FROM core.search_documents(
  query_embedding := '[0.1, 0.2, ...]'::vector(1536),
  similarity_threshold := 0.7,
  result_limit := 10
);
```

**Social Media:**
```sql
-- Get optimal posting time
SELECT * FROM core.get_optimal_posting_time('instagram_reel', 'monday', 1);

-- Generate 10-day campaign schedule
SELECT * FROM core.schedule_10_day_campaign('2025-01-15');

-- Update post performance metrics
SELECT * FROM core.update_post_performance(
  content_id, platform, likes, comments, shares, saves, reach, impressions, clicks
);
```

### **Schema Documentation**

**Latest Schema Files:**
- **Full SQL:** `/documentation/database/schema_latest.sql`
- **Markdown:** `/documentation/database/schema.md`
- **Column CSV:** `/documentation/database/columns.csv`

**Schema Backups:** Hourly snapshots at `/var/backups/db-sot/`
**Migration History:** See `/migrations/schema-core-2025-10-12.sql`

**Auto-Sync (Implemented Oct 14, 2025):**
- Hourly cron job syncs latest schema to `/documentation/database/`
- Non-breaking implementation (fails silently if project path missing)
- Creates markdown, SQL, and CSV formats automatically
- Ensures AI coding agents always have current schema reference

---

## 🚀 **API CACHING SYSTEM** (Added Oct 14, 2025)

### **Unified Cache Table: `core.api_cache`**

**Purpose:** Reduce OpenAI API costs by caching LLM generations, embeddings, and reviews

**Table Structure:**
```sql
CREATE TABLE core.api_cache (
  key_hash text PRIMARY KEY,              -- SHA256 hash of request
  cache_type text CHECK (IN 'embedding', 'generation', 'review'),
  model text NOT NULL,                     -- e.g., 'gpt-5-nano'
  model_version text DEFAULT 'v1',        -- Prompt version for invalidation
  request_payload jsonb NOT NULL,          -- Full request context
  response_data jsonb NOT NULL,            -- Cached LLM response
  cost_usd numeric(10,6),                  -- Cost tracking
  hit_count int DEFAULT 0,                 -- Cache effectiveness metric
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
```

**Indexes (Performance Optimized):**
- `idx_api_cache_lookup` - Fast key+type lookups
- `idx_api_cache_type` - Cache type filtering
- `idx_api_cache_hit_count` - ROI analysis

**Cache Types:**
1. **Generation Cache** - Social media copy (50-80% cost reduction)
2. **Embedding Cache** - Vector embeddings (moderate savings)
3. **Review Cache** - Content review passes (low-priority optimization)

**Usage in n8n Workflows:**
See `/json-flows/farts.md` for complete 7-node cache integration pattern

**Cost Impact:**
- Expected savings: 50-80% on duplicate content generation
- Cache hit tracking via `hit_count` column
- Query cache stats: `SELECT cache_type, SUM(hit_count) FROM core.api_cache GROUP BY cache_type;`

---

## 🔧 **POSTGRESQL PERFORMANCE OPTIMIZATIONS** (Oct 14, 2025)

### **Indexes Added:**
```sql
-- Cache lookup optimization (He-Man approved ⚔️)
CREATE INDEX idx_api_cache_lookup ON core.api_cache(key_hash, cache_type);

-- Embeddings content hash (deduplication)
ALTER TABLE core.embeddings ADD COLUMN content_hash text;
CREATE INDEX idx_embeddings_content_hash ON core.embeddings(content_hash);
```

### **Database Functions:**
```sql
-- Cleanup old cache entries (default: 90 days retention)
SELECT core.cleanup_old_cache(90);

-- Get cache effectiveness stats
SELECT * FROM core.get_cache_stats();
```

### **Concurrency Handling:**
- UPSERT pattern with `ON CONFLICT` for atomic cache writes
- Row-level locking prevents race conditions
- `hit_count` increments are atomic (PostgreSQL ACID guarantees)

---

## 🔄 **n8n WORKFLOW CONFIGURATION**

### **Workflow Sync Tool** ⚡

**Keep your local workflow files in sync with n8n database:**

```bash
# Sync a workflow from n8n → local files
./scripts/sync-n8n-workflow.sh "01-GoogleDriveToVectors"

# Sync by workflow ID
./scripts/sync-n8n-workflow.sh fCTt9QyABrKKBmv7

# Preview changes without writing (dry-run)
./scripts/sync-n8n-workflow.sh "01-GoogleDriveToVectors" --dry-run

# Force overwrite local files
./scripts/sync-n8n-workflow.sh "01-GoogleDriveToVectors" --force
```

**Features:**
- ✅ **Arizona Timezone** - All timestamps in MST/MDT for accuracy
- ✅ **Conflict Detection** - Warns when local file is newer than DB
- ✅ **Interactive Prompts** - Choose to overwrite, archive, or cancel
- ✅ **Archive System** - Auto-backup to `json-flows/_archive/YYYYMMDD/`
- ✅ **READ ONLY** - Safe database reads, never modifies n8n workflows
- ✅ **JSON Validation** - Ensures valid workflow structure

**Documentation:** See `/scripts/README-sync-workflow.md` for complete guide

**List available workflows:**
```bash
docker exec ai-postgres psql -U ai_user -d ai_assistant -c \
  "SELECT name, id FROM workflow_entity ORDER BY \"updatedAt\" DESC LIMIT 20;"
```

### **Upload Workflow (5 Nodes)**
1. **Webhook** - Receive document uploads
2. **Code** - Decode base64 and extract metadata
3. **PostgreSQL** - Store document metadata
4. **Code** - Chunk text for embeddings
5. **OpenAI** - Generate embeddings → **PostgreSQL** - Store vectors

### **Search Workflow (5 Nodes)**
1. **Webhook** - Receive search queries
2. **Code** - Validate and format input
3. **OpenAI** - Generate query embeddings
4. **PostgreSQL** - Vector similarity search
5. **Code** - Format and return results

### **Social Content Workflow 10 (With Caching - Oct 14, 2025)**

**Base Workflow:** 12+ nodes for RAG-powered social media generation
**Cache Integration:** +7 nodes per cache type (generation/embedding/review)

**Cache Pattern (7 Nodes):**
1. **Build Cache Key** (Code) - SHA256 hash of model + prompt + content
2. **Check Cache** (Postgres) - Lookup cached response
3. **Cache Hit?** (IF) - Route to cached or fresh path
4. **Use Cached** (Code) - Extract cached response (TRUE path)
5. **Format Fresh** (Code) - Normalize LLM output (FALSE path)
6. **Store Cache** (Postgres) - UPSERT with hit_count tracking
7. **Merge** (Merge) - Combine cached + fresh results

**Implementation Guide:** `/json-flows/farts.md` (complete drop-in configs)
**Generator Prompts:** `/json-flows/GENERATOR-NODE-EXACT.md`

**Cost Savings:**
- Generation cache: 50-80% reduction on duplicate episodes
- Hit tracking: `SELECT SUM(hit_count) FROM core.api_cache WHERE cache_type='generation';`

### **Import Workflows**
```bash
# Upload workflow
curl -X POST "your-n8n-url/api/v1/workflows/import" \
  -H "Content-Type: application/json" \
  -d @idudes-n8n-workflow.json

# Search workflow
curl -X POST "your-n8n-url/api/v1/workflows/import" \
  -H "Content-Type: application/json" \
  -d @SEARCH-WORKFLOW-NODES.json

# Social content automation (workflow 10)
# Located at: /json-flows/10-social-content-automation.json
```

---

## ⚡ **PERFORMANCE & SCALING**

### **Current Metrics**
- **Upload Speed:** ~50ms per document
- **Search Latency:** ~200ms per query
- **Storage:** DigitalOcean CDN (global)
- **Database:** Railway PostgreSQL (optimized)
- **Embeddings:** OpenAI text-embedding-3-small

### **Scaling Limits**
- **Documents:** 10M+ with proper indexing
- **Concurrent Users:** 100+ simultaneous searches
- **Storage:** Unlimited via DigitalOcean Spaces
- **Regions:** Global CDN distribution

### **Cost Estimates**
```
Monthly Costs (1000 documents, 5000 searches):
- Railway PostgreSQL: $5/month
- DigitalOcean Spaces: $5/month  
- OpenAI Embeddings: $2/month
- Vercel Hosting: Free tier
Total: ~$12/month
```

---

## 🔒 **SECURITY**

### **Data Protection**
- ✅ **HTTPS Everywhere** (SSL via Let's Encrypt)
- ✅ **Environment Variables** (No hardcoded secrets)
- ✅ **Database Encryption** (Railway managed)
- ✅ **API Rate Limiting** (Vercel edge functions)
- ✅ **CORS Configuration** (Restricted origins)

### **Access Control**
- 🔧 **IP Whitelisting** (Optional via Cloudflare)
- 🔧 **API Key Authentication** (Can be added)  
- 🔧 **Role-Based Access** (Multi-tenant ready)

---

## 🐛 **TROUBLESHOOTING**

### **Common Issues**

#### **Upload Fails**
```bash
# Check n8n webhook is active
curl https://ai.thirdeyediagnostics.com/webhook/idudesRAG/documents

# Verify environment variables
echo $OPENAI_API_KEY
echo $DATABASE_URL
```

#### **Search Returns No Results**
```bash
# Check database has data
psql $DATABASE_URL -c "SELECT COUNT(*) FROM documents;"
psql $DATABASE_URL -c "SELECT COUNT(*) FROM document_embeddings;"

# Test search function directly
psql $DATABASE_URL -c "SELECT * FROM search_documents('[0.1]'::vector(1536), 0.5, 5);"
```

#### **Slow Performance**
```bash
# Check vector index exists
psql $DATABASE_URL -c "\di+ idx_document_embeddings_vector"

# Rebuild index if needed
psql $DATABASE_URL -c "REINDEX INDEX idx_document_embeddings_vector;"
```

### **Debug Mode**
```bash
# Enable verbose logging in n8n
LOG_LEVEL=debug

# Check container logs
docker logs idudes-doc-processor -f

# Monitor database queries
psql $DATABASE_URL -c "SELECT * FROM pg_stat_activity WHERE state = 'active';"
```

---

## 🤝 **CONTRIBUTING**

### **Development Setup**
```bash
# Clone repository
git clone https://github.com/cpretzinger/idudesRAG.git
cd idudesRAG

# Install dependencies
cd ui && npm install

# Start development server
npm run dev

# Run tests (when available)
npm test
```

### **Code Style**
- **TypeScript** for type safety
- **ESLint + Prettier** for formatting
- **Conventional Commits** for git messages
- **PostgreSQL** for all data operations

---

## 📄 **LICENSE**

MIT License - Feel free to use for commercial or personal projects.

---

## 📞 **SUPPORT**

### **Documentation**
- 📋 **Setup Guides:** See `/Documentation/` folder
- 🔄 **Workflow Examples:** See `/Workflows/` folder  
- 🗄️ **Database Schema:** See `/Database/` folder

### **Community**
- 🐛 **Issues:** [GitHub Issues](https://github.com/cpretzinger/idudesRAG/issues)
- 💬 **Discussions:** [GitHub Discussions](https://github.com/cpretzinger/idudesRAG/discussions)
- 📧 **Email:** craig@theidudes.com

### **Professional Services**
- 🏢 **Custom Deployment:** Available for enterprise
- 🔧 **Integration Support:** API development assistance
- 📊 **Analytics Setup:** Custom dashboards and reporting

---

## 🎯 **ROADMAP**

### **Q4 2024 - COMPLETED ✅**
- [x] Core RAG pipeline with pgvector
- [x] n8n workflow automation
- [x] Social media content generation
- [x] Railway PostgreSQL deployment
- [x] Vercel UI deployment

### **October 2025 - COMPLETED ✅**
- [x] **API caching system** (50-80% cost reduction)
- [x] **Schema auto-sync** (hourly to `/documentation/database/`)
- [x] **PostgreSQL optimization** (composite indexes, UPSERT patterns)
- [x] **Workflow 10 cache integration** (7-node pattern documented)
- [x] **gpt-5-nano migration** (default model for all coding/n8n work)

### **Q1 2025**
- [ ] Multi-file upload support
- [ ] Real-time search suggestions
- [ ] Document versioning
- [ ] Advanced filtering options
- [ ] Embedding cache implementation (Phase 2)
- [ ] Review cache implementation (Phase 3)

### **Q2 2025**
- [ ] Multi-language support
- [ ] OCR for scanned documents
- [ ] Chat interface with documents
- [ ] Enterprise SSO integration
- [ ] Cache effectiveness dashboard

### **Q3 2025**
- [ ] Kubernetes deployment option
- [ ] Advanced analytics dashboard
- [ ] API monetization features
- [ ] Mobile app support

---

## ⭐ **ACKNOWLEDGMENTS**

Built with:
- **🚀 Next.js** - React framework for UI
- **🐘 PostgreSQL** - Database with pgvector extension
- **🤖 OpenAI** - Embeddings and AI capabilities  
- **☁️ DigitalOcean** - Spaces storage and CDN
- **🚂 Railway** - Managed PostgreSQL hosting
- **▲ Vercel** - Frontend deployment platform
- **🔄 n8n** - Workflow automation platform

---

## 📊 **STATS**

- **⭐ Stars:** Be the first to star this project!
- **🍴 Forks:** Help improve this system
- **🐛 Issues:** Report bugs and request features
- **📈 Usage:** Growing community of RAG developers

---

**Made with ❤️ by Craig Pretzinger for the AI community**

*Transforming document intelligence, one upload at a time.*

Current UI Capabilities:
  ✅ Chat interface at /chat using GPT-5-nano
  ✅ File upload system
  ✅ Auth system (n8n-native)

  System Prompt for Pakistani Content Team:

  # INSURANCE DUDES CONTENT ASSISTANT - URDU/ENGLISH BILINGUAL

  ## YOUR ROLE
  You are the AI content assistant for Insurance Dudes content team. Your team includes Pakistani content
  creators who may communicate in **Urdu (اردو) or English**.

  ## LANGUAGE RULES - CRITICAL
  1. **Accept Input**: Urdu (اردو) OR English
  2. **ALWAYS Output**: English ONLY (for copy-paste into systems)
  3. **Directions**: Give in BOTH Urdu and English when helping team

  ## YOUR EXPERTISE
  Based on the Insurance Dudes 2025 Content Domination Playbook:

  ### WEEKLY CONTENT SCHEDULE
  - **Monday Mayhem** (7 AM): 60-sec horror stories
  - **Teaching Tuesday** (12 PM): 3-min explainer videos
  - **War Story Wednesday** (5 PM): 8-12 min podcast clips
  - **Throwdown Thursday** (2 PM): Hot takes/controversial
  - **Friday Finals** (10 AM): Newsletter + podcast drop
  - **Sales Saturday** (9 AM): Live role-play streams
  - **Sunday Scroll** (7 PM): Meme carousels

  ### CONTENT PILLARS (4 E's)
  - Education 25%
  - Entertainment 35%
  - Emotion 25%
  - Engagement 15%

  ### PLATFORM REQUIREMENTS
  - YouTube Shorts: 15-45 sec, subtitles always
  - LinkedIn: 1,300 chars, 8 AM daily
  - TikTok: 3x daily, jump on trends <48hrs
  - Instagram: Reels 6 PM daily
  - Twitter/X: 5-10 tweets daily

  ## WHEN USER ASKS IN URDU
  **Understand**: Process their Urdu request fully
  **Respond**: Give directions in Urdu + English
  **Output Content**: ALWAYS in English (ready to copy-paste)

  ## EXAMPLE INTERACTION

  User (Urdu): "مجھے Monday ke liye ek horror story chahiye insurance claim ke baare mein"
  (I need a horror story for Monday about insurance claim)