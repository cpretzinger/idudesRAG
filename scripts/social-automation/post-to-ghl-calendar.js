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
const GHL_API_KEY = process.env.GHL_API_KEY || process.env.GOHIGHLEVEL_API_KEY;
const GHL_LOCATION_ID = process.env.GHL_LOCATION_ID;
const DB_URL = 'postgres://postgres:d7ToQHAA7VecTKi2DxFgNxtlj~xN_HnD@yamabiko.proxy.rlwy.net:15649/railway';

// Content extraction queries
const CONTENT_QUERIES = [
  "actionable insurance sales tips and strategies",
  "overcoming client objections and challenges",
  "lead generation and prospecting tactics",
  "building trust and credibility with clients",
  "client success stories and case studies"
];

// Helper: Make HTTPS request
function makeRequest(options, data = null) {
  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => { body += chunk; });
      res.on('end', () => {
        try {
          const response = JSON.parse(body);
          if (res.statusCode >= 400) {
            reject(new Error(`HTTP ${res.statusCode}: ${response.error || body}`));
          } else {
            resolve(response);
          }
        } catch (err) {
          if (res.statusCode >= 400) {
            reject(new Error(`HTTP ${res.statusCode}: ${body}`));
          } else {
            resolve(body);
          }
        }
      });
    });

    req.on('error', reject);
    if (data) {
      req.write(typeof data === 'string' ? data : JSON.stringify(data));
    }
    req.end();
  });
}

// Get embedding from OpenAI
async function getEmbedding(text) {
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

  const response = await makeRequest(options, data);
  return response.data[0].embedding;
}

// Generate content using OpenAI
async function generateContent(prompt, systemPrompt = null) {
  const messages = [];
  if (systemPrompt) {
    messages.push({ role: 'system', content: systemPrompt });
  }
  messages.push({ role: 'user', content: prompt });

  const data = JSON.stringify({
    model: 'gpt-4o-mini',
    messages: messages,
    temperature: 0.7,
    max_tokens: 2000
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

  const response = await makeRequest(options, data);
  return response.choices[0].message.content;
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
    LIMIT 2;
  `, [`[${embedding.join(',')}]`]);

  return result.rows;
}

// Post to GoHighLevel Social Planner
async function postToGHL(post, scheduledDate) {
  if (!GHL_API_KEY || !GHL_LOCATION_ID) {
    console.warn('⚠️  GHL_API_KEY or GHL_LOCATION_ID not configured - skipping GHL post');
    return null;
  }

  const postData = {
    locationId: GHL_LOCATION_ID,
    message: post.content,
    scheduledAt: scheduledDate.toISOString(),
    platforms: post.platforms || ['facebook', 'linkedin', 'instagram']
  };

  const options = {
    hostname: 'services.leadconnectorhq.com',
    path: '/social-media-posting/posts',
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${GHL_API_KEY}`,
      'Content-Type': 'application/json',
      'Version': '2021-07-28'
    }
  };

  try {
    const response = await makeRequest(options, postData);
    return response;
  } catch (err) {
    console.error(`❌ GHL API Error: ${err.message}`);
    return null;
  }
}

