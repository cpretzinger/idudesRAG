#!/bin/bash
# sync-n8n-workflow.sh
# Syncs n8n workflow JSON from PostgreSQL to local json-flows directory
# Compares timestamps in Arizona timezone and prompts for conflicts
#
# Usage:
#   ./sync-n8n-workflow.sh <workflow_name_or_id> [--dry-run] [--force]
#
# Examples:
#   ./sync-n8n-workflow.sh "01-GoogleDriveToVectors"
#   ./sync-n8n-workflow.sh fCTt9QyABrKKBmv7
#   ./sync-n8n-workflow.sh "01-GoogleDriveToVectors" --dry-run
#   ./sync-n8n-workflow.sh "01-GoogleDriveToVectors" --force

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Database credentials (n8n local PostgreSQL)
DB_HOST="ai-postgres"
DB_PORT="5432"
DB_USER="ai_user"
DB_NAME="ai_assistant"

# Project paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
WORKFLOWS_DIR="$PROJECT_ROOT/json-flows"
ARCHIVE_DIR="$WORKFLOWS_DIR/_archive"

# Flags
DRY_RUN=false
FORCE=false

# Parse arguments
if [ $# -lt 1 ]; then
    echo -e "${RED}Usage: $0 <workflow_name_or_id> [--dry-run] [--force]${NC}"
    echo "Example: $0 \"01-GoogleDriveToVectors\""
    echo "Example: $0 fCTt9QyABrKKBmv7 --dry-run"
    exit 1
fi

WORKFLOW_INPUT="$1"
shift

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  n8n Workflow Sync Tool${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to run postgres query via Docker
run_query() {
    docker exec ai-postgres psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "$1" 2>&1
}

# Function to get Arizona time from Unix timestamp
to_arizona_time() {
    local timestamp="$1"
    TZ='America/Phoenix' date -d "@$timestamp" '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null || echo "Invalid timestamp"
}

# Function to get file modification time in Arizona timezone
get_file_az_time() {
    local filepath="$1"
    if [ ! -f "$filepath" ]; then
        echo ""
        return
    fi
    local unix_time=$(stat -c %Y "$filepath" 2>/dev/null || echo "0")
    to_arizona_time "$unix_time"
}

# Function to convert PostgreSQL timestamp to Unix epoch
pg_to_epoch() {
    local pg_timestamp="$1"
    date -d "$pg_timestamp" +%s 2>/dev/null || echo "0"
}

# Function to calculate time difference (returns seconds)
time_diff_seconds() {
    local time1_epoch="$1"
    local time2_epoch="$2"
    echo $((time1_epoch - time2_epoch))
}

# Function to format seconds to human readable
format_duration() {
    local seconds="$1"
    local abs_seconds="${seconds#-}"

    if [ "$abs_seconds" -lt 60 ]; then
        echo "${abs_seconds}s"
    elif [ "$abs_seconds" -lt 3600 ]; then
        echo "$((abs_seconds / 60))m $((abs_seconds % 60))s"
    else
        echo "$((abs_seconds / 3600))h $((abs_seconds % 3600 / 60))m $((abs_seconds % 60))s"
    fi
}

# Step 1: Query workflow from database
echo -e "${YELLOW}[1/6] Querying workflow from database...${NC}"

# First get workflow metadata
METADATA_QUERY="
SELECT
  id,
  name,
  EXTRACT(EPOCH FROM \"updatedAt\")::bigint as updated_epoch,
  TO_CHAR(\"updatedAt\" AT TIME ZONE 'America/Phoenix', 'YYYY-MM-DD HH24:MI:SS') as az_updated
FROM workflow_entity
WHERE name = '$WORKFLOW_INPUT' OR id = '$WORKFLOW_INPUT'
LIMIT 1;
"

METADATA=$(run_query "$METADATA_QUERY")

if [ -z "$METADATA" ] || [[ "$METADATA" == *"ERROR"* ]]; then
    echo -e "${RED}ERROR: Workflow not found: $WORKFLOW_INPUT${NC}"
    echo "Available workflows:"
    run_query "SELECT name, id FROM workflow_entity ORDER BY \"updatedAt\" DESC LIMIT 10;" | column -t -s '|'
    exit 1
fi

# Parse metadata
IFS='|' read -r WF_ID WF_NAME WF_UPDATED_EPOCH WF_AZ_UPDATED <<< "$METADATA"

echo -e "${GREEN}Found workflow:${NC}"
echo -e "  ID: ${CYAN}$WF_ID${NC}"
echo -e "  Name: ${CYAN}$WF_NAME${NC}"
echo -e "  DB Updated (AZ): ${CYAN}$WF_AZ_UPDATED${NC}"
echo ""

# Step 2: Determine file path and check local file
echo -e "${YELLOW}[2/6] Checking local file...${NC}"

LOCAL_FILE="$WORKFLOWS_DIR/${WF_NAME}.json"

if [ -f "$LOCAL_FILE" ]; then
    FILE_MTIME=$(stat -c %Y "$LOCAL_FILE")
    FILE_AZ_TIME=$(to_arizona_time "$FILE_MTIME")
    echo -e "${GREEN}Local file exists:${NC} $LOCAL_FILE"
    echo -e "  File Modified (AZ): ${CYAN}$FILE_AZ_TIME${NC}"
else
    FILE_MTIME=0
    FILE_AZ_TIME="(file does not exist)"
    echo -e "${YELLOW}Local file does not exist:${NC} $LOCAL_FILE"
fi
echo ""

# Step 3: Compare timestamps
echo -e "${YELLOW}[3/6] Comparing timestamps...${NC}"

DIFF_SECONDS=$(time_diff_seconds "$WF_UPDATED_EPOCH" "$FILE_MTIME")
DIFF_ABS=${DIFF_SECONDS#-}

if [ "$FILE_MTIME" -eq 0 ]; then
    echo -e "${CYAN}Local file does not exist - will create new file${NC}"
    ACTION="create"
elif [ "$DIFF_ABS" -lt 5 ]; then
    echo -e "${GREEN}✓ Files are in sync (difference: $(format_duration $DIFF_SECONDS))${NC}"
    if [ "$FORCE" = false ]; then
        echo "Use --force to overwrite anyway."
        exit 0
    fi
    ACTION="sync"
elif [ "$DIFF_SECONDS" -gt 0 ]; then
    echo -e "${CYAN}⬆  Database version is NEWER by $(format_duration $DIFF_SECONDS)${NC}"
    ACTION="db_newer"
else
    echo -e "${YELLOW}⚠️  Local file is NEWER by $(format_duration ${DIFF_SECONDS#-})${NC}"
    ACTION="file_newer"
fi
echo ""

# Step 4: Handle user prompt (if file is newer and not forced)
if [ "$ACTION" = "file_newer" ] && [ "$FORCE" = false ]; then
    echo -e "${YELLOW}[4/6] Local file is newer than database version${NC}"
    echo ""
    echo -e "${CYAN}Actions:${NC}"
    echo "  [O] Overwrite local file with DB version (lose local changes)"
    echo "  [A] Archive local file + pull DB version"
    echo "  [C] Cancel (keep local file)"
    echo ""
    read -p "Choice [O/A/C]: " -n 1 -r CHOICE
    echo ""

    case $CHOICE in
        [Oo])
            echo -e "${YELLOW}Overwriting local file...${NC}"
            ACTION="overwrite"
            ;;
        [Aa])
            echo -e "${GREEN}Archiving local file...${NC}"
            ACTION="archive"
            ;;
        [Cc]|*)
            echo -e "${GREEN}Cancelled. Keeping local file.${NC}"
            exit 0
            ;;
    esac
    echo ""
fi

# Step 5: Archive old version if requested
if [ "$ACTION" = "archive" ]; then
    echo -e "${YELLOW}[5/6] Archiving old version...${NC}"

    ARCHIVE_DATE=$(TZ='America/Phoenix' date +%Y%m%d)
    ARCHIVE_SUBDIR="$ARCHIVE_DIR/$ARCHIVE_DATE"

    if [ "$DRY_RUN" = false ]; then
        mkdir -p "$ARCHIVE_SUBDIR"
        cp "$LOCAL_FILE" "$ARCHIVE_SUBDIR/${WF_NAME}.json"

        # Log to SYNC_LOG.md
        SYNC_LOG="$ARCHIVE_SUBDIR/SYNC_LOG.md"
        if [ ! -f "$SYNC_LOG" ]; then
            echo "# Workflow Sync Log - $ARCHIVE_DATE" > "$SYNC_LOG"
            echo "" >> "$SYNC_LOG"
        fi

        echo "## $(TZ='America/Phoenix' date '+%Y-%m-%d %H:%M:%S %Z')" >> "$SYNC_LOG"
        echo "- **Workflow**: $WF_NAME" >> "$SYNC_LOG"
        echo "- **File Modified**: $FILE_AZ_TIME" >> "$SYNC_LOG"
        echo "- **DB Updated**: $WF_AZ_UPDATED" >> "$SYNC_LOG"
        echo "- **Action**: Archived local version, pulled DB version" >> "$SYNC_LOG"
        echo "- **Difference**: DB newer by $(format_duration $DIFF_SECONDS)" >> "$SYNC_LOG"
        echo "" >> "$SYNC_LOG"

        echo -e "${GREEN}Archived to: $ARCHIVE_SUBDIR/${WF_NAME}.json${NC}"
    else
        echo -e "${CYAN}[DRY RUN] Would archive to: $ARCHIVE_SUBDIR/${WF_NAME}.json${NC}"
    fi
    echo ""
else
    echo -e "${YELLOW}[5/6] Skipping archive (not requested)${NC}"
    echo ""
fi

# Step 6: Build and write workflow JSON
echo -e "${YELLOW}[6/6] Extracting and writing workflow JSON...${NC}"

# Get workflow JSON components in a safe way
TMP_DIR="/tmp/n8n_sync_$$"
mkdir -p "$TMP_DIR"

# Extract each JSON field separately to avoid pipe delimiter issues
docker exec ai-postgres psql -U "$DB_USER" -d "$DB_NAME" -t -A -c \
  "SELECT nodes::text FROM workflow_entity WHERE id = '$WF_ID';" > "$TMP_DIR/nodes.json"

docker exec ai-postgres psql -U "$DB_USER" -d "$DB_NAME" -t -A -c \
  "SELECT connections::text FROM workflow_entity WHERE id = '$WF_ID';" > "$TMP_DIR/connections.json"

docker exec ai-postgres psql -U "$DB_USER" -d "$DB_NAME" -t -A -c \
  "SELECT COALESCE(settings::text, '{}') FROM workflow_entity WHERE id = '$WF_ID';" > "$TMP_DIR/settings.json"

docker exec ai-postgres psql -U "$DB_USER" -d "$DB_NAME" -t -A -c \
  "SELECT COALESCE(\"staticData\"::text, '{}') FROM workflow_entity WHERE id = '$WF_ID';" > "$TMP_DIR/staticData.json"

docker exec ai-postgres psql -U "$DB_USER" -d "$DB_NAME" -t -A -c \
  "SELECT COALESCE(\"pinData\"::text, '{}') FROM workflow_entity WHERE id = '$WF_ID';" > "$TMP_DIR/pinData.json"

docker exec ai-postgres psql -U "$DB_USER" -d "$DB_NAME" -t -A -c \
  "SELECT COALESCE(meta::text, '{\"templateCredsSetupCompleted\": true}') FROM workflow_entity WHERE id = '$WF_ID';" > "$TMP_DIR/meta.json"

# Build complete workflow JSON using Python for safer JSON merging
WORKFLOW_JSON=$(python3 - "$TMP_DIR" << 'PYTHON_EOF'
import json
import sys
import os

tmp_dir = sys.argv[1]

try:
    with open(os.path.join(tmp_dir, 'nodes.json'), 'r') as f:
        nodes = json.load(f)
    with open(os.path.join(tmp_dir, 'connections.json'), 'r') as f:
        connections = json.load(f)
    with open(os.path.join(tmp_dir, 'settings.json'), 'r') as f:
        settings = json.load(f)
    with open(os.path.join(tmp_dir, 'staticData.json'), 'r') as f:
        staticData = json.load(f)
    with open(os.path.join(tmp_dir, 'pinData.json'), 'r') as f:
        pinData = json.load(f)
    with open(os.path.join(tmp_dir, 'meta.json'), 'r') as f:
        meta = json.load(f)

    workflow = {
        "nodes": nodes,
        "connections": connections,
        "pinData": pinData,
        "settings": settings,
        "staticData": staticData,
        "meta": meta
    }

    print(json.dumps(workflow, indent=2))

except Exception as e:
    print(json.dumps({"error": str(e)}), file=sys.stderr)
    sys.exit(1)
PYTHON_EOF
)

# Validate JSON
if ! echo "$WORKFLOW_JSON" | python3 -m json.tool > /dev/null 2>&1; then
    echo -e "${RED}ERROR: Generated JSON is invalid!${NC}"
    echo "Debug: First 500 chars:"
    echo "$WORKFLOW_JSON" | head -c 500
    rm -rf "$TMP_DIR"
    exit 1
fi

# Format JSON (already formatted by Python script, but validate)
FORMATTED_JSON="$WORKFLOW_JSON"

if [ "$DRY_RUN" = false ]; then
    # Backup current file if exists
    if [ -f "$LOCAL_FILE" ]; then
        cp "$LOCAL_FILE" "${LOCAL_FILE}.bak"
    fi

    # Write new file
    echo "$FORMATTED_JSON" > "$LOCAL_FILE"

    # Remove backup if successful
    rm -f "${LOCAL_FILE}.bak"

    echo -e "${GREEN}✓ Successfully wrote workflow to: $LOCAL_FILE${NC}"
    echo -e "${GREEN}✓ Workflow synced from database${NC}"
else
    echo -e "${CYAN}[DRY RUN] Would write to: $LOCAL_FILE${NC}"
    echo -e "${CYAN}JSON Preview (first 20 lines):${NC}"
    echo "$FORMATTED_JSON" | head -20
fi
echo ""

# Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Sync Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}Workflow:${NC} $WF_NAME"
echo -e "${GREEN}Action:${NC} $ACTION"
echo -e "${GREEN}DB Updated (AZ):${NC} $WF_AZ_UPDATED"
if [ -f "$LOCAL_FILE" ]; then
    NEW_FILE_TIME=$(get_file_az_time "$LOCAL_FILE")
    echo -e "${GREEN}File Modified (AZ):${NC} $NEW_FILE_TIME"
fi
echo ""

if [ "$DRY_RUN" = true ]; then
    echo -e "${CYAN}This was a DRY RUN - no files were modified${NC}"
    echo ""
fi

# Cleanup temp directory
rm -rf "$TMP_DIR"
