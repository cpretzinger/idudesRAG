# Podcast Auto-Ingestion Workflow - Insurance Dudes

**Spotify Show:** https://open.spotify.com/show/2gVVPkZ2MWQ1orwdltdIAK
**RSS Feed:** https://feeds.buzzsprout.com/254746.rss
**Show ID:** `2gVVPkZ2MWQ1orwdltdIAK`

---

## Why RSS Instead of Spotify API?

**Spotify API limitations:**
- ✅ Can get episode metadata (title, description, release date)
- ❌ Cannot download audio files (only playback via Spotify player)
- ❌ No direct MP3 URLs

**RSS Feed advantages:**
- ✅ Contains direct MP3 download URLs in `<enclosure>` tags
- ✅ No authentication required
- ✅ Standard podcast format

**Solution:** Use RSS feed for audio download + transcription

---

## Workflow Overview

```
Schedule Trigger (every 6 hours)
  ↓
RSS Feed Read (Insurance Dudes)
  ↓
Check for New Episodes (compare with DB)
  ↓
Download MP3 Audio
  ↓
Transcribe with OpenAI Whisper
  ↓
Send to /webhook/documents (auto-embeddings)
```

---

## Node 1: Schedule Trigger

**Node Type:** Schedule Trigger
**Interval:** Every 6 hours

```json
{
  "parameters": {
    "rule": {
      "interval": [
        {
          "field": "hours",
          "hoursInterval": 6
        }
      ]
    }
  },
  "type": "n8n-nodes-base.scheduleTrigger",
  "typeVersion": 1.2
}
```

---

## Node 2: RSS Feed Read

**Node Type:** RSS Feed Read
**URL:** `https://feeds.buzzsprout.com/254746.rss`

```json
{
  "parameters": {
    "url": "https://feeds.buzzsprout.com/254746.rss"
  },
  "type": "n8n-nodes-base.rssFeedRead",
  "typeVersion": 1
}
```

**Output per episode:**
- `title` - Episode title
- `link` - Episode URL
- `pubDate` - Publication date
- `enclosure.url` - MP3 download URL
- `content` - Episode description
- `guid` - Unique episode ID

---

## Node 3: Check for New Episodes

**Node Type:** Code (JavaScript)

```javascript
// Check if episode already processed
const episodes = $input.all().map(item => item.json);
const { Client } = require('pg');

const client = new Client({
  connectionString: 'postgres://postgres:d7ToQHAA7VecTKi2DxFgNxtlj~xN_HnD@yamabiko.proxy.rlwy.net:15649/railway'
});

try {
  await client.connect();

  const newEpisodes = [];

  for (const episode of episodes) {
    const guid = episode.guid || episode.link;
    const title = episode.title;

    // Check if already exists in DB
    const result = await client.query(
      "SELECT id FROM core.documents WHERE metadata->>'podcast_guid' = $1",
      [guid]
    );

    if (result.rows.length === 0) {
      // New episode - add to processing queue
      console.log(`New episode found: ${title}`);
      newEpisodes.push(episode);
    } else {
      console.log(`Episode already processed: ${title}`);
    }
  }

  return newEpisodes.map(ep => ({ json: ep }));

} finally {
  await client.end();
}
```

---

## Node 4: Extract Episode Info

**Node Type:** Code (JavaScript)

```javascript
// Extract and format episode metadata
const episode = $input.first().json;

// Extract episode number from title (e.g., "Episode 123: Title" → "123")
const episodeMatch = episode.title.match(/episode[\s#]*(\d+)/i);
const episodeNumber = episodeMatch ? episodeMatch[1] : null;

// Get MP3 URL
const audioUrl = episode.enclosure?.url || episode['media:content']?.url;

if (!audioUrl) {
  throw new Error(`No audio URL found for episode: ${episode.title}`);
}

// Format date
const pubDate = new Date(episode.pubDate || episode.published);

return [{
  json: {
    title: episode.title,
    description: episode.content || episode.description || '',
    audioUrl: audioUrl,
    episodeNumber: episodeNumber,
    guid: episode.guid || episode.link,
    publishedAt: pubDate.toISOString(),
    showName: 'The Insurance Dudes',
    showId: '2gVVPkZ2MWQ1orwdltdIAK'
  }
}];
```

---

## Node 5: Download Audio

**Node Type:** HTTP Request
**Method:** GET
**URL:** `{{ $json.audioUrl }}`

```json
{
  "parameters": {
    "method": "GET",
    "url": "={{ $json.audioUrl }}",
    "options": {
      "response": {
        "response": {
          "responseFormat": "file"
        }
      }
    }
  },
  "type": "n8n-nodes-base.httpRequest",
  "typeVersion": 4.2
}
```

