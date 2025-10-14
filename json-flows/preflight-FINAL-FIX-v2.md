# Preflight - FINAL FIX v2 (Gate Ready Fixed)

## Issue: Gate Ready wasn't handling Postgres array results

---

## NODE 1: Get Episode Data (SAME - No changes)

```json
{
  "parameters": {
    "operation": "executeQuery",
    "query": "SELECT \n  fs.file_id,\n  fs.filename,\n  fs.status,\n  fs.chunks_count as total_chunks,\n  COUNT(e.id)::int as count\nFROM core.file_status fs\nLEFT JOIN core.embeddings e ON e.file_id = fs.file_id\nWHERE fs.file_id = $1\nGROUP BY fs.file_id, fs.filename, fs.status, fs.chunks_count;",
    "options": {
      "queryReplacement": "={{ [$json.file_id] }}"
    }
  },
  "id": "NEW-GET-EPISODE-DATA",
  "name": "Get Episode Data",
  "type": "n8n-nodes-base.postgres",
  "typeVersion": 2,
  "position": [-304, 96],
  "credentials": {
    "postgres": {
      "id": "9YUzCl4JCgWCDD57",
      "name": "RAG_READ_KEY"
    }
  }
}
```

---

## NODE 2: Gate Ready (FIXED - Returns proper array)

```json
{
  "parameters": {
    "jsCode": "// Postgres returns data in $json, handle both single object and array\nconst data = Array.isArray($json) ? $json[0] : $json;\n\nconst status = data?.status;\nconst count = Number(data?.count || 0);\nconst file_id = data?.file_id;\nconst filename = data?.filename;\nconst total_chunks = Number(data?.total_chunks || 0);\n\nconsole.log('=== Gate Ready Check ===');\nconsole.log('file_id:', file_id);\nconsole.log('filename:', filename);\nconsole.log('status:', status);\nconsole.log('count:', count);\nconsole.log('total_chunks:', total_chunks);\n\n// Validation: must have file_id\nif (!file_id) {\n  console.log('❌ No file_id - returning empty array');\n  return [];\n}\n\n// Check BOTH conditions\nconst isReady = (status === 'completed' && count > 0);\n\nif (!isReady) {\n  console.log('❌ Not ready:');\n  console.log('  - status === completed?', status === 'completed', '(actual:', status, ')');\n  console.log('  - count > 0?', count > 0, '(actual:', count, ')');\n  return [];\n}\n\nconsole.log('✅ READY - proceeding to idempotency check');\n\n// Return array of objects (n8n requirement)\nreturn [{\n  json: {\n    file_id: file_id,\n    filename: filename,\n    status: status,\n    count: count,\n    total_chunks: total_chunks,\n    ready: true\n  }\n}];"
  },
  "id": "965c8bda-b1f1-43e7-b22e-c2b0eb472c34",
  "name": "Gate Ready",
  "type": "n8n-nodes-base.code",
  "typeVersion": 2,
  "position": [144, 0]
}
```

**Key Fix:** `const data = Array.isArray($json) ? $json[0] : $json;`

---

## NODE 3: Gate Not Ready (FIXED - Returns proper array)

```json
{
  "parameters": {
    "jsCode": "// Handle both array and object from Postgres\nconst data = Array.isArray($json) ? $json[0] : $json;\n\nconst status = data?.status;\nconst count = Number(data?.count || 0);\nconst file_id = data?.file_id;\nconst filename = data?.filename;\n\nconsole.log('=== Gate Not Ready ===');\nconsole.log('file_id:', file_id);\nconsole.log('status:', status);\nconsole.log('count:', count);\nconsole.log('Reason:', status !== 'completed' ? 'status not completed' : 'embeddings count is 0');\n\n// Return array of objects\nreturn [{\n  json: {\n    file_id: file_id,\n    filename: filename,\n    status: status,\n    count: count,\n    ready: false,\n    reason: status !== 'completed' ? 'processing' : 'no_embeddings'\n  }\n}];"
  },
  "id": "62719d2c-ba34-4665-a4da-b395906fbb83",
  "name": "Gate Not Ready",
  "type": "n8n-nodes-base.code",
  "typeVersion": 2,
  "position": [144, 384]
}
```

---

## NODE 4: Idempotency Check (SAME - Already correct)

