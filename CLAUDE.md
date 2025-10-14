# Claude Project Configuration - idudesRAG

## 🎯 CORE PROJECT IDENTITY

### Project Information
```bash
# Project Name: idudesRAG
# Primary Purpose: RAG-powered document processing and semantic search system
# Tech Stack: Next.js, PostgreSQL, Qdrant, n8n, Docker
# User Identity: Craig Pretzinger (waldobabbo)
```

## 🔧 CRITICAL SYSTEM CONFIGURATION

### Database & Infrastructure
```bash
# Primary Database (PostgreSQL with pgvector)
RAILWAY_PGVECTOR_URL=postgres://postgres:d7ToQHAA7VecTKi2DxFgNxtlj~xN_HnD@yamabiko.proxy.rlwy.net:15649/railway


# AI Services
OPENAI_API_KEY=

# n8n Integration
NEXT_PUBLIC_N8N_URL=[N8N_URL]
N8N_WEBHOOK_URL=[N8N_WEBHOOK_URL]
```

### Environment File Location
```
Location: /Users/craigpretzinger/projects/idudesRAG/.env
```

## 🤖 AI MODEL PREFERENCES

### Model Selection Strategy
- **DEFAULT FOR ALL CODING & n8n WORK**: gpt-5-nano (fast, cheap, handles 90% of tasks)
- **DEFAULT FOR EMBEDDINGS**: gpt-4o-mini (cost-effective, proven for RAG)
- **COMPLEX REASONING**: gpt-4o (heavy document analysis, multi-step logic)
- **NEVER**: GPT-3.5 models (outdated for RAG tasks)

### Model Usage Rules
- **gpt-5-nano**: Use for ALL code generation, classification, parsing, n8n node configs, SQL queries, simple transforms
- **gpt-5-mini**: Medium complexity tasks requiring more reasoning
- **gpt-4o**: Only when explicitly needed for complex reasoning or when gpt-5-nano fails
- **Cost optimization**: Prefer gpt-5-nano first, escalate only if insufficient

## 📁 FILE ORGANIZATION

### Key Directories
```
/ui/                - Next.js frontend application
/processor/         - Document processing service
/migrations/        - Database schema migrations
/json-flows/        - n8n workflow configurations
/qdrant_storage/    - Vector database storage
/documentation/     - Project documentation (use Context7 MCP)
/scripts/           - Automation and utility scripts
```

### Critical Files
- `README.md` - Project overview and setup
- `docker-compose.yml` - Container orchestration
- `ui/package.json` - Frontend dependencies & scripts
- `processor/package.json` - Processing service dependencies
- `rag-architecture-schema.sql` - Database schema
- `n8n-workflows.json` - Workflow configurations

## 🚀 SPECIALIZED AGENT SELECTION

### When to Use Which Agent
- **File Search**: Task agent (comprehensive codebase searches)
- **Workflow Design**: n8n-workflow-architect (for n8n automation)
- **Database Work**: postgres-n8n-specialist (PostgreSQL + pgvector)
- **Vector Operations**: data-science-pipeline (embedding/similarity work)
- **Git Operations**: github-expert
- **CI/CD**: automation-architect
- **Code Review**: code-deep-reviewer
- **Documentation**: Context7 MCP (go-to for all documentation)

## 📋 PROJECT COMMANDS

### Development Commands
```bash
# Start all services
docker-compose up -d

# Start UI development
cd ui && npm run dev

# Build UI
cd ui && npm run build

# Linting
cd ui && npm run lint

# Start processor service
cd processor && npm start
```

### Custom Scripts
```bash
# Test n8n API connectivity
./test-n8n-api.sh

# Test podcast ingestion workflow
./test-podcast-ingestion.sh

# Run database migrations
make migrate

# Backup qdrant storage
make backup-qdrant
```

## 🚨 CRITICAL BEHAVIORAL RULES (ZERO TOLERANCE)

### Golden Rules - Tattoo These On Your Brain
1. **NO GUESSING**: Never invent DB columns, table names, node types, or field names. If not explicit in schema/docs, LOOK IT UP or ASK.
2. **SECRETS FROM .ENV ONLY**: All credentials/URLs/tokens must reference exact .env keys. Never inline secrets.
3. **SCHEMA IS LAW**: All queries/migrations must match EXACT schema (names, casing, types, constraints). Verify first.
4. **n8n DISCIPLINE**:
   - NEVER edit or output full project workflow JSON
   - NEVER hand nodes as raw n8n JSON
   - ONLY use NATIVE n8n nodes (no custom/imaginary nodes)
   - JSON snippets are reference context - output UI-friendly configs ONLY
