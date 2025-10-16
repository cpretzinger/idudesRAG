# TWAT - Workflow 01 UpdateStatus Fix

## Problem Identified
UpdateStatus node in workflow 01 (GoogleDriveToVectors.json) was receiving NULL values for `rag_chunks_count` in the database.

## Root Cause
Line 189 in workflow 01:
```javascript
"queryReplacement": "={{ [$json.file_id, $json.total_chunks] }}"
```

**Issue:** UpdateStatus receives data from InsertEmbedding node, which processes chunks ONE AT A TIME. Each chunk item has `$json.total_chunks` from ProcessDocument, BUT UpdateStatus runs hundreds of times (once per chunk) when it should only run once.

## The Real Issue
- InsertEmbedding uses fields: `chunk_size` (individual chunk length) - NOT `total_chunks`
- InsertEmbedding SQL (line 164) only inserts per-chunk data
- UpdateStatus tries to read `$json.total_chunks` from the CURRENT item flowing through InsertEmbedding
- But the current item is JUST the database INSERT result, which doesn't have `total_chunks`

## Solution
UpdateStatus should reference ProcessDocument node directly (like LogToSheets nodes do), not the current `$json` item.

### LogToSheets Pattern (CORRECT)
Lines 250-251 and 373-374 use:
```javascript
"Filename": "={{ $('ProcessDocument').first().json.filename }}",
"Chunks": "={{ $('ProcessDocument').first().json.total_chunks }}",
```

### UpdateStatus Fix (Line 189)
**Change from:**
```javascript
"queryReplacement": "={{ [$json.file_id, $json.total_chunks] }}"
```

**Change to:**
```javascript
"queryReplacement": "={{ [$json.file_id, $('ProcessDocument').first().json.total_chunks] }}"
```

Or for full consistency:
```javascript
"queryReplacement": "={{ [$('ProcessDocument').first().json.file_id, $('ProcessDocument').first().json.total_chunks] }}"
```

## Field Naming Clarity
- **ProcessDocument outputs:** `total_chunks` (total count across all chunks)
- **InsertEmbedding uses:** `chunk_size` (individual chunk text length)
- **Workflow 10 uses internally:** `chunk_count` (consistent within workflow 10)

## Status
- Identified: ✅
- Fix designed: ✅
- Applied to file: ❌ (pending)
- Git committed: ❌ (pending)
- Tested: ❌ (pending)

## Next Steps
1. Apply fix to line 189 in workflow 01 JSON
2. Git commit and push
3. Test with actual file processing in n8n
