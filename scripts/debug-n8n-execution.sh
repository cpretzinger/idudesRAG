#!/bin/bash
# debug-n8n-execution.sh
# Analyzes n8n workflow execution failures and provides actionable fixes
# Usage: ./debug-n8n-execution.sh <execution_id> [workflow_url]

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Database credentials from .env
DB_HOST="${POSTGRES_HOST:-134.209.72.79}"
DB_PORT="${POSTGRES_PORT:-5434}"
DB_USER="${POSTGRES_USER:-ai_user}"
DB_PASS="${POSTGRES_PASSWORD:-PtLIu0SN9oJWEvMVxxe5rCGym}"
DB_NAME="${POSTGRES_DB:-ai_assistant}"

# Check arguments
if [ $# -lt 1 ]; then
    echo -e "${RED}Usage: $0 <execution_id> [workflow_url]${NC}"
    echo "Example: $0 151024"
    echo "Example: $0 151024 https://ai.thirdeyediagnostics.com/workflow/uLQsT8ImlCY4SWtu"
    exit 1
fi

EXECUTION_ID="$1"
WORKFLOW_URL="${2:-}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  n8n Execution Debugger${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to run postgres query
run_query() {
    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -c "$1" 2>&1
}

# Step 1: Get execution metadata
echo -e "${YELLOW}[1/5] Fetching execution metadata...${NC}"
EXEC_META=$(run_query "
SELECT
  id,
  \"workflowId\",
  \"startedAt\",
  \"stoppedAt\",
  finished,
  mode,
  status
FROM execution_entity
WHERE id = $EXECUTION_ID;
")

if [ -z "$EXEC_META" ]; then
    echo -e "${RED}ERROR: Execution $EXECUTION_ID not found!${NC}"
    exit 1
fi

IFS='|' read -r exec_id workflow_id started stopped finished mode status <<< "$EXEC_META"

echo -e "${GREEN}Execution ID:${NC} $exec_id"
echo -e "${GREEN}Workflow ID:${NC} $workflow_id"
echo -e "${GREEN}Started:${NC} $started"
echo -e "${GREEN}Stopped:${NC} $stopped"
echo -e "${GREEN}Status:${NC} $status"
echo -e "${GREEN}Mode:${NC} $mode"
echo ""

# Step 2: Extract execution data
echo -e "${YELLOW}[2/5] Extracting execution data...${NC}"
TMP_FILE="/tmp/n8n_exec_${EXECUTION_ID}.json"
run_query "SELECT data FROM execution_data WHERE \"executionId\" = $EXECUTION_ID;" > "$TMP_FILE"

if [ ! -s "$TMP_FILE" ]; then
    echo -e "${RED}ERROR: No execution data found!${NC}"
    exit 1
fi

echo -e "${GREEN}Execution data saved to: $TMP_FILE${NC}"
echo ""

# Step 3: Parse execution and find error
echo -e "${YELLOW}[3/5] Analyzing execution data...${NC}"

ANALYSIS=$(python3 << 'PYTHON_EOF'
import json
import sys

try:
    with open('/tmp/n8n_exec_' + sys.argv[1] + '.json', 'r') as f:
        raw_data = f.read().strip()
        data = json.loads(raw_data)

    # Get metadata
    last_node_idx = data[2].get('lastNodeExecuted', '?')
    error_idx = data[2].get('error', '?')

    result = {
        'last_node_idx': last_node_idx,
        'last_node_name': data[int(last_node_idx)] if str(last_node_idx).isdigit() else 'Unknown',
        'has_error': str(error_idx).isdigit(),
        'error_message': None,
        'error_node': None,
        'run_data': {}
    }

    # Extract error details
    if str(error_idx).isdigit():
        err = data[int(error_idx)]
        msg_idx = err.get('message', '?')
        node_idx = err.get('node', '?')

        if str(msg_idx).isdigit():
            result['error_message'] = data[int(msg_idx)]

        if str(node_idx).isdigit():
            node_data = data[int(node_idx)]
            result['error_node'] = node_data.get('name', 'Unknown')

    # Extract runData for analysis
    run_data_idx = data[2].get('runData', '?')
    if str(run_data_idx).isdigit():
        run_data = data[int(run_data_idx)]
        # Get list of executed nodes
        result['executed_nodes'] = list(run_data.keys())

    print(json.dumps(result, indent=2))

except Exception as e:
    print(json.dumps({'error': str(e)}), file=sys.stderr)
    sys.exit(1)
PYTHON_EOF
)

echo "$ANALYSIS" > "/tmp/n8n_analysis_${EXECUTION_ID}.json"

LAST_NODE=$(echo "$ANALYSIS" | python3 -c "import sys, json; print(json.load(sys.stdin)['last_node_name'])")
HAS_ERROR=$(echo "$ANALYSIS" | python3 -c "import sys, json; print(json.load(sys.stdin)['has_error'])")
ERROR_MSG=$(echo "$ANALYSIS" | python3 -c "import sys, json; m=json.load(sys.stdin).get('error_message'); print(m if m else 'No error message')")
ERROR_NODE=$(echo "$ANALYSIS" | python3 -c "import sys, json; n=json.load(sys.stdin).get('error_node'); print(n if n else 'Unknown')")

echo -e "${GREEN}Last Executed Node:${NC} $LAST_NODE"
if [ "$HAS_ERROR" = "True" ]; then
    echo -e "${RED}Error Node:${NC} $ERROR_NODE"
    echo -e "${RED}Error Message:${NC}"
    echo -e "${RED}  $ERROR_MSG${NC}"
else
    echo -e "${GREEN}No errors detected${NC}"
fi
echo ""

# Step 4: Identify common failure patterns
echo -e "${YELLOW}[4/5] Identifying failure patterns...${NC}"

RECOMMENDATIONS=""

# Pattern 1: NULL constraint violations (DB insert failures)
if echo "$ERROR_MSG" | grep -q "violates not-null constraint"; then
    COLUMN=$(echo "$ERROR_MSG" | grep -oP 'column "\K[^"]+')
    RECOMMENDATIONS+="
${YELLOW}PATTERN DETECTED: Database NULL Constraint Violation${NC}
  Column: $COLUMN

  ${GREEN}Root Cause:${NC}
    Required field '$COLUMN' is NULL when inserting to database.
    This typically means upstream data is missing or not passed through.

  ${GREEN}Common Causes:${NC}
    1. Data lost in a node that doesn't preserve upstream fields
    2. Merge node misconfigured (wrong inputs or mode)
    3. Missing connection between data source and DB insert

  ${GREEN}Fix Steps:${NC}
    1. Trace back from '$ERROR_NODE' to find where '$COLUMN' should come from
    2. Check each node's output - ensure it preserves all required fields
    3. Add a Merge node before DB insert to combine review + enriched data
    4. Update packInputs nodes to preserve upstream data
"
fi

# Pattern 2: undefined in prompts
if echo "$ERROR_MSG" | grep -q "undefined"; then
    RECOMMENDATIONS+="
${YELLOW}PATTERN DETECTED: Undefined Values in Prompts${NC}

  ${GREEN}Root Cause:${NC}
    Template variables are not being replaced (showing 'undefined').
    Data is not flowing properly from upstream nodes.

  ${GREEN}Common Causes:${NC}
    1. packInputs node not pulling from correct upstream source
    2. Data structure mismatch between nodes
    3. Missing fields in input data

  ${GREEN}Fix Steps:${NC}
    1. Check packInputs nodes - ensure they reference correct upstream nodes
    2. Add console.log() to debug which fields are missing
    3. Use \$('NodeName').first().json to explicitly pull from upstream
"
fi

# Pattern 3: Empty node outputs
if [ "$LAST_NODE" != "Unknown" ] && [ "$status" = "error" ]; then
    RECOMMENDATIONS+="
${YELLOW}PATTERN DETECTED: Node Execution Failed${NC}
  Failed Node: $LAST_NODE

  ${GREEN}Common Causes:${NC}
    1. Node has empty output configuration (outputs to nothing)
    2. Node logic error (check console logs)
    3. Missing required input data

  ${GREEN}Fix Steps:${NC}
    1. Check if '$LAST_NODE' has output connections configured
    2. Review node's JavaScript code for errors
    3. Verify input data structure matches expectations
"
fi

if [ -z "$RECOMMENDATIONS" ]; then
    RECOMMENDATIONS="
${GREEN}No specific failure patterns detected.${NC}
Review the execution data manually at: $TMP_FILE
"
fi

echo "$RECOMMENDATIONS"
echo ""

# Step 5: Generate actionable plan
echo -e "${YELLOW}[5/5] Generating action plan...${NC}"

ACTION_PLAN="/tmp/n8n_fix_plan_${EXECUTION_ID}.md"

cat > "$ACTION_PLAN" << EOF
# n8n Execution Failure Analysis
**Execution ID**: $EXECUTION_ID
**Workflow ID**: $workflow_id
**Failed Node**: $LAST_NODE
**Error**: $ERROR_MSG

---

## Execution Timeline
- Started: $started
- Stopped: $stopped
- Duration: $(( $(date -d "$stopped" +%s) - $(date -d "$started" +%s) )) seconds
- Status: $status

---

## Error Analysis
$RECOMMENDATIONS

---

## Execution Data Files
- Raw execution data: $TMP_FILE
- Parsed analysis: /tmp/n8n_analysis_${EXECUTION_ID}.json
- This report: $ACTION_PLAN

---

## Next Steps

1. **Review Workflow in n8n UI**
   Workflow URL: ${WORKFLOW_URL:-https://ai.thirdeyediagnostics.com/workflow/$workflow_id}

2. **Check Node Connections**
   - Verify '$LAST_NODE' has proper output connections
   - Ensure data flows from source to destination without gaps

3. **Add Debug Logging**
   Add console.log() statements to nodes:
   \`\`\`javascript
   console.log('=== DEBUG ===');
   console.log('Input:', JSON.stringify(\$json, null, 2));
   console.log('Required fields:', {
     field1: \$json.field1,
     field2: \$json.field2
   });
   \`\`\`

4. **Test Incrementally**
   - Run workflow manually with test data
   - Check output of each node
   - Fix one issue at a time

---

## Related Documentation
- n8n Execution Logs: https://ai.thirdeyediagnostics.com/executions
- Workflow Editor: ${WORKFLOW_URL:-https://ai.thirdeyediagnostics.com/workflow/$workflow_id}
- Database Schema: /mnt/volume_nyc1_01/idudesRAG/documentation/database/schema_latest.sql

EOF

echo -e "${GREEN}Action plan saved to: $ACTION_PLAN${NC}"
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Analysis Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "View full report: ${GREEN}cat $ACTION_PLAN${NC}"
echo -e "View raw data: ${GREEN}cat $TMP_FILE${NC}"
echo ""

# Cleanup option
read -p "Delete temporary files? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -f "$TMP_FILE" "/tmp/n8n_analysis_${EXECUTION_ID}.json"
    echo -e "${GREEN}Temporary files deleted (report kept)${NC}"
else
    echo -e "${YELLOW}Temporary files kept for further analysis${NC}"
fi
