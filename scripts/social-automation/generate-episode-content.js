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

const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
const DB_URL = 'postgres://postgres:d7ToQHAA7VecTKi2DxFgNxtlj~xN_HnD@yamabiko.proxy.rlwy.net:15649/railway';

// Content queries for insurance podcast extraction
const CONTENT_QUERIES = [
  "insurance sales tips strategies techniques",
  "overcoming objections closing deals",
  "lead generation prospecting methods",
  "client relationships trust building",
  "success stories case studies results",
  "mindset motivation productivity",
  "industry insights market trends",
  "technology tools automation",
  "networking referrals partnerships",
  "challenges solutions problems solved"
];

// Helper functions
function makeRequest(options, data = null) {
  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => { body += chunk; });
      res.on('end', () => {
        try {
          const response = JSON.parse(body);
          if (res.statusCode >= 400) {
            reject(new Error(`HTTP ${res.statusCode}: ${response.error?.message || body}`));
          } else {
            resolve(response);
          }
        } catch (err) {
          resolve(body);
        }
      });
    });
    req.on('error', reject);
    if (data) req.write(typeof data === 'string' ? data : JSON.stringify(data));
    req.end();
  });
}

async function getEmbedding(text) {
  const response = await makeRequest({
    hostname: 'api.openai.com',
    path: '/v1/embeddings',
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${OPENAI_API_KEY}`,
      'Content-Type': 'application/json'
    }
  }, {
    input: text,
    model: 'text-embedding-3-small'
  });
  return response.data[0].embedding;
}

async function generateContent(prompt, systemPrompt = null, maxTokens = 3000) {
  const messages = [];
  if (systemPrompt) messages.push({ role: 'system', content: systemPrompt });
  messages.push({ role: 'user', content: prompt });

  const response = await makeRequest({
    hostname: 'api.openai.com',
    path: '/v1/chat/completions',
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${OPENAI_API_KEY}`,
      'Content-Type': 'application/json'
    }
  }, {
    model: 'gpt-4o-mini',
    messages: messages,
    temperature: 0.8,
    max_tokens: maxTokens
  });

  return response.choices[0].message.content;
}

async function searchContent(client, query) {
  const embedding = await getEmbedding(query);
  const result = await client.query(`
    SELECT filename, text, chunk_index,
           1 - (embedding <=> $1::vector) as similarity
    FROM core.embeddings
    WHERE 1 - (embedding <=> $1::vector) > 0.25
    ORDER BY embedding <=> $1::vector
    LIMIT 3;
  `, [`[${embedding.join(',')}]`]);
  return result.rows;
}

// Main function
async function main() {
  const episodeTitle = process.argv[2] || 'Insurance Sales Mastery';

  console.log(`\n🎙️ PODCAST CONTENT GENERATOR FOR SOCIAL MEDIA`);
  console.log(`==============================================`);
  console.log(`Episode: ${episodeTitle}`);
  console.log(`Output: 10-Day Content Calendar\n`);

  const client = new Client({ connectionString: DB_URL });

  try {
    await client.connect();

    // Step 1: Extract key insights from podcast
    console.log('📚 Step 1: Extracting podcast insights...\n');
    const insights = [];

    for (const query of CONTENT_QUERIES) {
      process.stdout.write(`  Searching: ${query}...`);
      const results = await searchContent(client, query);
      if (results.length > 0) {
        insights.push({
          category: query,
          content: results.map(r => r.text).join('\n\n').substring(0, 600),
          similarity: results[0].similarity
        });
        console.log(` ✓ (${(results[0].similarity * 100).toFixed(0)}% match)`);
      } else {
        console.log(` - (no match)`);
      }
    }

    console.log(`\n✅ Extracted ${insights.length} content categories\n`);

    if (insights.length === 0) {
      console.log('⚠️  No content found in database. Please add podcast transcripts first.');
      process.exit(0);
    }

    // Step 2: Generate content calendar
    console.log('📅 Step 2: Generating 10-day social media calendar...\n');

    const context = insights.map(i =>
      `${i.category.toUpperCase()}:\n${i.content}`
    ).join('\n\n---\n\n');

    const prompt = `You are creating a 10-day social media content calendar for the Insurance Dudes podcast episode: "${episodeTitle}"

PODCAST CONTENT EXTRACTED:
${context}

Generate 10 days of social media content. Each day should have 3 posts (Instagram Reel, Facebook, LinkedIn).

CONTENT THEMES TO COVER (1 per day):
Day 1: Hook - Most shocking/surprising insight
Day 2: Tip #1 - Actionable strategy
Day 3: Challenge/Problem addressed
Day 4: Solution/Hack revealed
Day 5: Case study or success story
Day 6: Mindset/Motivation
Day 7: Tip #2 - Advanced technique
Day 8: Industry insight or trend
Day 9: Call-to-action teaser
Day 10: Episode recap + CTA

FORMAT (for each day):

**DAY X: [Theme Name]**

📱 INSTAGRAM REEL (15-30 seconds):
Hook: [Attention-grabbing opening line]
Script: [Main content - 2-3 sentences]
CTA: [Clear call to action]
Hashtags: #InsuranceDudes #InsuranceSales [3-5 relevant hashtags]

📘 FACEBOOK POST:
[Engaging post with emojis, conversational tone, question or hook]

Hashtags: [5-8 hashtags]

💼 LINKEDIN POST:
[Professional insight, thought leadership, value-driven content]

Hashtags: [5-8 professional hashtags]

---

Make each post engaging, actionable, and true to the podcast content. Use emojis strategically. Vary the tone and format to keep audience engaged.`;

    const voiceProfile = fs.readFileSync(path.join(__dirname, 'craig-jason-voice-profile.md'), 'utf-8');

    const systemPrompt = `You are writing social media content AS Craig and Jason from the Insurance Dudes podcast. You must capture their authentic voice perfectly.

${voiceProfile}

CRITICAL RULES:
1. Write like you're talking to a friend at a bar, not a corporate presentation
2. Be direct, real, and occasionally blunt
3. Use their specific phrases and language patterns
4. NO generic motivational BS
5. Every post should sound like Craig or Jason actually said it
6. Mix bro energy with expert credibility
7. Story-driven > stat-driven (but use data when it hits)
8. Make it actionable - give them the exact next step

Remember: They trust you because you're REAL, not because you're perfect.`;

    const calendar = await generateContent(prompt, systemPrompt, 4000);

    // Save output
    const timestamp = new Date().toISOString().split('T')[0];
    const outputFile = `social-calendar-${timestamp}.md`;
    const outputPath = path.join(__dirname, outputFile);

    fs.writeFileSync(outputPath, `# Social Media Content Calendar\n## Episode: ${episodeTitle}\n## Generated: ${new Date().toLocaleString()}\n\n---\n\n${calendar}`);

    console.log(`✅ Content calendar generated!\n`);
    console.log(`📄 Saved to: ${outputFile}\n`);

    // Show preview
    console.log('📋 PREVIEW (First 2 Days):\n');
    console.log('='.repeat(60));
    const preview = calendar.split('---')[0];
    console.log(preview.substring(0, 1000));
    console.log('\n... (8 more days in full file)');
    console.log('='.repeat(60));

    console.log(`\n✅ Complete! Open ${outputFile} to view full 10-day calendar\n`);

  } catch (err) {
    console.error('\n❌ Error:', err.message);
    if (err.stack) console.error(err.stack);
    process.exit(1);
  } finally {
    await client.end();
  }
}

main();