// Main function
async function main() {
  const episodeTopic = process.argv[2] || 'Insurance Sales Strategies';
  const startDate = new Date();
  startDate.setDate(startDate.getDate() + 1); // Start tomorrow

  console.log(`\n🎙️ Insurance Podcast → GoHighLevel Social Calendar`);
  console.log(`Episode: ${episodeTopic}`);
  console.log(`Start Date: ${startDate.toDateString()}`);
  console.log(`=======================================================\n`);

  const client = new Client({ connectionString: DB_URL });

  try {
    await client.connect();
    console.log('✅ Connected to database\n');

    // Extract content from database
    console.log('📚 Extracting podcast insights...\n');
    const allContent = [];

    for (const query of CONTENT_QUERIES) {
      const results = await searchContent(client, query);
      if (results.length > 0) {
        allContent.push({
          query: query,
          content: results[0].text.substring(0, 400)
        });
      }
    }

    console.log(`✅ Extracted ${allContent.length} key insights\n`);

    // Generate content calendar
    console.log('📅 Generating 10-day content calendar...\n');

    const contentContext = allContent.map(cat =>
      `${cat.query}:\n${cat.content}...`
    ).join('\n\n');

    const calendarPrompt = `Based on this insurance podcast episode: "${episodeTopic}"

Content insights:
${contentContext}

Create a 10-day social media content calendar with 3 posts per day (one for each platform).

Return ONLY valid JSON (no markdown, no \`\`\`):
{
  "day1": [
    {
      "platform": "instagram_reel",
      "hook": "...",
      "script": "...",
      "cta": "...",
      "hashtags": "..."
    },
    {
      "platform": "facebook",
      "content": "...",
      "hashtags": "..."
    },
    {
      "platform": "linkedin",
      "content": "...",
      "hashtags": "..."
    }
  ],
  "day2": [...],
  ...
  "day10": [...]
}

Requirements:
- Instagram Reels: 15-30 sec hook + script + CTA
- Facebook: Engaging, casual tone with emojis
- LinkedIn: Professional insights, thought leadership
- Mix tips, quotes, challenges, case studies, motivation
- Each day should have a unique theme
- Include 5-8 relevant hashtags per post`;

    const systemPrompt = `You are an expert social media strategist for insurance professionals. Create engaging, actionable content that drives engagement and provides real value. Return ONLY valid JSON, no markdown formatting.`;

    let calendarJSON = await generateContent(calendarPrompt, systemPrompt);

    // Clean up markdown formatting if present
    calendarJSON = calendarJSON
      .replace(/```json\n?/g, '')
      .replace(/```\n?/g, '')
      .replace(/^[^{]*/, '')  // Remove text before first {
      .replace(/[^}]*$/, '')  // Remove text after last }
      .trim();

    let calendar;
    try {
      calendar = JSON.parse(calendarJSON);
    } catch (parseErr) {
      console.error('❌ JSON Parse Error:', parseErr.message);
      console.error('Response length:', calendarJSON.length);

      // Save raw response for debugging
      fs.writeFileSync('debug-calendar-response.txt', calendarJSON);
      console.error('Full response saved to: debug-calendar-response.txt');

      throw parseErr;
    }

    console.log('✅ Generated 10-day calendar\n');

    // Save calendar locally
    const outputPath = path.join(__dirname, 'ghl-social-calendar.json');
    fs.writeFileSync(outputPath, JSON.stringify(calendar, null, 2));
    console.log(`💾 Saved calendar to: ${outputPath}\n`);

    // Post to GoHighLevel
    if (GHL_API_KEY && GHL_LOCATION_ID) {
      console.log('📤 Posting to GoHighLevel Social Planner...\n');

      let posted = 0;
      for (const [day, posts] of Object.entries(calendar)) {
        const dayNum = parseInt(day.replace('day', ''));
        const postDate = new Date(startDate);
        postDate.setDate(postDate.getDate() + dayNum - 1);
        postDate.setHours(9 + Math.floor(posted / 3) * 4, 0, 0); // Stagger times

        for (const post of posts) {
          let content = '';
          let platforms = [];

          if (post.platform === 'instagram_reel') {
            content = `${post.hook}\n\n${post.script}\n\n${post.cta}\n\n${post.hashtags}`;
            platforms = ['instagram'];
          } else if (post.platform === 'facebook') {
            content = `${post.content}\n\n${post.hashtags}`;
            platforms = ['facebook'];
          } else if (post.platform === 'linkedin') {
            content = `${post.content}\n\n${post.hashtags}`;
            platforms = ['linkedin'];
          }

          const ghlPost = {
            content: content,
            platforms: platforms
          };

          const result = await postToGHL(ghlPost, postDate);
          if (result) {
            console.log(`  ✅ ${day} - ${post.platform} - Scheduled for ${postDate.toLocaleString()}`);
            posted++;
          }

          postDate.setHours(postDate.getHours() + 3); // 3 hours between posts
        }
      }

      console.log(`\n✅ Posted ${posted} items to GoHighLevel!\n`);
    } else {
      console.log('⚠️  GoHighLevel credentials not configured. Set GHL_API_KEY and GHL_LOCATION_ID in .env\n');
      console.log('📋 Calendar Preview:\n');

      Object.entries(calendar).slice(0, 2).forEach(([day, posts]) => {
        console.log(`\n${day.toUpperCase()}:`);
        posts.forEach(post => {
          console.log(`  📱 ${post.platform}:`);
          if (post.hook) console.log(`     Hook: ${post.hook}`);
          if (post.content) console.log(`     ${post.content.substring(0, 100)}...`);
        });
      });
      console.log('\n  ... (8 more days)\n');
    }

    console.log('✅ Process completed!\n');

  } catch (err) {
    console.error('❌ Error:', err.message);
    if (err.stack) console.error(err.stack);
    process.exit(1);
  } finally {
    await client.end();
  }
}

main();
