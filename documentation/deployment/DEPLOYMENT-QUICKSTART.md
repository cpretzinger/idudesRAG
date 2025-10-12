# 🚀 DEPLOYMENT QUICKSTART - Copy & Paste Commands

## 📋 Table of Contents
- [Deploy to Droplet](#deploy-to-droplet)
- [All Makefile Commands](#makefile-commands)
- [Docker Commands](#docker-commands)
- [PM2 Commands](#pm2-commands)
- [Testing Commands](#testing-commands)
- [File Locations](#file-locations)

---

## 🎯 Deploy to Droplet (3 Commands)

```bash
# 1. SSH to droplet
ssh root@your-droplet-ip

# 2. Navigate to project and pull latest code
cd /opt/idudesRAG && git pull origin main

# 3. Deploy with Docker (RECOMMENDED)
make deploy
```

**That's it!** The app will:
- Build Docker image
- Start container
- Run health checks
- Show logs

---

## 📦 Makefile Commands (Quick Reference)

### Deployment
```bash
make deploy          # Pull + rebuild + restart (Docker)
make deploy-pm2      # Pull + rebuild + restart (PM2)
```

### Docker Management
```bash
make docker-build    # Build Docker image
make docker-up       # Start containers
make docker-down     # Stop containers
make docker-restart  # Restart containers
make docker-logs     # View logs (follow mode)
make docker-ps       # Show container status
```

### PM2 Management
```bash
make pm2-start       # Build and start with PM2
make pm2-stop        # Stop PM2 process
make pm2-restart     # Restart PM2 process
make pm2-logs        # View PM2 logs
make pm2-status      # Show PM2 status
```

### Testing
```bash
make test-env        # Test environment variables
make test-db         # Test database connection
make test-spaces     # Test DigitalOcean Spaces
make test-all        # Run all tests
make health          # Quick health check
```

### Development
```bash
make dev             # Start development server
make build           # Build for production
make install         # Install dependencies
```

### Maintenance
```bash
make clean           # Clean build artifacts
make backup-env      # Backup .env file
make help            # Show all commands
```

---

## 🐳 Docker Commands (Manual)

### Build & Start
```bash
# Build image
docker-compose -f docker-compose.prod.yml build

# Start containers
docker-compose -f docker-compose.prod.yml up -d

# Build and start in one command
docker-compose -f docker-compose.prod.yml up -d --build
```

### Manage Containers
```bash
# View logs
docker-compose -f docker-compose.prod.yml logs -f

# Stop containers
docker-compose -f docker-compose.prod.yml down

# Restart containers
docker-compose -f docker-compose.prod.yml restart

# Show running containers
docker-compose -f docker-compose.prod.yml ps

# Execute command in container
docker-compose -f docker-compose.prod.yml exec ui sh
```

### Cleanup
```bash
# Remove containers
docker-compose -f docker-compose.prod.yml down

# Remove containers and images
docker-compose -f docker-compose.prod.yml down --rmi all

# Remove everything including volumes
docker-compose -f docker-compose.prod.yml down --rmi all -v
```

---

## 🔧 PM2 Commands (Manual)

### Start & Stop
```bash
# Start application
cd ui
npm run build
pm2 start npm --name "idudes-ui" -- start

# Save PM2 config
pm2 save

# Setup auto-restart on reboot
pm2 startup
```

### Manage Process
```bash
# Restart
pm2 restart idudes-ui

# Stop
pm2 stop idudes-ui

# Delete
pm2 delete idudes-ui

# Restart all
pm2 restart all
```

### Monitoring
```bash
# View logs
pm2 logs idudes-ui

# View specific number of lines
pm2 logs idudes-ui --lines 100

# View only errors
pm2 logs idudes-ui --err

# Show status
pm2 status

# Show detailed info
pm2 show idudes-ui

# Monitor in real-time
pm2 monit
```

---

## 🧪 Testing Commands

### Environment Variables
```bash
# Test locally
curl http://localhost:3000/api/test-env

# Test remotely
curl https://your-domain.com/api/test-env

# Pretty print with jq
curl http://localhost:3000/api/test-env | jq
```

**Expected Response:**
```json
{
  "hasDatabase": true,
  "hasSpaces": true,
  "hasOpenAI": true,
  "n8nUrl": "https://ai.thirdeyediagnostics.com/webhook",
  "spacesEndpoint": "https://nyc3.digitaloceanspaces.com",
  "errors": [],
  "warnings": []
}
```

### Database Connection
```bash
# Test database
curl http://localhost:3000/api/test-db | jq

# Should show:
# - PostgreSQL version
# - Available schemas (core, public)
# - Tables in each schema
# - No errors
```

### DigitalOcean Spaces
```bash
# Test Spaces connectivity
curl http://localhost:3000/api/test-spaces | jq

# Should show:
# - connected: true
# - canList: true
# - canWrite: true
# - canDelete: true
# - bucketInfo with all settings
```

### All Tests at Once
```bash
make test-all
# OR manually:
curl http://localhost:3000/api/test-env && \
curl http://localhost:3000/api/test-db && \
curl http://localhost:3000/api/test-spaces
```

---

## 📁 File Locations

### Docker Files
```
ui/Dockerfile                    # Multi-stage production build
ui/.dockerignore                 # Files to exclude from build
docker-compose.prod.yml          # Production orchestration
```

### Configuration
```
.env                             # Environment variables (shared)
ui/.env.local                    # Symlink to root .env
ui/next.config.ts                # Next.js config (standalone mode)
```

### Documentation
```
documentation/DROPLET-DEPLOYMENT.md    # Full deployment guide
documentation/VERCEL-ENV-SETUP.md      # Environment variables reference
documentation/VERIFICATION-CHECKLIST.md # Testing checklist
DEPLOYMENT-QUICKSTART.md               # This file (quick reference)
```

### Build Output
```
ui/.next/                        # Next.js build output
ui/.next/standalone/             # Docker standalone output
ui/node_modules/                 # Dependencies
```

### Automation
```
Makefile                         # Quick command shortcuts
scripts/verify-setup.sh          # Environment verification script
```

---

## 🔄 Common Workflows

### Deploy New Code
```bash
# SSH to droplet
ssh root@your-droplet-ip

# Navigate to project
cd /opt/idudesRAG

# Pull latest code
git pull origin main

# Deploy with Docker
make deploy

# OR with PM2
make deploy-pm2

# Verify deployment
make test-all
```

### View Logs
```bash
# Docker logs (live)
make docker-logs

# PM2 logs (live)
make pm2-logs

# Last 100 lines only
docker-compose -f docker-compose.prod.yml logs --tail=100

# Since specific time
docker-compose -f docker-compose.prod.yml logs --since 2h
```

### Restart After Changes
```bash
# Docker
make docker-restart

# PM2
make pm2-restart

# Full rebuild (if Dockerfile changed)
make docker-down
make docker-up
```

### Check Application Health
```bash
# Quick health check
make health

# Detailed status
make docker-ps    # Docker
make pm2-status   # PM2

# Test all endpoints
make test-all
```

---

## 🆘 Troubleshooting

### Port Already in Use
```bash
# Find process using port 3000
lsof -i :3000

# Kill process
kill -9 <PID>
```

### Environment Variables Not Loading
```bash
# Check .env exists
ls -la .env

# Verify symlink
ls -la ui/.env.local

# Recreate symlink
cd ui && rm -f .env.local && ln -s ../.env .env.local
```

### Docker Build Fails
```bash
# Clean everything
make clean

# Rebuild from scratch
docker-compose -f docker-compose.prod.yml build --no-cache

# Start fresh
make docker-up
```

### Database Connection Issues
```bash
# Test connection directly
psql "postgresql://postgres:password@host:port/railway"

# Check DATABASE_URL is set
echo $DATABASE_URL

# Test via API
curl http://localhost:3000/api/test-db
```

---

## 📊 Monitoring

### Check Resources
```bash
# CPU & Memory usage
htop

# Disk space
df -h

# Docker stats
docker stats

# PM2 monitoring
pm2 monit
```

### View Logs by Time
```bash
# Last hour
docker-compose -f docker-compose.prod.yml logs --since 1h

# Last 24 hours
docker-compose -f docker-compose.prod.yml logs --since 24h

# Specific time range
docker-compose -f docker-compose.prod.yml logs --since "2024-01-05T10:00:00" --until "2024-01-05T11:00:00"
```

---

## 🎯 Quick Copy-Paste Deployment

**Complete deployment in one command block:**

```bash
# Full deployment (copy this entire block)
ssh root@your-droplet-ip << 'ENDSSH'
cd /opt/idudesRAG
git pull origin main
docker-compose -f docker-compose.prod.yml down
docker-compose -f docker-compose.prod.yml up -d --build
docker-compose -f docker-compose.prod.yml logs --tail=50
ENDSSH
```

**Verify deployment:**
```bash
curl https://your-domain.com/api/test-env
curl https://your-domain.com/api/test-db
curl https://your-domain.com/api/test-spaces
```

---

*Last Updated: 2025-10-05*  
*All commands tested on DigitalOcean Ubuntu 22.04 LTS*