# n8n Workflow Sync Script

## Overview

`sync-n8n-workflow.sh` syncs n8n workflow JSON from PostgreSQL database to local `json-flows/` directory with intelligent timestamp comparison and conflict resolution.

## Features

✅ **Arizona Timezone Support** - All timestamps compared in Arizona time (MST/MDT)
✅ **Conflict Detection** - Detects when local file is newer than DB version
✅ **Interactive Prompts** - Choose overwrite, archive, or cancel
✅ **Archive System** - Automatically archives old versions with timestamps
✅ **Safety Features** - JSON validation, backup before overwrite, dry-run mode
✅ **Dual Lookup** - Find workflows by name or ID

## Usage

```bash
# Basic sync by workflow name
./scripts/sync-n8n-workflow.sh "01-GoogleDriveToVectors"

# Sync by workflow ID
./scripts/sync-n8n-workflow.sh fCTt9QyABrKKBmv7

# Dry run (preview changes without writing)
./scripts/sync-n8n-workflow.sh "01-GoogleDriveToVectors" --dry-run

# Force overwrite (skip prompts)
./scripts/sync-n8n-workflow.sh "01-GoogleDriveToVectors" --force
```

## Workflow Resolution

The script accepts either:
- **Workflow Name**: Exact name from n8n (e.g., `"01-GoogleDriveToVectors"`)
- **Workflow ID**: Unique identifier (e.g., `fCTt9QyABrKKBmv7`)

To list available workflows:
```bash
docker exec ai-postgres psql -U ai_user -d ai_assistant -c \
  "SELECT name, id FROM workflow_entity ORDER BY \"updatedAt\" DESC LIMIT 20;"
```

## Timestamp Comparison

The script compares timestamps in **Arizona timezone** to ensure consistency:

### When DB is Newer (Common Case)
```
DB Updated (AZ):   2025-10-16 13:13:09
File Modified (AZ): 2025-10-16 11:54:29

⬆  Database version is NEWER by 1h 18m 40s
✓ Will pull DB version to local file
```

### When Local File is Newer (Conflict)
```
DB Updated (AZ):   2025-10-14 10:00:00
File Modified (AZ): 2025-10-16 14:30:00

⚠️  Local file is NEWER by 2d 4h 30m

Actions:
  [O] Overwrite local file with DB version (lose local changes)
  [A] Archive local file + pull DB version
  [C] Cancel (keep local file)
```

### When Files are In Sync
```
✓ Files are in sync (difference: 2s)
Use --force to overwrite anyway.
```

## Archive System

When choosing **[A] Archive**, the script:

1. Creates dated directory: `json-flows/_archive/20251016/`
2. Copies current file: `_archive/20251016/workflow-name.json`
3. Logs sync operation to: `_archive/20251016/SYNC_LOG.md`
4. Pulls fresh version from database

### Archive Structure
```
json-flows/
├── _archive/
│   ├── 20251016/
│   │   ├── 01-GoogleDriveToVectors.json
│   │   ├── 10-social-content-automation.json
│   │   └── SYNC_LOG.md
│   ├── 20251015/
│   │   └── ...
│   └── DEPRECATION_LOG.md  (future use)
└── 01-GoogleDriveToVectors.json
```

### SYNC_LOG.md Format
```markdown
# Workflow Sync Log - 20251016

## 2025-10-16 14:22:15 MST
- **Workflow**: 01-GoogleDriveToVectors
- **File Modified**: 2025-10-16 11:54:29 MST
- **DB Updated**: 2025-10-16 13:13:09 MST
- **Action**: Archived local version, pulled DB version
- **Difference**: DB newer by 1h 18m 40s
```

## JSON Reconstruction

The script reconstructs complete workflow JSON from PostgreSQL columns:

```json
{
  "nodes": [...],           // Workflow nodes
  "connections": {...},     // Node connections
  "pinData": {},            // Pinned test data
  "settings": {...},        // Workflow settings
  "staticData": {...},      // Static workflow data
  "meta": {                 // Metadata
    "templateCredsSetupCompleted": true,
    "instanceId": "..."
  }
}
```

## Safety Features

