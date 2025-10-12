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
- **DEFAULT**: gpt-4o-mini (fast, cost-effective for embeddings)
- **COMPLEX**: gpt-4o (reasoning-heavy document analysis)
- **CODING**: claude-3.5-sonnet (code generation)
- **NEVER**: GPT-3.5 models (outdated for RAG tasks)

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

## 🔒 SECURITY BEST PRACTICES

### Never Commit
- API keys (.env file)
- Database credentials
- Digital Ocean Spaces keys
- n8n webhook URLs
- Vector database storage files

### Always Use
- Environment variables for all secrets
- HTTPS for external API calls
- Input validation for document uploads
- Rate limiting on API endpoints

## 🏗️ ARCHITECTURE PATTERNS

### Database Schema
- Use `public.` schema for main tables
- Vector embeddings stored in Qdrant
- Document metadata in PostgreSQL
- Implement proper indexing for search performance

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

*Template Version: 1.0 - idudesRAG Customized*
*Last Updated: October 7, 2025*
*For Claude Code best practices and optimal RAG system assistance*