5. **DELIVERABLES = USABLE**: Output must be copy-pasteable code/SQL or step-by-step UI config with exact field names/values

### Self-Check Protocol (Before Every Response)
1. ✅ Verified all DB names/columns/keys against schema/migrations?
2. ✅ Referenced only .env keys for secrets/URLs?
3. ✅ n8n steps provided as UI-friendly config (not JSON)?
4. ✅ Used only native n8n nodes?
5. ✅ Output is copy-pasteable and complete?
6. ✅ If ambiguous, asked concise questions first?

### Banned Behaviors
- ❌ Guessing column names or "close enough" wording
- ❌ Using secrets directly in examples
- ❌ Outputting or editing workflow JSON
- ❌ Supplying nodes as n8n JSON
- ❌ Inventing non-native n8n nodes or fields
- ❌ Hand-wavy instructions (show EVERY field)

## 🔒 SECURITY BEST PRACTICES

### Never Commit
- API keys (.env file)
- Database credentials
- Digital Ocean Spaces keys
- n8n webhook URLs
- Vector database storage files

### Always Use
- Environment variables for all secrets (exact .env key names)
- HTTPS for external API calls
- Input validation for document uploads
- Rate limiting on API endpoints

### Environment Variable Discipline
- **All secrets/URLs** loaded from .env
- **Never inline** secrets in code, configs, or examples
- If variable doesn't exist in .env, propose:
  - New key name
  - Where it's read
  - Safe default (do NOT invent values)
- Before showing script/config, list required env keys:
  ```
  Requires .env:
  - DATABASE_URL
  - REDIS_URL
  ```

## 🏗️ ARCHITECTURE PATTERNS

### Database Schema Rules
- **Source of truth**: migration files, Prisma schema, or DB introspection (`SHOW COLUMNS FROM ...`)
- **Never alias** or "pretty name" DB entities - use EXACT table/column names and types
- When unsure: 1) check schema/migrations, 2) inspect DB, 3) ask
- Use `public.` schema for main tables
- Vector embeddings stored in Qdrant
- Document metadata in PostgreSQL
- Implement proper indexing for search performance

### SQL Requirements
- Fully qualified table names if project requires it
- Explicit column lists (no `SELECT *` in production code)
- Correct constraints (PK/FK/UNIQUE/CHECK) and indexes when relevant
- **Migrations**: Provide forward AND safe rollback steps
- Warn about data-impacting changes (nullable→non-null, enum changes, drops)

### API Design
- RESTful endpoints in Next.js API routes
- Webhook handlers for n8n integration
- Consistent error handling across services
- Document upload/processing pipelines

### Caching Strategy
- Qdrant for vector similarity search
- PostgreSQL for metadata queries
- n8n for workflow orchestration
- Redis for session data (if implemented)

## 📊 MONITORING & METRICS

### Health Checks
- `/api/test-env` endpoint (UI service)
- Qdrant health endpoint: `http://localhost:6333/health`
- PostgreSQL connectivity checks
- n8n webhook status

### Key Metrics
- Document processing time
- Search response times
- Vector similarity accuracy
- Webhook success rates
- Storage usage (Spaces + Qdrant)

## 🔄 AUTOMATION SETUP

### Git Hooks (Configured)
```bash
# .git/hooks/post-checkout
# Auto-applies Claude template for new repositories
```

### n8n Workflows
- Document processing pipeline
- Google Drive auto-ingestion
- Authentication flows
- Metadata enrichment
- Error notifications

### n8n Workflow Output Format (STRICT - DO NOT TEST ME ON THIS)
When providing n8n configurations, use this EXACT format:

```
Node: <Human-Readable Name> (Type: <Native n8n Node Type>)
Credentials: <Name of saved credential set in n8n>  // if applicable

Parameters:
  - <UI Field Label>: <Exact Value or Expression>
  - <UI Field Label>: <Exact Value or Expression>
  - Nested Field:
      - Sub-field: <Value>

Connections:
  - Input from: <Upstream Node Name / Main>
  - Output to:
      - <Downstream Node Name> via <Main/On Error/etc.>

Notes:
  - <Execution order caveats, rate limits, retries, JSON paths used>
  - <Any special configuration requirements>
```

**Native n8n nodes only**: HTTP Request, Function, Set, IF, Merge, Switch, MySQL/Postgres, Code, Webhook, etc.

**If credentials required**: Name the credential AS SAVED IN n8n (do NOT paste the secret). If unsure, ASK for credential name.

## 📝 DOCUMENTATION STRATEGY

### Use Context7 MCP For
- RAG architecture documentation
- API endpoint specifications
- n8n workflow diagrams
- Database schema documentation
- Deployment guides
- Troubleshooting guides

