# 🔍 SEARCH WORKFLOW - NODE BY NODE CONFIG

## 📋 **COMPLETE n8n SEARCH WORKFLOW**

### **NODE 1: WEBHOOK (Search Input)**
```json
{
  "parameters": {
    "path": "idudesRAG/search",
    "httpMethod": "POST",
    "responseMode": "lastNode"
  },
  "type": "n8n-nodes-base.webhook",
  "name": "Search Webhook"
}
```

### **NODE 2: VALIDATE INPUT**
```javascript
// Code Node - Validate search query
const input = $input.first().json;

if (!input.query || input.query.trim().length === 0) {
  return [{ 
    json: { 
      error: "Query is required",
      status: 400 
    } 
  }];
}

return [{ 
  json: { 
    query: input.query.trim(),
    limit: input.limit || 10,
    threshold: input.threshold || 0.7
  } 
}];
```

### **NODE 3: OPENAI EMBEDDINGS (Query Vector)**
```json
{
  "parameters": {
    "resource": "embedding",
    "model": "text-embedding-3-small",
    "text": "={{ $json.query }}",
    "options": {
      "dimensions": 1536
    }
  },
  "type": "@n8n/n8n-nodes-langchain.embeddingsOpenAi",
  "credentials": {
    "openAiApi": {
      "id": "openai-creds",
      "name": "OpenAI API"
    }
  }
}
```

### **NODE 4: POSTGRESQL VECTOR SEARCH**
```json
{
  "parameters": {
    "operation": "executeQuery",
    "query": "SELECT \n  d.id as document_id,\n  d.filename,\n  d.spaces_url,\n  de.chunk_text,\n  1 - (de.embedding <=> $1::vector) as similarity\nFROM document_embeddings de\nJOIN documents d ON d.id = de.document_id\nWHERE 1 - (de.embedding <=> $1::vector) > $2\nORDER BY de.embedding <=> $1::vector\nLIMIT $3;",
    "additionalFields": {
      "mode": "independently",
      "queryParameters": "={{ JSON.stringify([$('OpenAI Embeddings').item.json.data, $('Validate Input').item.json.threshold, $('Validate Input').item.json.limit]) }}"
    }
  },
  "type": "n8n-nodes-base.postgres",
  "credentials": {
    "postgres": {
      "id": "railway-pgvector",
      "name": "Railway PGVector"
    }
  }
}
```

### **NODE 5: FORMAT RESPONSE**
```javascript
// Code Node - Format search results
const input = $input.first().json;
const searchQuery = $('Validate Input').first().json.query;
const results = input || [];

const formattedResults = results.map(row => ({
  document_id: row.document_id,
  filename: row.filename,
  spaces_url: row.spaces_url,
  content_preview: row.chunk_text.substring(0, 200) + '...',
  similarity: Math.round(row.similarity * 100) / 100,
  download_url: `https://datainjestion.nyc3.cdn.digitaloceanspaces.com/${row.filename}`
}));

return [{
  json: {
    success: true,
    query: searchQuery,
    total_results: formattedResults.length,
    results: formattedResults,
    timestamp: new Date().toISOString()
  }
}];
```

---

## 🔗 **NODE CONNECTIONS**

```
Search Webhook → Validate Input → OpenAI Embeddings → PostgreSQL Search → Format Response
```

---

## 🎯 **WEBHOOK URLS**

### **Upload:**
`https://ai.thirdeyediagnostics.com/webhook/idudesRAG/documents`

### **Search:**
`https://ai.thirdeyediagnostics.com/webhook/idudesRAG/search`

---

## 📝 **TEST PAYLOAD**

```json
{
  "query": "insurance policies",
  "limit": 5,
  "threshold": 0.7
}
```

---

## ✅ **EXPECTED RESPONSE**

```json
{
  "success": true,
  "query": "insurance policies",
  "total_results": 3,
  "results": [
    {
      "document_id": "uuid-here",
      "filename": "policy.pdf",
      "spaces_url": "https://datainjestion.nyc3.cdn.digitaloceanspaces.com/policy.pdf",
      "content_preview": "This policy covers...",
      "similarity": 0.89,
      "download_url": "https://datainjestion.nyc3.cdn.digitaloceanspaces.com/policy.pdf"
    }
  ],
  "timestamp": "2025-10-05T22:45:00.000Z"
}
```

**This workflow gives you semantic search with downloadable documents!** 🚀