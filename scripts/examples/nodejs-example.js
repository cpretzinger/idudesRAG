// SIMPLEST NODEJS IMPLEMENTATION
// npm install pg openai

const { Pool } = require('pg');
const OpenAI = require('openai');

// Your connection
const pool = new Pool({
  connectionString: 'postgresql://postgres:5Prl6LQokZHCIo59EOr3Tys0esF7ubao@trolley.proxy.rlwy.net:35195/railway',
  ssl: { rejectUnauthorized: false }
});

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY
});

// ============================================
// INGEST A DOCUMENT
// ============================================
async function ingestDocument(text, metadata = {}) {
  // 1. Store document
  const { rows } = await pool.query(
    'INSERT INTO core.documents (content, metadata) VALUES ($1, $2) RETURNING id',
    [text, metadata]
  );
  const docId = rows[0].id;
  
  // 2. Chunk it (simple 1000 char chunks)
  const chunks = [];
  const chunkSize = 1000;
  for (let i = 0; i < text.length; i += chunkSize) {
    chunks.push(text.slice(i, i + chunkSize));
  }
  
  // 3. Embed and store each chunk
  for (let i = 0; i < chunks.length; i++) {
    const embedding = await openai.embeddings.create({
      model: 'text-embedding-3-small',
      input: chunks[i]
    });
    
    await pool.query(
      'INSERT INTO core.document_embeddings (document_id, chunk, embedding, chunk_index) VALUES ($1, $2, $3, $4)',
      [docId, chunks[i], JSON.stringify(embedding.data[0].embedding), i]
    );
  }
  
  return docId;
}

// ============================================
// SEARCH DOCUMENTS
// ============================================
async function searchDocuments(query, limit = 10) {
  // 1. Embed the query
  const queryEmbedding = await openai.embeddings.create({
    model: 'text-embedding-3-small',
    input: query
  });
  
  // 2. Search
  const { rows } = await pool.query(`
    SELECT 
      de.chunk,
      d.metadata,
      1 - (de.embedding <=> $1::vector) as similarity
    FROM core.document_embeddings de
    JOIN core.documents d ON d.id = de.document_id
    WHERE 1 - (de.embedding <=> $1::vector) > 0.7
    ORDER BY de.embedding <=> $1::vector
    LIMIT $2
  `, [JSON.stringify(queryEmbedding.data[0].embedding), limit]);
  
  return rows;
}

// ============================================
// USAGE
// ============================================
async function main() {
  // Ingest
  const docId = await ingestDocument(
    "This is my document about PostgreSQL and vector search.",
    { title: "PG Guide", source: "manual" }
  );
  console.log('Document ingested:', docId);
  
  // Search
  const results = await searchDocuments("How to search vectors?");
  console.log('Search results:', results);
}

main().catch(console.error);