---

## Node 6: Transcribe with OpenAI Whisper

**Node Type:** Code (JavaScript)

```javascript
// Transcribe audio with OpenAI Whisper API
const audioData = $input.first().binary.data;
const metadata = $('Extract Episode Info').first().json;

// Create form data for Whisper API
const FormData = require('form-data');
const form = new FormData();

// Convert binary data to buffer
const audioBuffer = Buffer.from(audioData.data, 'base64');
form.append('file', audioBuffer, {
  filename: `episode_${metadata.episodeNumber || 'unknown'}.mp3`,
  contentType: 'audio/mpeg'
});
form.append('model', 'whisper-1');
form.append('language', 'en');
form.append('response_format', 'verbose_json');
form.append('timestamp_granularities[]', 'segment');

// Call Whisper API
const response = await fetch('https://api.openai.com/v1/audio/transcriptions', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${$credentials.openAiApi.apiKey}`,
    ...form.getHeaders()
  },
  body: form
});

const transcription = await response.json();

if (!transcription.text) {
  throw new Error('Transcription failed: ' + JSON.stringify(transcription));
}

return [{
  json: {
    transcript: transcription.text,
    segments: transcription.segments || [],
    duration: transcription.duration || 0,
    language: transcription.language || 'en',
    metadata: metadata
  }
}];
```

---

## Node 7: Format for Document Upload

**Node Type:** Code (JavaScript)

```javascript
// Format transcript for /webhook/documents endpoint
const data = $input.first().json;
const metadata = data.metadata;

// Create filename
const filename = metadata.episodeNumber
  ? `Episode ${metadata.episodeNumber} - ${metadata.title}.txt`
  : `${metadata.title}.txt`;

// Format transcript with timestamps (if available)
let formattedContent = `# ${metadata.title}\n\n`;
formattedContent += `**Show:** ${metadata.showName}\n`;
formattedContent += `**Episode:** ${metadata.episodeNumber || 'N/A'}\n`;
formattedContent += `**Published:** ${new Date(metadata.publishedAt).toLocaleDateString()}\n`;
formattedContent += `**Duration:** ${Math.floor(data.duration / 60)} minutes\n\n`;
formattedContent += `## Description\n\n${metadata.description}\n\n`;
formattedContent += `## Transcript\n\n${data.transcript}`;

// Convert to base64
const base64Content = Buffer.from(formattedContent).toString('base64');

return [{
  json: {
    filename: filename,
    content: base64Content,
    type: 'text/plain',
    size: formattedContent.length,
    source: 'podcast-automation',
    podcast_metadata: {
      show_name: metadata.showName,
      show_id: metadata.showId,
      episode_number: metadata.episodeNumber,
      episode_title: metadata.title,
      published_at: metadata.publishedAt,
      duration_seconds: data.duration,
      guid: metadata.guid,
      audio_url: metadata.audioUrl,
      language: data.language
    }
  }
}];
```

---

## Node 8: Send to Document Webhook

**Node Type:** HTTP Request
**Method:** POST
**URL:** `https://ai.thirdeyediagnostics.com/webhook/documents`

```json
{
  "parameters": {
    "method": "POST",
    "url": "https://ai.thirdeyediagnostics.com/webhook/documents",
    "sendHeaders": true,
    "headerParameters": {
      "parameters": [
        {
          "name": "Content-Type",
          "value": "application/json"
        }
      ]
    },
    "sendBody": true,
    "bodyParameters": {
      "parameters": [
        {
          "name": "filename",
          "value": "={{ $json.filename }}"
        },
        {
          "name": "content",
          "value": "={{ $json.content }}"
        },
        {
          "name": "type",
          "value": "={{ $json.type }}"
        },
        {
          "name": "size",
          "value": "={{ $json.size }}"
        },
        {
          "name": "source",
          "value": "={{ $json.source }}"
        },
        {
          "name": "podcast_metadata",
          "value": "={{ JSON.stringify($json.podcast_metadata) }}"
        }
      ]
    }
  },
  "type": "n8n-nodes-base.httpRequest",
  "typeVersion": 4.2
}
```

**Alternative (simpler):**

```javascript
// Use HTTP Request node with JSON body
{
  "method": "POST",
  "url": "https://ai.thirdeyediagnostics.com/webhook/documents",
  "sendBody": true,
  "specifyBody": "json",
  "jsonBody": "={{ JSON.stringify($json) }}"
}
```

---

## Node 9: Log Success

**Node Type:** Code (JavaScript)

