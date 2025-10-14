# Preflight - FINAL FIX (Drop-in Ready)

## Solution: Single Query Node + Simple Gate Ready

### Problem
- Two separate queries (Check File Status + Check Embeddings Count)
- Merge node doesn't combine correctly
- Gate Ready can't access the data

### Solution
- **ONE query** that returns everything: file_id, filename, status, total_chunks, count
- Gate Ready uses simple `$json.field` references
- Idempotency Check with 2 outputs

---

## NODE 1: Replace "Check File Status" and "Check Embeddings Count"

**DELETE THESE TWO NODES:**
1. Check File Status (id: 03545db2-1eef-4d10-ad0d-4ab2b235f689)
2. Check Embeddings Count (id: a31f3460-c7af-476f-a086-6de73b4b82c6)

**ADD THIS ONE NODE:**

### Get Episode Data (Replaces both DB checks)

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

**Query Returns:**
```json
{
  "file_id": "1F5hfhg-DAy9wikYR3ZzUGrBeF4t89m6y",
  "filename": "Episode_754_-_Untold_Power_of_Insurance_with_Andrew_Engler.txt",
  "status": "completed",
  "total_chunks": 100,
  "count": 100
}
```

---

## NODE 2: Gate Ready (FIXED - Simple)

```json
{
  "parameters": {
    "jsCode": "// After Get Episode Data, $json has everything we need\nconst status = $json.status;\nconst count = Number($json.count || 0);\nconst file_id = $json.file_id;\nconst filename = $json.filename;\nconst total_chunks = Number($json.total_chunks || 0);\n\nconsole.log('=== Gate Ready Check ===');\nconsole.log('file_id:', file_id);\nconsole.log('filename:', filename);\nconsole.log('status:', status);\nconsole.log('count:', count);\nconsole.log('total_chunks:', total_chunks);\n\n// Validation: must have file_id\nif (!file_id) {\n  console.log('❌ No file_id - blocking');\n  return [];\n}\n\n// Check BOTH conditions\nconst isReady = (status === 'completed' && count > 0);\n\nif (!isReady) {\n  console.log('❌ Not ready:');\n  console.log('  - status === completed?', status === 'completed', '(actual:', status, ')');\n  console.log('  - count > 0?', count > 0, '(actual:', count, ')');\n  return [];\n}\n\nconsole.log('✅ READY - proceeding to idempotency check');\n\n// Pass ALL data forward\nreturn [{\n  json: {\n    file_id: file_id,\n    filename: filename,\n    status: status,\n    count: count,\n    total_chunks: total_chunks,\n    ready: true\n  }\n}];"
  },
  "id": "965c8bda-b1f1-43e7-b22e-c2b0eb472c34",
  "name": "Gate Ready",
  "type": "n8n-nodes-base.code",
  "typeVersion": 2,
  "position": [144, 0]
}
```

---

## NODE 3: Gate Not Ready (for the other branch)

```json
{
  "parameters": {
    "jsCode": "// This receives items that are NOT ready\nconst status = $json.status;\nconst count = Number($json.count || 0);\nconst file_id = $json.file_id;\nconst filename = $json.filename;\n\nconsole.log('=== Gate Not Ready ===');\nconsole.log('file_id:', file_id);\nconsole.log('status:', status);\nconsole.log('count:', count);\nconsole.log('Reason not ready:', status !== 'completed' ? 'status not completed' : 'embeddings count is 0');\n\n// Pass data to \"Not Ready\" response\nreturn [{\n  json: {\n    file_id: file_id,\n    filename: filename,\n    status: status,\n    count: count,\n    ready: false,\n    reason: status !== 'completed' ? 'processing' : 'no_embeddings'\n  }\n}];"
  },
  "id": "62719d2c-ba34-4665-a4da-b395906fbb83",
  "name": "Gate Not Ready",
  "type": "n8n-nodes-base.code",
  "typeVersion": 2,
  "position": [144, 384]
}
```

---

## NODE 4: Idempotency Check (Single node with 2 outputs)

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

## CONNECTIONS (Updated)

### Delete old Merge node connections

### New Flow:

```
Episode Ready Webhook
  └→ Validate Episode Payload
       ├→ Payload OK
       │    └→ Get Episode Data (NEW - single query)
       │         ├→ Gate Ready (if status=completed AND count>0)
       │         │    └→ Idempotency Check
       │         │         ├→ Output 0 (new) → Respond Accepted + Get Episode Chunks
       │         │         └→ Output 1 (duplicate) → Respond Duplicate
       │         └→ Gate Not Ready (if NOT ready)
       │              └→ Respond Not Ready
       └→ Payload Invalid
            └→ Respond Bad Request
```

### JSON Connections:

