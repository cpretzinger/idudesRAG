# 🌐 n8n Workflow Sync UI

Beautiful web interface for syncing n8n workflows from PostgreSQL to local JSON files.

![Status](https://img.shields.io/badge/status-production-green)
![License](https://img.shields.io/badge/license-MIT-blue)

---

## 🚀 Quick Start

### Option 1: Docker (Recommended for Server)

```bash
cd scripts/sync-ui

# Build and start container
docker-compose up -d

# View logs
docker-compose logs -f

# Stop container
docker-compose down
```

**Access:**
- Local: http://localhost:3456
- Production: https://sync.thirdeyediagnostics.com (via Traefik)

### Option 2: Local Development

```bash
cd scripts/sync-ui

# Install dependencies
pnpm install

# Start server
./start.sh
# OR
pnpm start
```

**Access:** http://localhost:3456

---

## ✨ Features

### 📊 Dashboard
- **Real-time Status** - See all workflows at a glance
- **Arizona Timezone** - All timestamps in MST/MDT
- **Smart Detection** - Auto-detects sync status (synced/outdated/conflict)
- **Statistics** - Total, synced, needs update, and local newer counts

### 🔍 Workflow Management
- **Search** - Filter by workflow name or ID
- **Status Badges** - Visual indicators for sync state
- **Action Buttons** - One-click sync operations
- **Conflict Resolution** - Interactive prompts for newer local files

### ⚡ Sync Operations
- **Pull from DB** - Update local files with database version
- **Force Sync** - Overwrite local files (use with caution)
- **Archive & Sync** - Backup local version before pulling DB
- **Dry Run** - Preview changes without modifying files

### 🎨 User Interface
- **Modern Design** - Clean, gradient-based UI
- **Responsive** - Works on desktop and mobile
- **Real-time Updates** - Instant feedback on sync operations
- **Dark Code Logs** - Terminal-style output display

---

## 📋 Usage

### Sync Status Indicators

| Badge | Meaning | Action |
|-------|---------|--------|
| **✓ Synced** 🟢 | Files match DB | Force sync available |
| **DB Newer** 🔴 | Database updated | Pull from DB |
| **Local Newer** 🟡 | Local file modified | Resolve conflict |
| **Not Exists** ⚪ | File missing | Create from DB |

### Sync Actions

**1. Pull from DB** (Green button)
- Database version is newer
- Safe operation - overwrites local file
- Creates new file if doesn't exist

**2. Resolve Conflict** (Yellow button)
- Local file is newer than DB
- Options:
  - **Overwrite Local** - Use database version (lose local changes)
  - **Archive Local + Pull DB** - Backup to `_archive/` then sync

**3. Force Sync** (Gray button)
- Files are already in sync
- Forces pull from DB anyway
- Useful for verification

### Archive System

When choosing "Archive Local + Pull DB":

1. **Creates dated directory**: `json-flows/_archive/20251016/`
2. **Copies current file**: Preserves local changes
3. **Logs operation**: `_archive/20251016/SYNC_LOG.md`
4. **Syncs from DB**: Pulls fresh version

---

## 🛠️ Configuration

### Environment Variables

```bash
# Change server port (default: 3456)
export SYNC_UI_PORT=8080

# Then start server
./start.sh
```

### Server Configuration

Edit `server.js` to customize:
- Port number
- Maximum workflows displayed (default: 50)
- Buffer size for large workflows
- Timezone (default: America/Phoenix)

---

## 📡 API Endpoints

The UI communicates with these REST endpoints:

### `GET /api/workflows`
Returns all workflows with status

**Response:**
```json
[
  {
    "id": "fCTt9QyABrKKBmv7",
    "name": "01-GoogleDriveToVectors",
    "dbUpdated": "2025-10-16 13:13:09",
    "fileModified": "2025-10-16 11:54:29",
    "status": "db_newer",
    "statusText": "DB Newer",
    "statusClass": "outdated",
    "diffSeconds": 4720
  }
]
```

### `POST /api/sync`
Sync a workflow

**Request:**
```json
{
  "workflowId": "fCTt9QyABrKKBmv7",
  "force": false,
  "archive": false
}
```

**Response:**
```json
{
  "success": true,
  "message": "Workflow synced successfully!",
  "log": "... sync output ..."
}
```

### `GET /api/sync-status/:workflowId`
Get dry-run output for a workflow

### `GET /health`
Server health check

---

## 🔧 Development

### Run in Dev Mode (Auto-restart)
```bash
pnpm dev
```

### Project Structure
```
sync-ui/
├── index.html      # Frontend UI
├── server.js       # Express backend
├── package.json    # Dependencies
├── start.sh        # Startup script
└── README.md       # This file
```

### Tech Stack
- **Frontend**: Vanilla JavaScript, HTML5, CSS3
- **Backend**: Node.js + Express
- **Database**: PostgreSQL via Docker (ai-postgres container)
- **Shell**: Bash script integration

---

## 🐛 Troubleshooting

### Server Won't Start

**Issue**: Port already in use
```bash
# Kill process on port 3456
lsof -ti:3456 | xargs kill -9

# Then restart
./start.sh
```

**Issue**: Dependencies not installed
```bash
cd scripts/sync-ui
pnpm install
```

### Docker Container Not Running

**Issue**: `ai-postgres` container offline
```bash
# Check container status
docker ps | grep ai-postgres

# Start container
docker-compose up -d ai-postgres
```

### Workflows Not Loading

**Issue**: Database connection failed
```bash
# Test database connection
docker exec ai-postgres psql -U ai_user -d ai_assistant -c "SELECT COUNT(*) FROM workflow_entity;"
```

**Issue**: Permission denied
```bash
# Make scripts executable
chmod +x start.sh
chmod +x ../sync-n8n-workflow.sh
```

### Sync Fails

**Issue**: Workflow JSON invalid
- Check n8n UI - workflow may be corrupted
- Try re-saving workflow in n8n
- Check server logs for detailed error

**Issue**: File permissions
```bash
# Check file ownership
ls -la ../../json-flows/

# Fix if needed
sudo chown -R $USER:$USER ../../json-flows/
```

---

## 🔐 Security Notes

### Safe Operations
- ✅ All sync operations are **READ ONLY** on database
- ✅ Never modifies workflow_entity table
- ✅ Only writes to local filesystem
- ✅ Archive system prevents data loss

### Network Access
The server runs on **localhost only** by default:
- Not exposed to internet
- No authentication required (local access)
- Safe for development use

### Production Deployment
If deploying to remote server:
1. Add authentication middleware
2. Use HTTPS/SSL
3. Restrict IP access
4. Enable CORS properly

---

## 📊 Screenshots

### Dashboard View
```
╔═══════════════════════════════════════╗
║  Total: 15  │ Synced: 8  │ Outdated: 5 │ Newer: 2  ║
╚═══════════════════════════════════════╝

Workflow                    DB Updated        Status      Actions
────────────────────────────────────────────────────────────────
01-GoogleDriveToVectors    2025-10-16 13:13   DB Newer   [Pull from DB]
10-social-automation       2025-10-16 10:51   Synced     [Force Sync]
12-Chat-Embeddings         2025-10-15 18:22   Local Newer [Resolve]
```

### Sync Modal
```
╔════════════════════════════╗
║   Syncing Workflow...      ║
╠════════════════════════════╣
║                            ║
║  ⚡ Pulling from database  ║
║  ✓ JSON validated          ║
║  ✓ File written            ║
║                            ║
║  [Success!]                ║
╚════════════════════════════╝
```

---

## 🎯 Roadmap

### v1.1 (Next Release)
- [ ] Bulk sync operations (select multiple workflows)
- [ ] Scheduled auto-sync
- [ ] Workflow diff viewer
- [ ] Export/import settings

### v1.2 (Future)
- [ ] Real-time WebSocket updates
- [ ] Conflict merge tool
- [ ] Version history browser
- [ ] Dark mode toggle

---

## 📄 License

MIT License - Free to use for personal and commercial projects

---

## 💬 Support

**Issues**: Report bugs in main project issue tracker
**Documentation**: See `/scripts/README-sync-workflow.md` for CLI tool docs
**Questions**: Contact craig@theidudes.com

---

## 🙏 Acknowledgments

Built with:
- **Express.js** - Web server framework
- **PostgreSQL** - n8n workflow storage
- **Docker** - Container orchestration
- **n8n** - Workflow automation platform

---

**Made with ❤️ for the idudesRAG project**

*Keeping workflows in sync, one click at a time.* ⚡