```javascript
// Log successful processing
const response = $input.first().json;
const metadata = $('Format for Document Upload').first().json;

console.log('✅ Podcast episode processed:', {
  episode: metadata.podcast_metadata.episode_title,
  episodeNumber: metadata.podcast_metadata.episode_number,
  documentId: response.id || 'unknown',
  timestamp: new Date().toISOString()
});

return [{
  json: {
    success: true,
    episode: metadata.podcast_metadata.episode_title,
    episodeNumber: metadata.podcast_metadata.episode_number,
    filename: metadata.filename,
    uploadResponse: response
  }
}];
```

---

## Workflow Connections

```
Schedule Trigger
  ↓
RSS Feed Read
  ↓
Check for New Episodes
  ↓
Extract Episode Info
  ↓
Download Audio
  ↓
Transcribe with OpenAI Whisper
  ↓
Format for Document Upload
  ↓
Send to Document Webhook
  ↓
Log Success
```

---

## Cost Estimates

### OpenAI Whisper Pricing
- **Cost:** $0.006 per minute
- **Average podcast:** 60 minutes
- **Cost per episode:** ~$0.36

### Monthly Costs (1 episode/day)
- Transcription: 30 × $0.36 = **$10.80/month**
- Embeddings: 30 × ~$0.02 = **$0.60/month**
- **Total: ~$11.40/month**

---

## Update PrepDoc Node for Podcasts

**Add to workflow 02 PrepDoc node:**

```javascript
// Detect if this is a podcast transcript
const isPodcast = source === 'podcast-automation' ||
                  filename.toLowerCase().includes('episode');

// Extract podcast metadata if present
const podcastMeta = input.json?.podcast_metadata || {};

metadata: {
  filename: filename,
  file_type: file_type,
  file_size: file_size || content.length,
  source: source,
  timestamp: new Date().toISOString(),
  upload_source: upload_source,
  // Podcast-specific fields
  document_type: isPodcast ? 'transcript' : 'document',
  language: podcastMeta.language || 'en',
  episode_id: podcastMeta.episode_number?.toString() || null,
  episode_title: podcastMeta.episode_title || null,
  podcast_guid: podcastMeta.guid || null,
  show_name: podcastMeta.show_name || null,
  published_at: podcastMeta.published_at || null,
  audio_url: podcastMeta.audio_url || null,
  duration_seconds: podcastMeta.duration_seconds || null
}
```

---

## Testing

### Manual Test

1. **Trigger workflow manually**
2. **Check n8n logs** for RSS feed parsing
3. **Verify new episode detected** (should skip already-processed)
4. **Monitor Whisper API call** (can take 2-5 minutes)
5. **Check webhook response** for document ID

### Verify in Database

```sql
-- Check podcast episodes
SELECT
  filename,
  metadata->>'episode_id' as episode,
  metadata->>'show_name' as show,
  metadata->>'document_type' as type,
  created_at
FROM core.documents
WHERE metadata->>'source' = 'podcast-automation'
ORDER BY created_at DESC;

-- Check embeddings
SELECT
  metadata->>'filename' as filename,
  metadata->>'episode_id' as episode,
  COUNT(*) as chunks
FROM core.document_embeddings
WHERE metadata->>'source' = 'podcast-automation'
GROUP BY metadata->>'filename', metadata->>'episode_id'
ORDER BY metadata->>'episode_id' DESC;
```

---

## Error Handling

### Add Error Handling Node (After Each Critical Step)

```javascript
// Wrap critical operations in try-catch
try {
  // Operation code here

} catch (error) {
  console.error('Error processing podcast:', {
    step: 'transcription',
    episode: $json.title,
    error: error.message
  });

  // Send error notification (optional)
  // Could send to Slack, email, etc.

  return [];  // Skip this episode, continue with next
}
```

---

## Optimization Options

### 1. Parallel Processing

If multiple new episodes, process in parallel:
- Use Split In Batches node
- Set batch size = 3 (don't overwhelm Whisper API)

### 2. Faster Transcription Alternative

**AssemblyAI** (faster than Whisper):
- Cost: $0.00025/second (~$0.90/hour)
- Speed: 15% of audio length (60min audio = 9min transcription)
- Better speaker diarization

### 3. Resume Failed Transcriptions

Add database tracking for in-progress transcriptions to resume if workflow fails midway.

---

## Production Checklist

- [ ] Set schedule trigger interval (recommend 6-12 hours)
- [ ] Test with 1 old episode first
- [ ] Verify embeddings created correctly
- [ ] Set up error notifications (Slack/email)
- [ ] Monitor Whisper API costs
- [ ] Add retry logic for failed transcriptions
- [ ] Implement progress tracking in database