### 1. JSON Validation
Before writing, validates JSON structure:
```bash
ERROR: Generated JSON is invalid!
Debug: First 500 chars:
{"error": "Unexpected token..."}
```

### 2. Automatic Backup
Creates `.bak` file before overwrite:
```bash
01-GoogleDriveToVectors.json      # Current
01-GoogleDriveToVectors.json.bak  # Backup (auto-deleted on success)
```

### 3. Dry Run Mode
Preview changes without modifying files:
```bash
./scripts/sync-n8n-workflow.sh "workflow-name" --dry-run

[DRY RUN] Would write to: /path/to/workflow.json
JSON Preview (first 20 lines):
{
  "nodes": [...]
}

This was a DRY RUN - no files were modified
```

### 4. Temp File Cleanup
Automatically cleans up temporary files after execution:
```bash
/tmp/n8n_sync_12345/  # Created during execution
# Auto-deleted at script end
```

## Database Connection

The script connects to the **local n8n PostgreSQL** container:

```bash
DB_HOST="ai-postgres"       # Docker container name
DB_PORT="5432"              # Internal port
DB_USER="ai_user"
DB_NAME="ai_assistant"
```

### Required Docker Container
Ensure `ai-postgres` container is running:
```bash
docker ps | grep ai-postgres
# Should show: ai-postgres   Up 7 days (healthy)
```

## Workflow Locking & Version Control

### ✅ This Script is Safe - READ ONLY

**Important**: This script **only reads** from the database and **never modifies** workflow data in PostgreSQL, so it **will not cause workflow locks**.

All database operations are `SELECT` queries only:
```sql
-- Example: What the script does
SELECT id, name, nodes, connections, updatedAt
FROM workflow_entity
WHERE name = 'workflow-name';

-- What it NEVER does:
-- ❌ UPDATE workflow_entity SET ...
-- ❌ INSERT INTO workflow_history ...
-- ❌ Modify versionId field
```

### How n8n Workflow Locking Works

n8n uses **optimistic locking** with version control:

1. **versionId Field**: Each workflow has a unique `versionId` (UUID)
2. **Version Check**: When saving in n8n UI, it checks if `versionId` matches current DB value
3. **Conflict Detection**: If `versionId` changed, someone else edited = shows conflict warning
4. **Version History**: All versions stored in `workflow_history` table for rollback

### Common Causes of Workflow Locks (Not This Script)

If you encounter workflow locks, it's typically from:

**1. Concurrent Editing**
```
❌ Multiple browser tabs with same workflow open
❌ Multiple users editing same workflow simultaneously
❌ Editing workflow while it's actively executing
```

**2. Network Issues**
```
❌ Save operation interrupted mid-way
❌ Database connection timeout during save
❌ Browser crash before save completed
```

