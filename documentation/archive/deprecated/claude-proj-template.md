# Claude Project Template - Best Practices Configuration

## 🎯 CORE PROJECT IDENTITY

### Project Information
```bash
# Project Name: [PROJECT_NAME]
# Primary Purpose: [BRIEF_DESCRIPTION]
# Tech Stack: [MAIN_TECHNOLOGIES]
# User Identity: [YOUR_NAME] ([GITHUB_USERNAME])
```

## 🔧 CRITICAL SYSTEM CONFIGURATION

### Database & Infrastructure
```bash
# Primary Database
DATABASE_URL=[CONNECTION_STRING]

# Cache Layer (Redis/Memory)
REDIS_URL=[REDIS_CONNECTION] 

# AI Services
OPENAI_API_KEY=[API_KEY]
# Other API keys as needed
```

### Environment File Location
```
Location: [PATH_TO_ENV_FILE]
```

## 🤖 AI MODEL PREFERENCES

### Model Selection Strategy
- **DEFAULT**: gpt-4o-mini (fast, cost-effective)
- **COMPLEX**: gpt-4o (reasoning-heavy tasks)
- **CODING**: claude-3.5-sonnet (code generation)
- **NEVER**: [Deprecated models to avoid]

## 📁 FILE ORGANIZATION

### Key Directories
```
/src/           - Source code
/docs/          - Documentation (use Context7 MCP)
/tests/         - Test files
/scripts/       - Automation scripts
/config/        - Configuration files
```

### Critical Files
- `README.md` - Project overview
- `package.json` - Dependencies & scripts
- `.env.local` - Environment variables
- `docker-compose.yml` - Container setup

## 🚀 SPECIALIZED AGENT SELECTION

### When to Use Which Agent
- **File Search**: Task agent (comprehensive searches)
- **Workflow Design**: n8n-workflow-architect
- **Database Work**: postgres-n8n-specialist  
- **Cache/Memory**: redis-architect
- **Git Operations**: github-expert
- **CI/CD**: automation-architect
- **Code Review**: code-deep-reviewer
- **Documentation**: Context7 MCP (go-to for all docs)

## 📋 PROJECT COMMANDS

### Development Commands
```bash
# Start development
npm run dev

# Run tests
npm test

# Build project
npm run build

# Linting
npm run lint

# Type checking
npm run typecheck
```

### Custom Scripts
```bash
# Project-specific commands
[ADD_CUSTOM_COMMANDS]
```

## 🔒 SECURITY BEST PRACTICES

### Never Commit
- API keys or secrets
- Database credentials
- Personal access tokens
- Environment files (.env*)

### Always Use
- Environment variables for secrets
- HTTPS for all external calls
- Input validation
- Rate limiting

## 🏗️ ARCHITECTURE PATTERNS

### Database Schema
- Use `[SCHEMA_NAME].` prefix for related tables
- Implement proper indexing
- Use migrations for schema changes

### API Design
- RESTful endpoints
- Consistent error handling
- Proper HTTP status codes
- Rate limiting

### Caching Strategy
- Redis for session data
- In-memory for frequently accessed data
- Database query optimization

## 📊 MONITORING & METRICS

### Health Checks
- `/health` endpoint
- Database connectivity
- External service status

### Key Metrics
- Response times
- Error rates
- Resource usage
- User activity

## 🔄 AUTOMATION SETUP

### Git Hooks (Optional)
```bash
# .git/hooks/post-checkout
#!/bin/bash
if [ ! -f "CLAUDE.md" ] && [ -f "claude-proj-template.md" ]; then
    echo "Applying Claude template..."
    cp claude-proj-template.md CLAUDE.md
    echo "Template applied. Please customize CLAUDE.md for this project."
fi
```

## 📝 DOCUMENTATION STRATEGY

### Use Context7 MCP For
- API documentation
- Architecture diagrams
- User guides
- Technical specifications
- Troubleshooting guides

### Documentation Structure
```
/docs/
  ├── api/          - API documentation
  ├── architecture/ - System design
  ├── guides/       - User guides
  └── troubleshoot/ - Common issues
```

## ✅ PROJECT CHECKLIST

### Initial Setup
- [ ] Environment variables configured
- [ ] Database schema created
- [ ] API keys secured
- [ ] Git hooks installed (optional)
- [ ] Documentation structure created

### Development Ready
- [ ] Development server runs
- [ ] Tests pass
- [ ] Linting configured
- [ ] Type checking works
- [ ] CI/CD pipeline setup

### Production Ready
- [ ] Environment variables in production
- [ ] Database migrations run
- [ ] Health checks implemented
- [ ] Monitoring configured
- [ ] Error handling complete

## 🎯 SUCCESS METRICS

### Performance Targets
- Response time: < [TARGET]ms
- Uptime: > [TARGET]%
- Error rate: < [TARGET]%

### Code Quality
- Test coverage: > [TARGET]%
- Linting: 0 errors
- Type safety: 100%

---

## 📋 CUSTOMIZATION INSTRUCTIONS

1. Replace all `[PLACEHOLDER]` values with project-specific information
2. Add project-specific commands and scripts
3. Update database schema information
4. Configure monitoring and metrics
5. Set realistic performance targets
6. Remove sections not applicable to your project

---

*Template Version: 1.0*
*Last Updated: October 2025*
*For Claude Code best practices and optimal AI assistance*