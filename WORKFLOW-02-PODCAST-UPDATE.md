# Update Workflow 02 for Podcast Support

## What Needs to Change

Workflow 02 (`02-DocumentUpload&Vectorization.json`) needs to handle podcast metadata when episodes are sent from workflow 09.

---

## Update PrepDoc Node

**Location:** Workflow 02, PrepDoc node (Code node after webhook)

**Add this code after line that extracts source:**

```javascript
// Extract podcast metadata if present (from workflow 09)
const podcastMeta = input.json.body?.podcast_metadata || {};
const isPodcast = source === 'podcast-automation' ||
                  Object.keys(podcastMeta).length > 0;
```

**Replace the metadata return section with:**

```javascript
return [{
  json: {
    pageContent: content,
    metadata: {
      filename: filename,
      file_type: file_type,
      file_size: file_size || content.length,
      source: source,
      timestamp: new Date().toISOString(),
      upload_source: 'webhook',
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
  }
}];
```

---

## Update map Node

**Location:** Workflow 02, map node (normalizes data for PGVector)

**Replace metadata section with:**

```javascript
const mapped = {
  pageContent,
  metadata: {
    filename: md.filename ?? 'unknown',
    file_type: md.file_type ?? 'text/plain',
    file_size: toInt(md.file_size ?? pageContent.length),
    source: md.source ?? 'idudesRAG-upload',
    timestamp: asIso(md.timestamp),
    upload_source: md.upload_source ?? 'webhook',
    // Podcast fields
    document_type: md.document_type ?? 'document',
    language: md.language ?? 'en',
    episode_id: md.episode_id ?? null,
    episode_title: md.episode_title ?? null,
    podcast_guid: md.podcast_guid ?? null,
    show_name: md.show_name ?? null,
    published_at: md.published_at ?? null,
    audio_url: md.audio_url ?? null,
    duration_seconds: md.duration_seconds ?? null,
    ...(document_id ? { document_id } : {})
  }
};
```

---

## Update DocLoader Metadata Values

**Location:** Workflow 02, DocLoader node

**Add these metadata rows:**

| Name | Value |
|------|-------|
| document_type | `{{ $('map').first().json.metadata.document_type }}` |
| language | `{{ $('map').first().json.metadata.language }}` |
| episode_id | `{{ $('map').first().json.metadata.episode_id }}` |
| episode_title | `{{ $('map').first().json.metadata.episode_title }}` |
| podcast_guid | `{{ $('map').first().json.metadata.podcast_guid }}` |
| show_name | `{{ $('map').first().json.metadata.show_name }}` |
| published_at | `{{ $('map').first().json.metadata.published_at }}` |
| audio_url | `{{ $('map').first().json.metadata.audio_url }}` |
| duration_seconds | `{{ $('map').first().json.metadata.duration_seconds }}` |

---

## Complete PrepDoc Node Code (Full Replacement)

```javascript
const input = $input.first();
let content = '';
let filename = 'unknown';
let file_type = 'text/plain';
let file_size = 0;
let source = 'idudesRAG-upload';

// Extract metadata from webhook BODY
if (input.json.body?.filename) filename = input.json.body.filename;
if (input.json.body?.type) file_type = input.json.body.type;
if (input.json.body?.size) file_size = parseInt(input.json.body.size);
if (input.json.body?.source) source = input.json.body.source;

// Extract podcast metadata if present (from workflow 09)
const podcastMeta = input.json.body?.podcast_metadata || {};
const isPodcast = source === 'podcast-automation' ||
                  Object.keys(podcastMeta).length > 0;

// Extract and DECODE content from body
if (input.json.body?.content) {
  content = input.json.body.content;
  // DECODE if base64 encoded
  if (content && /^[A-Za-z0-9+/=]+$/.test(content) && content.length > 50) {
    try {
      content = Buffer.from(content, 'base64').toString('utf-8');
    } catch (e) {
      // Not base64, keep original
    }
  }
}

return [{
  json: {
    pageContent: content,
    metadata: {
      filename: filename,
      file_type: file_type,
      file_size: file_size || content.length,
      source: source,
      timestamp: new Date().toISOString(),
      upload_source: 'webhook',
      // Podcast-specific fields (null for regular documents)
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
  }
}];
```

---

## Testing

### Test with Regular Document Upload

```bash
curl -X POST https://ai.thirdeyediagnostics.com/webhook/documents \
  -H "Content-Type: application/json" \
  -d '{
    "filename": "test.txt",
    "content": "VGVzdCBkb2N1bWVudA==",
    "type": "text/plain",
    "size": 100,
    "source": "ui-upload"
  }'
```

**Expected metadata:**
```json
{
  "document_type": "document",
  "language": "en",
  "episode_id": null,
  "podcast_guid": null
}
```

### Test with Podcast Upload (from workflow 09)

Workflow 09 automatically sends podcast metadata. The webhook will receive:

```json
{
  "filename": "Episode 123 - Title.txt",
  "content": "base64_encoded_transcript...",
  "type": "text/plain",
  "size": 50000,
  "source": "podcast-automation",
  "podcast_metadata": {
    "show_name": "The Insurance Dudes",
    "episode_number": "123",
    "episode_title": "Title",
    "guid": "...",
    "language": "en"
  }
}
```

**Expected metadata:**
```json
{
  "document_type": "transcript",
  "language": "en",
  "episode_id": "123",
  "episode_title": "Title",
  "podcast_guid": "...",
  "show_name": "The Insurance Dudes"
}
```

---

## Verify in Database

```sql
-- Check podcast episode was stored
SELECT
  filename,
  metadata->>'document_type' as type,
  metadata->>'episode_id' as episode,
  metadata->>'show_name' as show,
  created_at
FROM core.documents
WHERE metadata->>'source' = 'podcast-automation'
ORDER BY created_at DESC
LIMIT 1;

-- Check embeddings have podcast metadata
SELECT
  metadata->>'filename' as filename,
  metadata->>'episode_id' as episode,
  metadata->>'show_name' as show,
  COUNT(*) as chunks
FROM core.document_embeddings
WHERE metadata->>'source' = 'podcast-automation'
GROUP BY
  metadata->>'filename',
  metadata->>'episode_id',
  metadata->>'show_name'
ORDER BY metadata->>'episode_id' DESC;
```

---

## Summary of Changes

1. ✅ **PrepDoc node**: Detects podcast_metadata, sets document_type='transcript'
2. ✅ **map node**: Passes through all podcast fields
3. ✅ **DocLoader node**: Adds 9 podcast metadata fields to embeddings

**Result:** Both regular documents and podcast transcripts work through the same workflow, auto-detected by presence of `podcast_metadata` field.
