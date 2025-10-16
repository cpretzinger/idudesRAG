#!/bin/bash
# daemon-start.sh - Start n8n Workflow Auto-Sync Daemon

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  n8n Auto-Sync Daemon${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
    echo -e "${YELLOW}Installing dependencies...${NC}"
    pnpm install
    echo ""
fi

# Check if PostgreSQL trigger is installed
echo -e "${YELLOW}Checking PostgreSQL trigger...${NC}"
TRIGGER_CHECK=$(docker exec ai-postgres psql -U ai_user -d ai_assistant -t -c \
    "SELECT COUNT(*) FROM pg_trigger WHERE tgname = 'workflow_update_trigger';" 2>&1)

if [[ "$TRIGGER_CHECK" =~ "0" ]]; then
    echo -e "${RED}⚠️  PostgreSQL trigger not installed!${NC}"
    echo -e "${YELLOW}Installing trigger...${NC}"

    docker exec -i ai-postgres psql -U ai_user -d ai_assistant < ../setup-workflow-trigger.sql

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Trigger installed successfully${NC}"
    else
        echo -e "${RED}✗ Failed to install trigger${NC}"
        echo -e "${YELLOW}Run manually: docker exec -i ai-postgres psql -U ai_user -d ai_assistant < ../setup-workflow-trigger.sql${NC}"
        exit 1
    fi
elif [[ "$TRIGGER_CHECK" =~ "1" ]]; then
    echo -e "${GREEN}✓ Trigger already installed${NC}"
else
    echo -e "${YELLOW}Could not verify trigger status${NC}"
fi
echo ""

# Check if Docker container is running
if ! docker ps | grep -q ai-postgres; then
    echo -e "${RED}⚠️  Error: ai-postgres container is not running${NC}"
    echo -e "${YELLOW}   Start it with: docker-compose up -d ai-postgres${NC}"
    exit 1
fi

# Start daemon
echo -e "${GREEN}Starting auto-sync daemon...${NC}"
echo -e "${YELLOW}Logs will be written to: sync-daemon.log${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
echo ""

# Run daemon
pnpm daemon
