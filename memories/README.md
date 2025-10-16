# Memories Directory Structure

Quick-search optimized folder organization for Claude context retrieval.

## Folder Structure

```
memories/
├── workflows/           # n8n workflow fixes, patterns, node configs
├── database/           # Schema changes, migrations, query patterns
├── bugs/               # Bug investigations and fixes
├── architecture/       # System design decisions, data flow diagrams
├── integrations/       # API integrations, webhook configs, external services
├── prompts/            # LLM prompt engineering, versioning strategies
├── performance/        # Optimization work, caching strategies
├── deployment/         # Docker, environment configs, CI/CD notes
└── learnings/          # General project learnings, gotchas, patterns
```

## Quick Search Keywords

### workflows/
- n8n node configurations
- Field name mappings ($json.field references)
- Connection patterns between nodes
- Error handling patterns
- Batch processing patterns

### database/
- Table schemas and column types
- Migration scripts and rollback patterns
- Index creation strategies
- Query optimization notes
- PostgreSQL + pgvector patterns

### bugs/
- Root cause analyses
- Field naming mismatches
- Data flow issues
- Null value investigations
- Type conversion problems

### architecture/
- ProcessDocument → InsertEmbedding → UpdateStatus flow
- Content classification (episode vs book)
- Cache key generation strategies
- Vector embedding pipelines
- Multi-stage processing patterns

### integrations/
- Google Drive API patterns
- OpenAI embedding API usage
- Railway PostgreSQL connections
- Webhook configurations
- External service authentication

### prompts/
- v2 vs v3 prompt strategies
- System prompt templates
- content_type conditional logic
- Persona injection patterns
- Brand voice consistency

### performance/
- Batch size optimizations
- Embedding API rate limiting
- Database query optimization
- Memory management (6GB container limits)
- Caching strategies (API cache, generation cache)

### deployment/
- Environment variable requirements
- Docker container configs
- n8n custom node setup
- Database connection strings
- Service health checks

### learnings/
- Common pitfalls and solutions
- Best practices discovered
- Anti-patterns to avoid
- Quick reference guides
- "Never do this again" notes

## Naming Convention

Use descriptive filenames:
- `YYYY-MM-DD-short-description.md` for dated entries
- `topic-specific-name.md` for evergreen references
- `twat.md` for "This Week's Awesome Troubleshooting" quick notes

## Usage

When creating new memory files:
1. Put in the most relevant folder
2. Use clear, searchable titles
3. Include keywords at the top
4. Reference related files
5. Keep it concise and actionable
