// ProcessDocument Code Node - Production Version
// Purpose: Extract text, chunk, generate embeddings, return n8n items for PostgreSQL insertion
// Last Updated: 2025-10-15
// Memory Limit: 6GB container, ~700MB safe working memory per execution

const CONFIG = {
  CHUNK_SIZE: 900,
  OVERLAP: 150,
  BATCH_SIZE: 100,
  MAX_RETRIES: 3,
  TIMEOUT_MS: 120000,
  RATE_LIMIT_DELAY_MS: 100,
  MAX_FILE_SIZE_MB: 100,
  MAX_CHUNKS_IN_MEMORY: 1000,
  EMBEDDING_MODEL: 'text-embedding-3-small',
  EMBEDDING_DIMENSIONS: 1536
};

const OPENAI_API_KEY = $env.OPENAI_API_KEY;
if (!OPENAI_API_KEY) throw new Error('OPENAI_API_KEY not configured in environment');

const items = $input.all();

// Extract metadata with fallback strategy
let meta = items.find(i => i.json?.file_id && i.json?.filename)?.json;
if (!meta) {
  const pkg = $items('ExtractAndPackage', 0, 0)?.[0]?.json;
  if (pkg?.file_id && pkg?.filename) meta = pkg;
}
if (!meta) {
  throw new Error('Missing file metadata (file_id, filename). Ensure ExtractAndPackage → ProcessDocument OR pass-through metadata.');
}

const file_id = meta.file_id;
const filename = meta.filename;
const mime_type = meta.mime_type || 'text/plain';

// Validate file_id format (UUID)
if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(file_id)) {
  throw new Error(`Invalid file_id format: ${file_id}`);
}

// Extract content from various input formats
let content = '';
for (const it of items) {
  if (typeof it.json?.data === 'string') { content = it.json.data; break; }
  if (typeof it.json?.content === 'string') { content = it.json.content; break; }
  if (typeof it.json === 'string') { content = it.json; break; }
  if (it.binary && Object.keys(it.binary).length) {
    const [binKey] = Object.keys(it.binary);
    const b64 = it.binary[binKey]?.data;
    if (b64) {
      try {
        content = Buffer.from(b64, 'base64').toString('utf-8');
        break;
      } catch (e) {
        console.warn(`Failed to decode binary data: ${e.message}`);
        continue;
      }
    }
  }
}
if (!content || content.length < 50) {
  throw new Error(`No content found in inputs for ${filename} (min 50 chars required).`);
}

