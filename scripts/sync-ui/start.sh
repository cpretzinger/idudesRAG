#!/bin/bash
# start.sh - Launch n8n Workflow Sync UI

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  n8n Workflow Sync UI${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
    echo -e "${YELLOW}Installing dependencies...${NC}"
    pnpm install
    echo ""
fi

# Check if Docker container is running
if ! docker ps | grep -q ai-postgres; then
    echo -e "${YELLOW}⚠️  Warning: ai-postgres container is not running${NC}"
    echo -e "${YELLOW}   Start it with: docker-compose up -d ai-postgres${NC}"
    echo ""
fi

# Start server
echo -e "${GREEN}Starting server...${NC}"
echo ""

PORT="${SYNC_UI_PORT:-3456}"

# Kill any process already using the port
lsof -ti:$PORT | xargs kill -9 2>/dev/null || true

# Start the server
pnpm start