**3. Direct Database Modifications (Don't Do This)**
```sql
-- ❌ NEVER DO THIS - Bypasses version control
UPDATE workflow_entity
SET nodes = '...'
WHERE id = 'workflow-id';
```

### Recommended Workflow for Sync

**Safe bidirectional workflow**:

```bash
# Step 1: Pull latest from n8n DB → local files (this script)
./scripts/sync-n8n-workflow.sh "01-GoogleDriveToVectors"

# Step 2a: Edit in n8n UI (recommended)
# - Make changes in browser
# - n8n handles versioning automatically
# - Run Step 1 again to sync changes back to files

# Step 2b: Edit local JSON file (advanced)
# - Make changes to json-flows/*.json
# - Manually import via n8n UI: Workflows → Import from File
# - DO NOT write directly to database

# Step 3: Commit to git
git add json-flows/
git commit -m "Updated workflows"
```

### If You Get a Version Conflict

If n8n shows "Workflow was changed by someone else":

```bash
# Option 1: Check current version in database
docker exec ai-postgres psql -U ai_user -d ai_assistant -c \
  "SELECT id, name, versionId, updatedAt AT TIME ZONE 'America/Phoenix'
   FROM workflow_entity
   WHERE name = '01-GoogleDriveToVectors';"

# Option 2: Pull fresh version with this script
./scripts/sync-n8n-workflow.sh "01-GoogleDriveToVectors" --force

# Option 3: In n8n UI, click "Reload" to get latest version
# Then manually re-apply your changes
```

### Why This Script Won't Lock Workflows

| Action | Affects Locks? | This Script |
|--------|---------------|-------------|
| `SELECT` from database | ✅ No | ✅ Does this |
| `UPDATE` workflow_entity | ❌ Yes | ❌ Never |
| `INSERT` workflow_history | ❌ Yes | ❌ Never |
| Modify `versionId` | ❌ Yes | ❌ Never |
| Edit in n8n UI | ❌ Maybe* | ❌ Separate |
| Write to local files | ✅ No | ✅ Does this |

*Only if multiple editors or network issues

### Best Practices

✅ **DO**:
- Use this script to sync n8n → codebase
- Edit workflows in n8n UI when possible
- Import local JSON via n8n UI if needed
- Close unused workflow tabs in browser
- Reload workflow in UI if you see conflict warnings

❌ **DON'T**:
- Write to PostgreSQL directly (bypass n8n)
- Keep multiple workflow editor tabs open
- Edit workflow while it's executing
- Force-save over conflict warnings without checking

## Exit Codes

| Code | Meaning |
|------|---------|
| 0    | Success (or files in sync) |
| 1    | Workflow not found / Invalid JSON / Database error |

## Troubleshooting

### Workflow Not Found
```bash
ERROR: Workflow not found: workflow-name
Available workflows:
01-GoogleDriveToVectors           fCTt9QyABrKKBmv7
10-social-content-automation      GAZS5v8zBJFtChup
...
```
**Solution**: Use exact workflow name or ID from the list.

### Database Connection Failed
```bash
docker exec: Error response from daemon: Container ai-postgres is not running
```
**Solution**: Start the container:
```bash
docker-compose up -d ai-postgres
```

### JSON Validation Failed
```bash
ERROR: Generated JSON is invalid!
```
**Solution**: Database may have corrupted JSON. Check workflow in n8n UI and re-save.

### Permission Denied
```bash
./scripts/sync-n8n-workflow.sh: Permission denied
```
**Solution**: Make script executable:
```bash
chmod +x ./scripts/sync-n8n-workflow.sh
```

## Examples

### Example 1: Routine Sync After n8n Edits
```bash
# Just edited workflow in n8n UI, now pull to codebase
./scripts/sync-n8n-workflow.sh "01-GoogleDriveToVectors"

# Output:
⬆  Database version is NEWER by 5m 12s
✓ Successfully wrote workflow to: json-flows/01-GoogleDriveToVectors.json
✓ Workflow synced from database
```

### Example 2: Conflict Resolution
```bash
# Made local edits but n8n also has changes
./scripts/sync-n8n-workflow.sh "10-social-content-automation"

# Prompted:
⚠️  Local file is NEWER by 2h 30m
Actions:
  [O] Overwrite local file with DB version (lose local changes)
  [A] Archive local file + pull DB version
  [C] Cancel (keep local file)
Choice [O/A/C]: A

# Result:
Archived to: json-flows/_archive/20251016/10-social-content-automation.json
✓ Workflow synced from database
```

### Example 3: Check Before Overwriting
```bash
# Not sure if files match - check first
./scripts/sync-n8n-workflow.sh "12-Chat-and-Search-Embeddings" --dry-run

# Output:
⬆  Database version is NEWER by 3h 45m
[DRY RUN] Would write to: json-flows/12-Chat-and-Search-Embeddings.json
JSON Preview (first 20 lines):
{...}

# Looks good - run for real
./scripts/sync-n8n-workflow.sh "12-Chat-and-Search-Embeddings"
```

## Related Scripts

- `debug-n8n-execution.sh` - Analyze workflow execution failures
- (Future) `sync-all-workflows.sh` - Bulk sync all workflows

## Notes

- **Always use exact workflow names** - Names are case-sensitive and may include emojis
- **Workflow IDs are safer** - Won't change even if workflow is renamed
- **Archive is your friend** - When in doubt, choose [A] to preserve local changes
- **Dry-run first** - Use `--dry-run` on critical workflows to preview changes

---

**Script Location**: `/mnt/volume_nyc1_01/idudesRAG/scripts/sync-n8n-workflow.sh`
**Author**: Generated with Claude Code
**Version**: 1.0
**Last Updated**: 2025-10-16