// Text normalization and cleaning
function finalClean(s) {
  return String(s)
    .replace(/\r\n?/g, '\n')
    .replace(/\t/g, ' ')
    .replace(/\u0000/g, '')
    .normalize('NFKD').replace(/[\u0300-\u036f]/g, '')
    .replace(/\u00A0/g, ' ')
    .replace(/\u2018|\u2019|\u201A|\u2032/g, "'")
    .replace(/\u201C|\u201D|\u201E|\u2033/g, '"')
    .replace(/\u2014/g, ' — ')
    .replace(/\u2013/g, '-')
    .replace(/\u2026/g, '...')
    .replace(/[ \t]+/g, ' ')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

const cleanedText = finalClean(content);
if (cleanedText.length < 50) throw new Error('Cleaned text too short (min 50 chars)');

// File size validation
const maxBytes = CONFIG.MAX_FILE_SIZE_MB * 1024 * 1024;
if (cleanedText.length > maxBytes) {
  throw new Error(`File too large: ${(cleanedText.length / 1024 / 1024).toFixed(1)}MB exceeds ${CONFIG.MAX_FILE_SIZE_MB}MB limit`);
}

console.log(`Processing ${filename} (${file_id})`);
console.log(`Content: ${content.length} bytes → Cleaned: ${cleanedText.length} bytes`);

// Semantic chunking with overlap
const chunks = [];
let start = 0;
while (start < cleanedText.length) {
  let end = Math.min(start + CONFIG.CHUNK_SIZE, cleanedText.length);
  if (end < cleanedText.length) {
    const window = cleanedText.slice(start, end);
    const breaks = [
      window.lastIndexOf('\n\n'),
      window.lastIndexOf('\n'),
      window.lastIndexOf('. '),
      window.lastIndexOf('! '),
      window.lastIndexOf('? '),
      window.lastIndexOf('; '),
      window.lastIndexOf(', ')
    ];
    const best = Math.max(...breaks);
    if (best > CONFIG.CHUNK_SIZE * 0.5) end = start + best + 1;
  }
  const txt = cleanedText.slice(start, end).trim();
  if (txt) chunks.push(txt);
  if (end >= cleanedText.length) break;
  start = Math.max(0, end - CONFIG.OVERLAP);
}
if (!chunks.length) throw new Error('No chunks created');

console.log(`Generated ${chunks.length} chunks (avg: ${Math.floor(cleanedText.length / chunks.length)} chars)`);

// OpenAI embedding with retry logic
async function embedBatch(batch, retries = CONFIG.MAX_RETRIES) {
  for (let attempt = 1; attempt <= retries; attempt++) {
    try {
      const res = await this.helpers.httpRequest({
        method: 'POST',
        url: 'https://api.openai.com/v1/embeddings',
        headers: {
          'Authorization': `Bearer ${OPENAI_API_KEY}`,
          'Content-Type': 'application/json'
        },
        body: { input: batch, model: CONFIG.EMBEDDING_MODEL },
        json: true,
        timeout: CONFIG.TIMEOUT_MS,
        ignoreHttpStatusErrors: true,
      });

      if (res.error) {
        throw new Error(`OpenAI API Error: ${res.error.message || JSON.stringify(res.error)}`);
      }

      if (!res.data || !Array.isArray(res.data)) {
        throw new Error('Invalid response format from OpenAI API');
      }

      return res.data.map(d => d.embedding);

    } catch (error) {
      const isLastAttempt = attempt === retries;

      if (isLastAttempt) {
        throw new Error(`Embedding failed after ${retries} attempts: ${error.message}`);
      }

      const delay = Math.pow(2, attempt) * 1000;
      console.log(`Attempt ${attempt} failed (${error.message}), retrying in ${delay}ms...`);
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }
}

const t0 = Date.now();

// Batch embedding with rate limiting
const embs = [];
const batchCount = Math.ceil(chunks.length / CONFIG.BATCH_SIZE);
console.log(`Processing ${batchCount} embedding batches...`);

for (let i = 0; i < chunks.length; i += CONFIG.BATCH_SIZE) {
  const batch = chunks.slice(i, i + CONFIG.BATCH_SIZE);
  const out = await embedBatch.call(this, batch);
  embs.push(...out);

  // Rate limiting between batches
  if (i + CONFIG.BATCH_SIZE < chunks.length) {
    await new Promise(resolve => setTimeout(resolve, CONFIG.RATE_LIMIT_DELAY_MS));
  }
}

const duration = Math.floor((Date.now() - t0) / 1000);
console.log(`Embeddings complete in ${duration}s (avg: ${(duration / chunks.length).toFixed(2)}s/chunk)`);

// Validate embedding count and dimensions
if (embs.length !== chunks.length) {
  throw new Error(`Embedding count mismatch: ${chunks.length} chunks but ${embs.length} embeddings`);
}

// Sanitize filename for safe storage
const safeFilename = filename.replace(/[^a-zA-Z0-9._-]/g, '_').slice(0, 255);

// Build n8n items for PostgreSQL insertion
return chunks.map((text, idx) => {
  const embedding = embs[idx];

  if (!Array.isArray(embedding) || embedding.length !== CONFIG.EMBEDDING_DIMENSIONS) {
    throw new Error(`Invalid embedding at index ${idx}: expected ${CONFIG.EMBEDDING_DIMENSIONS}-dim array, got ${typeof embedding}`);
  }

  return {
    json: {
      file_id,
      filename: safeFilename,
      original_filename: filename,
      file_type: mime_type,
      file_size: cleanedText.length,
      chunk_index: idx,
      text,
      chunk_size: text.length,
      embedding,
      total_chunks: chunks.length,
      duration,
      status: 'completed'
    }
  };
});