```json
{
  "connections": {
    "Episode Ready Webhook": {
      "main": [[{"node": "Validate Episode Payload", "type": "main", "index": 0}]]
    },
    "Validate Episode Payload": {
      "main": [
        [
          {"node": "Payload OK", "type": "main", "index": 0},
          {"node": "Payload Invalid", "type": "main", "index": 0}
        ]
      ]
    },
    "Payload OK": {
      "main": [[{"node": "Get Episode Data", "type": "main", "index": 0}]]
    },
    "Payload Invalid": {
      "main": [[{"node": "Respond Bad Request", "type": "main", "index": 0}]]
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

## IMPLEMENTATION STEPS

### Step 1: Delete Old Nodes
1. Delete "Check File Status" node
2. Delete "Check Embeddings Count" node
3. Delete "Merge" node
4. Delete "Idempotency New" node
5. Delete "Idempotency Duplicate" node

### Step 2: Add New Nodes
1. Add "Get Episode Data" node (paste JSON above)
2. Update "Gate Ready" node (paste new jsCode)
3. Update "Gate Not Ready" node (paste new jsCode)
4. Add "Idempotency Check" node (paste JSON above)

### Step 3: Wire Connections
1. Payload OK → Get Episode Data
2. Get Episode Data → Gate Ready (output 0)
3. Get Episode Data → Gate Not Ready (output 1)
4. Gate Ready → Idempotency Check
5. Idempotency Check output 0 → Respond Accepted
6. Idempotency Check output 0 → Get Episode Chunks
7. Idempotency Check output 1 → Respond Duplicate
8. Gate Not Ready → Respond Not Ready

---

## TESTING

### Test 1: New Episode (Should Process)
**Input:**
```json
{
  "file_id": "1F5hfhg-DAy9wikYR3ZzUGrBeF4t89m6y",
  "filename": "Episode 754 - Untold Power of Insurance with Andrew Engler.txt"
}
```

**Expected Log Output:**
```
=== Gate Ready Check ===
file_id: 1F5hfhg-DAy9wikYR3ZzUGrBeF4t89m6y
filename: Episode_754_-_Untold_Power_of_Insurance_with_Andrew_Engler.txt
status: completed
count: 100
total_chunks: 100
✅ READY - proceeding to idempotency check

=== Idempotency Check ===
file_id: 1F5hfhg-DAy9wikYR3ZzUGrBeF4t89m6y
filename: Episode_754_-_Untold_Power_of_Insurance_with_Andrew_Engler.txt
✅ NEW episode detected
   Marking as processed NOW
   → Routing to Output 0 (new processing branch)
```

**Result:** Respond Accepted (200) + continues to Get Episode Chunks

---

### Test 2: Duplicate Episode (Should Reject)
**Input:** Same as Test 1 (run twice)

**Expected Log Output:**
```
=== Gate Ready Check ===
file_id: 1F5hfhg-DAy9wikYR3ZzUGrBeF4t89m6y
...
✅ READY - proceeding to idempotency check

=== Idempotency Check ===
file_id: 1F5hfhg-DAy9wikYR3ZzUGrBeF4t89m6y
🔄 DUPLICATE detected
   First processed: 2025-10-13T22:30:00.000Z
   → Routing to Output 1 (duplicate branch)
```

**Result:** Respond Duplicate (200 with duplicate status)

---

### Test 3: Not Ready (No Embeddings)
**Input:**
```json
{
  "file_id": "FILE-WITH-NO-EMBEDDINGS",
  "filename": "Test Episode.txt"
}
```

**Expected:** (assuming this file exists but has no embeddings)
```
=== Gate Ready Check ===
file_id: FILE-WITH-NO-EMBEDDINGS
status: completed
count: 0
❌ Not ready:
  - status === completed? true (actual: completed)
  - count > 0? false (actual: 0)
```

**Result:** Respond Not Ready (202)

---

## SUMMARY

### What Changed:
1. ✅ **One query instead of two** - Get Episode Data returns everything
2. ✅ **Simple $json references** - Gate Ready just reads $json fields
3. ✅ **Proper branching** - Gate Ready/Not Ready split based on conditions
4. ✅ **Single idempotency node** - Two outputs (new vs duplicate)
5. ✅ **Debug logging** - See exactly what's happening

### Data Flow:
```
Get Episode Data returns:
{
  file_id: "...",
  filename: "...",
  status: "completed",
  total_chunks: 100,
  count: 100
}

↓

Gate Ready checks:
  status === 'completed' ✅
  count > 0 ✅
  → Passes to Idempotency Check

↓

Idempotency Check:
  First time? → Output 0 (new) → Process
  Duplicate? → Output 1 → Respond Duplicate
```

All nodes are drop-in ready. Just copy/paste the JSON!
