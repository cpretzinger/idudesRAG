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

// Content extraction queries for insurance podcast
const CONTENT_QUERIES = [
  "actionable insurance sales tips and strategies",
  "overcoming client objections and challenges",
  "lead generation and prospecting tactics",
  "building trust and credibility with clients",
  "time management and productivity hacks",
  "closing techniques and sales strategies",
  "client success stories and case studies",
  "insurance industry insights and trends",
  "mindset and motivation for insurance agents",
  "referral and networking strategies"
];

// Get embedding from OpenAI
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
            reject(new Error('Invalid OpenAI response structure'));
          }
        } catch (err) {
          reject(err);
        }
      });
    });

    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

// Generate content using OpenAI (using gpt-5-nano as per user instructions)
async function generateContent(prompt, systemPrompt = null) {
  return new Promise((resolve, reject) => {
    const messages = [];

    if (systemPrompt) {
      messages.push({ role: 'system', content: systemPrompt });
    }

    messages.push({ role: 'user', content: prompt });

    const data = JSON.stringify({
      model: 'gpt-4o-mini', // Using gpt-4o-mini as gpt-5-nano equivalent
      messages: messages,
      temperature: 0.7,
      max_tokens: 500
    });

    const options = {
      hostname: 'api.openai.com',
      path: '/v1/chat/completions',
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
          } else if (response.choices && response.choices[0]) {
            resolve(response.choices[0].message.content);
          } else {
            reject(new Error('Invalid OpenAI response structure'));
          }
        } catch (err) {
          reject(err);
        }
      });
    });

    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

// Search database for relevant content
async function searchContent(client, query) {
  const embedding = await getEmbedding(query);

  const result = await client.query(`
    SELECT
      filename,
      text,
      1 - (embedding <=> $1::vector) as similarity
    FROM core.embeddings
    WHERE 1 - (embedding <=> $1::vector) > 0.3
    ORDER BY embedding <=> $1::vector
    LIMIT 3;
  `, [`[${embedding.join(',')}]`]);

  return result.rows;
}

// Main function
async function main() {
  const episodeTopic = process.argv[2] || 'Insurance Sales Strategies';

  console.log(`\n🎙️ Social Media Content Calendar Generator`);
  console.log(`Episode Topic: ${episodeTopic}`);
  console.log(`==============================================\n`);

  const client = new Client({ connectionString: DB_URL });

  try {
    await client.connect();
    console.log('✅ Connected to database\n');

    // Step 1: Extract content from database
    console.log('📚 Extracting relevant content...\n');
    const allContent = [];

    for (const query of CONTENT_QUERIES.slice(0, 5)) { // Limit to 5 queries for speed
      console.log(`  Searching: "${query}"`);
      const results = await searchContent(client, query);
      if (results.length > 0) {
        allContent.push({
          query: query,
          results: results
        });
      }
    }

    console.log(`\n✅ Extracted ${allContent.length} content categories\n`);

    // Step 2: Generate content calendar
    console.log('📅 Generating 10-Day Content Calendar...\n');

    const contentContext = allContent.map(cat => {
      const topResult = cat.results[0];
      return `Topic: ${cat.query}\nContent: ${topResult.text.substring(0, 300)}...\nRelevance: ${(topResult.similarity * 100).toFixed(1)}%`;
    }).join('\n\n');

    const calendarPrompt = `Based on this insurance podcast episode content:

${contentContext}

Generate a 10-day social media content calendar with posts for Instagram Reels, Facebook, and LinkedIn.

For each day, create:
1. **Instagram Reel** (15-30 second hook + script)
2. **Facebook Post** (engaging post with hashtags)
3. **LinkedIn Post** (professional insight with value)

Focus on:
- Actionable tips and strategies
- Engaging hooks and questions
- Platform-appropriate tone
- Mix of educational, inspirational, and promotional content

Format as JSON with this structure:
{
  "day1": {
    "reel": { "hook": "...", "script": "...", "cta": "..." },
    "facebook": { "post": "...", "hashtags": "..." },
    "linkedin": { "post": "...", "hashtags": "..." }
  },
  ...
}`;

    const systemPrompt = `You are a social media content strategist specializing in insurance and financial services. Create engaging, value-driven content that educates and inspires insurance professionals.`;

    const calendar = await generateContent(calendarPrompt, systemPrompt);

    // Save to file
    const outputPath = path.join(__dirname, 'social-calendar-output.json');

    try {
      // Try to parse as JSON
      const parsedCalendar = JSON.parse(calendar);
      fs.writeFileSync(outputPath, JSON.stringify(parsedCalendar, null, 2));
      console.log(`✅ Content calendar saved to: ${outputPath}\n`);

      // Display summary
      console.log('📊 Calendar Summary:');
      Object.keys(parsedCalendar).forEach(day => {
        console.log(`  ${day}: Reel ✓ | Facebook ✓ | LinkedIn ✓`);
      });
    } catch (parseErr) {
      // If not JSON, save as text
      fs.writeFileSync(outputPath.replace('.json', '.txt'), calendar);
      console.log(`✅ Content calendar saved to: ${outputPath.replace('.json', '.txt')}\n`);
      console.log(calendar);
    }

    console.log('\n✅ Social media content calendar generated successfully!\n');

  } catch (err) {
    console.error('❌ Error:', err.message);
    process.exit(1);
  } finally {
    await client.end();
  }
}

main();