```json
{
  "parameters": {
    "jsCode": "const sd = this.getWorkflowStaticData('global');\nsd.socialProcessed = sd.socialProcessed || {};\n\nconst fid = $json.file_id;\n\nconsole.log('=== Idempotency Check ===');\nconsole.log('file_id:', fid);\nconsole.log('filename:', $json.filename);\n\n// Must have file_id\nif (!fid) {\n  console.log('❌ No file_id - blocking both outputs');\n  return [[], []];\n}\n\n// Check if already processed\nconst alreadyProcessed = sd.socialProcessed[fid];\n\nif (alreadyProcessed) {\n  console.log('🔄 DUPLICATE detected');\n  console.log('   First processed:', alreadyProcessed.first_seen);\n  console.log('   → Routing to Output 1 (duplicate branch)');\n  \n  // OUTPUT 1: Duplicate\n  return [\n    [], // Output 0 (new) = empty\n    [{ json: { ...$json, duplicate: true, first_processed_at: alreadyProcessed.first_seen }}] // Output 1 (duplicate) = has data\n  ];\n} else {\n  console.log('✅ NEW episode detected');\n  console.log('   Marking as processed NOW');\n  console.log('   → Routing to Output 0 (new processing branch)');\n  \n  // Mark as processed\n  sd.socialProcessed[fid] = { \n    first_seen: new Date().toISOString(),\n    filename: $json.filename\n  };\n  \n  // OUTPUT 0: New\n  return [\n    [{ json: { ...$json, duplicate: false, is_new: true }}], // Output 0 (new) = has data\n    [] // Output 1 (duplicate) = empty\n  ];\n}"
  },
  "id": "NEW-IDEMPOTENCY-CHECK",
  "name": "Idempotency Check",
  "type": "n8n-nodes-base.code",
  "typeVersion": 2,
  "position": [368, -96]
}
```

---

## WHAT CHANGED IN v2

### Gate Ready:
**Before:**
```javascript
const status = $json.status;  // ❌ Fails if $json is undefined
```

**After:**
```javascript
const data = Array.isArray($json) ? $json[0] : $json;  // ✅ Handles both formats
const status = data?.status;
```

### Gate Not Ready:
**Same fix** - handles array/object from Postgres

---

## CONNECTIONS (Same as before)

```json
{
  "connections": {
    "Payload OK": {
      "main": [[{"node": "Get Episode Data", "type": "main", "index": 0}]]
    },
    "Get Episode Data": {
      "main": [
        [
          {"node": "Gate Ready", "type": "main", "index": 0},
          {"node": "Gate Not Ready", "type": "main", "index": 0}
        ]
      ]
    },
    "Gate Ready": {
      "main": [[{"node": "Idempotency Check", "type": "main", "index": 0}]]
    },
    "Gate Not Ready": {
      "main": [[{"node": "Respond Not Ready", "type": "main", "index": 0}]]
    },
    "Idempotency Check": {
      "main": [
        [
          {"node": "Respond Accepted", "type": "main", "index": 0},
          {"node": "Get Episode Chunks", "type": "main", "index": 0}
        ],
        [
          {"node": "Respond Duplicate", "type": "main", "index": 0}
        ]
      ]
    }
  }
}
```

---

## QUICK COPY/PASTE VERSIONS

### Gate Ready - jsCode only:
```javascript
// Postgres returns data in $json, handle both single object and array
const data = Array.isArray($json) ? $json[0] : $json;

const status = data?.status;
const count = Number(data?.count || 0);
const file_id = data?.file_id;
const filename = data?.filename;
const total_chunks = Number(data?.total_chunks || 0);

console.log('=== Gate Ready Check ===');
console.log('file_id:', file_id);
console.log('filename:', filename);
console.log('status:', status);
console.log('count:', count);
console.log('total_chunks:', total_chunks);

// Validation: must have file_id
if (!file_id) {
  console.log('❌ No file_id - returning empty array');
  return [];
}

// Check BOTH conditions
const isReady = (status === 'completed' && count > 0);

if (!isReady) {
  console.log('❌ Not ready:');
  console.log('  - status === completed?', status === 'completed', '(actual:', status, ')');
  console.log('  - count > 0?', count > 0, '(actual:', count, ')');
  return [];
}

console.log('✅ READY - proceeding to idempotency check');

// Return array of objects (n8n requirement)
return [{
  json: {
    file_id: file_id,
    filename: filename,
    status: status,
    count: count,
    total_chunks: total_chunks,
    ready: true
  }
}];
```

### Gate Not Ready - jsCode only:
```javascript
// Handle both array and object from Postgres
const data = Array.isArray($json) ? $json[0] : $json;

const status = data?.status;
const count = Number(data?.count || 0);
const file_id = data?.file_id;
const filename = data?.filename;

console.log('=== Gate Not Ready ===');
console.log('file_id:', file_id);
console.log('status:', status);
console.log('count:', count);
console.log('Reason:', status !== 'completed' ? 'status not completed' : 'embeddings count is 0');

// Return array of objects
return [{
  json: {
    file_id: file_id,
    filename: filename,
    status: status,
    count: count,
    ready: false,
    reason: status !== 'completed' ? 'processing' : 'no_embeddings'
  }
}];
```

---

## TEST IT

After pasting the fixed code:

1. **Trigger with test payload**
2. **Check execution logs** - should see:
```
=== Gate Ready Check ===
file_id: 1F5hfhg-DAy9wikYR3ZzUGrBeF4t89m6y
filename: Episode_754_-_Untold_Power_of_Insurance_with_Andrew_Engler.txt
status: completed
count: 100
total_chunks: 100
✅ READY - proceeding to idempotency check
```

3. **Should pass to Idempotency Check** without errors

The key fix: `const data = Array.isArray($json) ? $json[0] : $json;`

This handles both Postgres output formats.
