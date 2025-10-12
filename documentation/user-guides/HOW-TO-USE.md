# 🎙️ Insurance Dudes Podcast → Social Media Content Generator

## What This Does

Automatically generates a **10-day social media content calendar** from your podcast episodes with content for:
- 📱 Instagram Reels (hooks, scripts, CTAs)
- 📘 Facebook Posts (engaging, conversational)
- 💼 LinkedIn Posts (professional, thought leadership)

All written in **Craig & Jason's authentic voice** - no generic corporate BS!

## Quick Start

### 1. Add Podcast Episode to Database

First, upload your podcast transcript to Google Drive → RAG-Pending folder. The workflow will automatically:
- Extract text from the file
- Chunk it for optimal search
- Create embeddings
- Store in PostgreSQL database

**OR** manually insert content:
```bash
# Upload .txt, .md, or .pdf file to Google Drive RAG-Pending folder
# Workflow runs every 17 minutes automatically
```

### 2. Generate Social Calendar

```bash
node generate-episode-content.js "Your Episode Title Here"
```

**Example:**
```bash
node generate-episode-content.js "How to 10x Your Insurance Leads Without Spending More"
```

### 3. Get Your Content

Output saved to: `social-calendar-YYYY-MM-DD.md`

Contains:
- ✅ 10 days of content
- ✅ 3 posts per day (IG Reel, Facebook, LinkedIn)
- ✅ Written in Craig & Jason's voice
- ✅ Hashtags included
- ✅ Ready to copy/paste

## Example Output Structure

```markdown
**DAY 1: Hook - Most shocking insight**

📱 INSTAGRAM REEL:
Hook: "Real talk - internet leads don't suck. Your follow-up does..."
Script: [Punchy 15-30 sec content]
CTA: "Link in bio for the full breakdown 🔥"
Hashtags: #InsuranceDudes #LeadGeneration...

📘 FACEBOOK POST:
[Engaging conversational post with emojis]
Hashtags: ...

💼 LINKEDIN POST:
[Professional insight with credibility]
Hashtags: ...
```

## Testing Semantic Search

Want to see what content is available in your database?

```bash
# Test semantic search
node test-semantic-search.js "your search query here"

# Examples:
node test-semantic-search.js "overcoming sales objections"
node test-semantic-search.js "lead generation strategies"
node test-semantic-search.js "building client trust"
```

## Content Themes (10-Day Structure)

1. **Hook** - Most shocking/surprising insight
2. **Tip #1** - Actionable strategy
3. **Challenge** - Problem addressed
4. **Solution** - Hack revealed
5. **Case Study** - Success story
6. **Mindset** - Motivation
7. **Tip #2** - Advanced technique
8. **Industry Insight** - Trend/data
9. **CTA Teaser** - Episode promotion
10. **Recap** - Episode summary + CTA

## Voice Profile

Content is generated using Craig & Jason's authentic voice:
- ✅ Direct, conversational (like talking to a friend)
- ✅ Real talk, no BS
- ✅ Mix of bro energy + expert credibility
- ✅ Story-driven over stat-driven
- ✅ Actionable > motivational platitudes
- ❌ NO generic corporate speak
- ❌ NO fake positivity
- ❌ NO cheesy motivational quotes

See: `craig-jason-voice-profile.md` for full details

## Files Overview

```
generate-episode-content.js       # Main content generator
test-semantic-search.js           # Test database search
craig-jason-voice-profile.md      # Voice/tone guidelines
HOW-TO-USE.md                     # This file
.env                              # API keys (OpenAI)
```

## Troubleshooting

### "No content found in database"
→ Make sure podcast transcripts are uploaded and processed first
→ Check Google Drive workflow is running
→ Verify embeddings exist: `psql ... -c "SELECT COUNT(*) FROM core.embeddings;"`

### "Low similarity matches"
→ Try broader search terms
→ May need more podcast content in database
→ Check that episode content is relevant to search

### "Generic voice, not Craig & Jason"
→ Voice profile is loaded from `craig-jason-voice-profile.md`
→ Make sure file exists and contains their style guide
→ AI will adapt based on examples provided

## Next Steps

1. **Upload more podcast episodes** → Better content extraction
2. **Customize voice profile** → Edit `craig-jason-voice-profile.md` with specific phrases
3. **Batch process** → Generate calendars for multiple episodes at once
4. **GoHighLevel integration** → Auto-post to social (coming soon)

## Support

Need help? Check the workflow status:
- Google Drive: ai.thirdeyediagnostics.com
- Database: Railway PostgreSQL
- Embeddings: `SELECT * FROM core.embeddings LIMIT 5;`

---

**Made for Insurance Dudes by Insurance Dudes** 🎙️🔥
