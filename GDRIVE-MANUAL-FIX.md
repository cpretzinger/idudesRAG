# Fix: Google Drive Manual Execution

## Problem
When manually executing the Google Drive workflow, it processes the **same old file** instead of new files you added.

## Why This Happens
The **Google Drive Trigger** node caches the last triggered file. Manual execution replays that cached data.

---

## ✅ CORRECT Solution: Use Schedule + List Files

### Replace Google Drive Trigger with This:

**Node 1: Schedule Trigger**
- **Trigger Interval:** Every 15 minutes (or as needed)
- **Purpose:** Runs workflow on schedule AND allows manual execution

**Node 2: Google Drive - List**
- **Operation:** List
- **Resource:** File
- **Folder ID:** `YOUR_GOOGLE_DRIVE_FOLDER_ID`
- **Limit:** `100` (process up to 100 new files per run)
- **Filters:**
  - Query: `modifiedTime > '{{ $now.minus({ minutes: 20 }).toISO() }}'`
  - This gets files modified in last 20 minutes

**Node 3: Loop Over Items**
- Use `$items` to process each file from the list

**Node 4: Download File**
- **File ID:** `{{ $json.id }}`
- **Name:** `{{ $json.name }}`

---

## Configuration

### Schedule Trigger Settings

**Trigger Interval:** `Every 15 Minutes`
**Trigger Times:**
```
Cron Expression: */15 * * * *
```

**OR Simple Mode:**
- Interval: `Minutes`
- Minutes Between Triggers: `15`

---

### Google Drive - List Settings

**Node Type:** Google Drive
**Operation:** List
**Resource:** File

**Folder ID:**
```
YOUR_GOOGLE_DRIVE_FOLDER_ID
```

**Filters:**

**Query:**
```
modifiedTime > '{{ $now.minus({ minutes: 20 }).toISO() }}' and trashed = false
```

**Options:**
- Limit: `100`
- Order By: `modifiedTime desc`

**Credentials:**
- Google Drive OAuth2: `GOOGLE_DRIVE_OAUTH_CREDENTIAL_ID`

---

### Download File Settings

**Node Type:** Google Drive
**Operation:** Download
**File ID:**
```
{{ $json.id }}
```

**Google File Conversion:**
- Docs to Format: `text/plain`
- Sheets to Format: `text/csv`
- Slides to Format: `text/plain`

---

## Updated Workflow Structure

```
Schedule Trigger (every 15 min)
  ↓
Google Drive - List (get files modified in last 20 min)
  ↓
Loop: For each file
  ↓
Download File (using {{ $json.id }})
  ↓
PrepDoc
  ↓
Execute SQL
  ↓
Edit Fields
  ↓
map
  ↓
PGVector Store
  ↓
Cleanup
```

---

## Why This Works

### Automatic Mode:
- Runs every 15 minutes
- Checks for files modified in last 20 minutes
- Processes all new files (no duplicates due to timestamp check)

### Manual Mode:
- Click "Execute Workflow"
- Gets files modified in last 20 minutes
- Processes them immediately

---

## Prevent Duplicate Processing

### Add Check Node (Before Download)

**Node Type:** Code (JavaScript)

```javascript
// Check if file already processed
const fileId = $json.id;
const fileName = $json.name;

// Get list of already processed files from database
const { Client } = require('pg');
const client = new Client({
  connectionString: 'postgres://postgres:d7ToQHAA7VecTKi2DxFgNxtlj~xN_HnD@yamabiko.proxy.rlwy.net:15649/railway'
});

try {
  await client.connect();

  const result = await client.query(
    "SELECT id FROM core.documents WHERE metadata->>'drive_file_id' = $1",
    [fileId]
  );

  if (result.rows.length > 0) {
    // Already processed - skip
    console.log(`Skipping ${fileName} - already processed`);
    return [];
  }

  // Not processed - continue
  return [$input.item];

} finally {
  await client.end();
}
```

---

## Alternative: Keep Trigger + Add Webhook for Manual

### Dual Path Setup

**Path 1: Google Drive Trigger (Auto)**
- Triggers on new files
- Processes automatically

**Path 2: Webhook (Manual)**
- POST with `{ "fileId": "..." }`
- Downloads specific file by ID
- Use for manual testing

**Merge:** Both paths connect to "Download File" node

### Webhook Configuration

**Node Type:** Webhook
**HTTP Method:** POST
**Path:** `gdrive-manual`

**Request Body:**
```json
{
  "fileId": "YOUR_GOOGLE_DRIVE_FILE_ID"
}
```

**Test:**
```bash
curl -X POST https://ai.thirdeyediagnostics.com/webhook/gdrive-manual \
  -H "Content-Type: application/json" \
  -d '{"fileId": "1VdRG8IMYrH8gIU_-7bBP8DzQzhgoTj1edkZ3g7TFAJI"}'
```

---

## Recommended: Schedule + List (Simplest)

**Benefits:**
- ✅ Works for auto AND manual execution
- ✅ No duplicate processing (timestamp check)
- ✅ Processes multiple files per run
- ✅ Easy to test (just click Execute)

**Drawbacks:**
- ❌ Not instant (15 min delay)
- ❌ Uses polling (checks every 15 min even if no new files)

**Best for:** Production use with regular file uploads

---

## Quick Test

1. **Remove old Google Drive Trigger node**
2. **Add Schedule Trigger** (set to 15 min interval)
3. **Add Google Drive - List** (with timestamp filter)
4. **Connect to existing Download File node**
5. **Click "Execute Workflow"**
6. **Should process files from last 20 minutes**

---

## Verification

After workflow runs:

```sql
-- Check what files were processed
SELECT
  filename,
  metadata->>'drive_file_id' as drive_id,
  created_at
FROM core.documents
WHERE metadata->>'source' = 'google_drive'
ORDER BY created_at DESC;

-- Check for duplicates (should be 0)
SELECT
  metadata->>'drive_file_id' as drive_id,
  COUNT(*) as count
FROM core.documents
WHERE metadata->>'source' = 'google_drive'
GROUP BY metadata->>'drive_file_id'
HAVING COUNT(*) > 1;
```

---

## Summary

**DO NOT USE:** Manual Trigger (has no file data)

**USE INSTEAD:**
1. **Schedule Trigger** (runs periodically + allows manual execution)
2. **Google Drive - List** (gets new files by timestamp)
3. **Check for duplicates** (optional but recommended)
4. **Download & process** (existing nodes work as-is)
