#!/usr/bin/env node

const https = require('https');
const { Client } = require('pg');
const fs = require('fs');
const path = require('path');

// Load .env file
const envPath = path.join(__dirname, '.env');
if (fs.existsSync(envPath)) {
  const envContent = fs.readFileSync(envPath, 'utf-8');
  envContent.split('\n').forEach(line => {
    const match = line.match(/^([^=]+)=(.*)$/);
    if (match && !process.env[match[1]]) {
      process.env[match[1]] = match[2];
    }
  });
}

// Configuration
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
const DB_URL = 'postgres://postgres:d7ToQHAA7VecTKi2DxFgNxtlj~xN_HnD@yamabiko.proxy.rlwy.net:15649/railway';

// Test query
const TEST_QUERY = process.argv[2] || 'How do I get more leads for my business?';

console.log(`\n🔍 Semantic Search Test`);
console.log(`Query: "${TEST_QUERY}"\n`);

// Function to get embedding from OpenAI
async function getEmbedding(text) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify({
      input: text,
      model: 'text-embedding-3-small'
    });

    const options = {
      hostname: 'api.openai.com',
      path: '/v1/embeddings',
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${OPENAI_API_KEY}`,
        'Content-Type': 'application/json',
        'Content-Length': data.length
      }
    };

    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => { body += chunk; });
      res.on('end', () => {
        try {
          const response = JSON.parse(body);
          if (response.error) {
            reject(new Error(`OpenAI API Error: ${response.error.message}`));
          } else if (response.data && response.data[0]) {
            resolve(response.data[0].embedding);
          } else {
            console.error('OpenAI Response:', body);
            reject(new Error('Invalid OpenAI response structure'));
          }
        } catch (err) {
          console.error('Failed to parse OpenAI response:', body);
          reject(err);
        }
      });
    });

    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

// Main function
async function main() {
  const client = new Client({ connectionString: DB_URL });

  try {
    console.log('📡 Connecting to database...');
    await client.connect();

    console.log('🤖 Getting embedding from OpenAI...');
    const queryEmbedding = await getEmbedding(TEST_QUERY);
    console.log(`✅ Got embedding (${queryEmbedding.length} dimensions)\n`);

    // Verify table structure
    console.log('🔧 Checking table structure...');
    const structureResult = await client.query(`
      SELECT column_name, data_type
      FROM information_schema.columns
      WHERE table_schema = 'core'
      AND table_name = 'embeddings'
      ORDER BY ordinal_position;
    `);
    console.log('Table columns:', structureResult.rows.map(r => `${r.column_name} (${r.data_type})`).join(', '));
    console.log('');

    // Check total embeddings
    const countResult = await client.query('SELECT COUNT(*) FROM core.embeddings;');
    console.log(`Total embeddings in database: ${countResult.rows[0].count}\n`);

    // Perform semantic search using cosine similarity
    console.log('🔎 Performing semantic search...\n');
    const searchResult = await client.query(`
      SELECT
        file_id,
        filename,
        chunk_index,
        LEFT(text, 200) as text_preview,
        chunk_size,
        1 - (embedding <=> $1::vector) as similarity
      FROM core.embeddings
      ORDER BY embedding <=> $1::vector
      LIMIT 5;
    `, [`[${queryEmbedding.join(',')}]`]);

    console.log(`📊 Found ${searchResult.rows.length} results:\n`);

    searchResult.rows.forEach((row, idx) => {
      console.log(`${idx + 1}. ${row.filename} (chunk ${row.chunk_index})`);
      console.log(`   Similarity: ${(row.similarity * 100).toFixed(2)}%`);
      console.log(`   Size: ${row.chunk_size} chars`);
      console.log(`   Preview: ${row.text_preview.replace(/\n/g, ' ').substring(0, 150)}...`);
      console.log('');
    });

    console.log('✅ Semantic search test completed successfully!');

  } catch (err) {
    console.error('❌ Error:', err.message);
    console.error(err);
    process.exit(1);
  } finally {
    await client.end();
  }
}

main();