### Documentation Structure
```
/documentation/
  ├── api/              - API documentation
  ├── architecture/     - System design docs
  ├── workflows/        - n8n workflow guides
  ├── deployment/       - Setup and deployment
  └── troubleshoot/     - Common issues and fixes
```

## ✅ PROJECT CHECKLIST

### Initial Setup
- [x] Environment variables configured
- [x] Database schema created (PostgreSQL + pgvector)
- [x] Vector database setup (Qdrant)
- [x] Docker containers configured
- [x] n8n workflows implemented
- [x] Git hooks installed

### Development Ready
- [x] Development server runs (Next.js)
- [x] Document processing pipeline works
- [x] Vector search functional
- [x] n8n integration active
- [x] Docker containers healthy

### Production Ready
- [ ] Environment variables in production
- [x] Database migrations complete
- [x] Health checks implemented
- [ ] Monitoring configured
- [x] Error handling complete
- [ ] SSL certificates configured

## 🎯 SUCCESS METRICS

### Performance Targets
- Document processing: < 30s per document
- Search response time: < 2s
- Vector similarity accuracy: > 85%
- System uptime: > 99%

### Code Quality
- TypeScript strict mode enabled
- Linting: 0 errors
- Database queries optimized
- n8n workflows documented

## 🔍 RAG-SPECIFIC CONFIGURATION

### Vector Database (Qdrant)
- Collection: `idudes_documents`
- Vector size: 1536 (OpenAI embeddings)
- Distance metric: Cosine similarity
- Payload includes: document_id, metadata, chunks

### Document Processing
- Chunking strategy: Recursive character splitting
- Chunk size: 1000 characters
- Overlap: 200 characters
- Supported formats: PDF, TXT, DOCX, MD

### Search Configuration
- Semantic search via vector similarity
- Hybrid search (vector + keyword)
- Result ranking and re-ranking
- Context preservation across chunks

## 📋 RESPONSE TEMPLATES (USE THESE FORMATS)

### 1. Database Query/Change
```
Context:
- Goal: <one-liner>
- Tables involved: <exact names>

Requires .env:
- <KEY_1>, <KEY_2>

SQL:
<runnable SQL with explicit columns, constraints, and comments>

Notes:
- Impact, locks, rollbacks, index needs, etc.
```

### 2. App Code Touching Database
```
Assumptions:
- ORM/Driver: <name & version if known>

Requires .env:
- <KEYS>

Code:
<exact code; imports; connection uses .env>

Why it's correct:
- <schema confirmations>
```

### 3. n8n Node Config (UI-Friendly)
```
Node: Fetch Orders (Type: HTTP Request)
Credentials: Ecom API (API Key)

Parameters:
  - HTTP Method: GET
  - URL: {{$env.ECOM_BASE_URL}}/orders?since={{$json.lastRun}}
  - Query Params:
      - limit: 100
  - Authentication: Header Auth
  - Header: Authorization: Bearer {{$credentials.apiKey}}
  - Response: JSON

Connections:
  - Input from: Start (Main)
  - Output to: Transform Orders (Main)

Notes:
  - Retries: 3
  - Rate limit: 5 req/s
```

### 4. When Blocked - STOP AND ASK
If any of the following are missing/unclear:
- Actual DB schema for entities you need
- Exact .env key name for a required secret
- Saved name of a credential in n8n
- Which environment (dev/stage/prod) we're targeting

**Format**: "I need clarification on [specific item] before proceeding. Current options I see are: [list]. Which should I use?"

---

## 📋 PROJECT-SPECIFIC NOTES

### Active Workflows
1. Document processor RAG workflow
2. Google Drive auto-ingestion
3. Document metadata enrichment
4. Authentication flows (login, validate, reset)

### Known Issues
- Qdrant storage backup is large (70MB compressed)
- Monitor vector database storage growth
- Ensure n8n webhook endpoints remain accessible

### Next Steps
- Implement usage analytics dashboard
- Add conversation history tracking
- Create automated testing pipeline
- Set up production monitoring

---

## 🎭 TONE & CONDUCT

Be **crisp, direct, and execution-focused**. No fluff. If something's risky or ambiguous, say it straight and propose the safest next step. If you slip and start guessing, **HALT** and re-verify.

**Translation**: Use exact names, pull creds from .env, honor the schema, speak n8n UI language, and don't make stuff up. We ship facts, not vibes.

---

*Template Version: 2.0 - idudesRAG with Behavioral Rules*
*Last Updated: October 14, 2025*
*Precision-first coding • Zero guessing • Schema enforcement • n8n UI discipline*