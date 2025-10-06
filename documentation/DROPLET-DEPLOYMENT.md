# 🚀 DigitalOcean Droplet Deployment Guide

## 📋 Prerequisites
- SSH access to your DigitalOcean droplet
- Git installed on droplet
- Docker and Docker Compose installed
- Port 3000 available

---

## 🔐 Step 1: SSH into Droplet

```bash
ssh root@your-droplet-ip
```

Or if using a specific user:
```bash
ssh username@your-droplet-ip
```

---

## 📥 Step 2: Clone or Pull Repository

### If First Time (Clone):
```bash
cd /opt  # or wherever you want to store the project
git clone https://github.com/cpretzinger/idudesRAG.git
cd idudesRAG
```

### If Already Exists (Pull Updates):
```bash
cd /opt/idudesRAG  # or your project path
git pull origin main
```

---

## ⚙️ Step 3: Environment Setup

### Create `.env` File
```bash
cp .env.example .env  # if you have a template
# OR create new .env file
nano .env
```

### Add All Variables (Copy from Local `.env`):
```env
# OpenAI
OPENAI_API_KEY=sk-proj-WtRG...

# Railway PostgreSQL
RAILWAY_PGVECTOR_URL=postgres://postgres:d7ToQHAA7VecTKi2DxFgNxtlj~xN_HnD@yamabiko.proxy.rlwy.net:15649/railway
DATABASE_URL=postgres://postgres:d7ToQHAA7VecTKi2DxFgNxtlj~xN_HnD@yamabiko.proxy.rlwy.net:15649/railway

# DigitalOcean Spaces
SPACES_ACCESS_KEY=DO801GMC4X89LPH7GYUR
SPACES_SECRET_KEY=5ETjfL9VsoOx/23w4uwwdNVoJG1+npyGPrXsvSW31gQ
SPACES_BUCKET=datainjestion
SPACES_REGION=nyc3
SPACES_ENDPOINT=https://nyc3.digitaloceanspaces.com
SPACES_CDN_URL=https://datainjestion.nyc3.cdn.digitaloceanspaces.com

# n8n Webhooks
NEXT_PUBLIC_N8N_URL=https://ai.thirdeyediagnostics.com/webhook
N8N_WEBHOOK_URL=https://ai.thirdeyediagnostics.com/webhook/idudesRAG/documents
```

**Save and exit:** `Ctrl+X`, `Y`, `Enter`

---

## 📦 Step 4: Install Dependencies

```bash
cd ui
npm install --production
cd ..
```

---

## 🏗️ Step 5: Build Next.js Application

```bash
cd ui
npm run build
cd ..
```

**Expected Output:**
```
✓ Compiled successfully
✓ Linting and checking validity of types
✓ Collecting page data
✓ Generating static pages (4/4)
✓ Finalizing page optimization
```

---

## 🚀 Step 6: Start Application

### Option A: Docker Compose (Recommended - Most Reliable)
```bash
# Build and start
docker-compose -f docker-compose.prod.yml up -d --build

# View logs
docker-compose -f docker-compose.prod.yml logs -f

# Check status
docker-compose -f docker-compose.prod.yml ps
```

**Or use Makefile shortcuts:**
```bash
make docker-build  # Build image
make docker-up     # Start containers
make docker-logs   # View logs
make deploy        # Pull + rebuild + restart
```

### Option B: Using PM2 (Process Manager)
```bash
# Install PM2 globally (first time only)
npm install -g pm2

# Start application
cd ui
pm2 start npm --name "idudes-ui" -- start

# Save PM2 config to restart on reboot
pm2 save
pm2 startup
```

**Or use Makefile:**
```bash
make pm2-start    # Build and start with PM2
make pm2-logs     # View logs
make deploy-pm2   # Pull + rebuild + restart
```

### Option C: Direct Production Mode
```bash
cd ui
npm start &
```

---

## 🔍 Step 7: Verify Deployment

### Check Application is Running
```bash
curl http://localhost:3000/api/test-env
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

### Check Database Connection
```bash
curl http://localhost:3000/api/test-db
```

### Check Spaces Connection
```bash
curl http://localhost:3000/api/test-spaces
```

---

## 🌐 Step 8: Configure Nginx (Optional - for Public Access)

### Create Nginx Config
```bash
nano /etc/nginx/sites-available/idudes-rag
```

### Add Configuration:
```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

### Enable Site
```bash
ln -s /etc/nginx/sites-available/idudes-rag /etc/nginx/sites-enabled/
nginx -t  # Test config
systemctl reload nginx
```

---

## 📊 Monitoring & Management

### View Logs (PM2)
```bash
pm2 logs idudes-ui
```

### View Logs (Docker)
```bash
docker-compose logs -f
```

### Restart Application
```bash
# PM2
pm2 restart idudes-ui

# Docker
docker-compose restart

# Manual
pkill -f "next start"
cd ui && npm start &
```

### Stop Application
```bash
# PM2
pm2 stop idudes-ui

# Docker
docker-compose down
```

---

## 🔄 Update Process (Pull Latest Changes)

```bash
# 1. Navigate to project
cd /opt/idudesRAG

# 2. Pull latest code
git pull origin main

# 3. Update dependencies (if package.json changed)
cd ui
npm install
npm run build

# 4. Restart application
pm2 restart idudes-ui
# OR
docker-compose restart
```

---

## 🆘 Troubleshooting

### Port Already in Use
```bash
# Find what's using port 3000
lsof -i :3000

# Kill the process
kill -9 <PID>
```

### Environment Variables Not Loading
```bash
# Check .env file exists
ls -la .env

# Verify symlink
ls -la ui/.env.local

# Recreate symlink if needed
cd ui
rm -f .env.local
ln -s ../.env .env.local
```

### Build Fails
```bash
# Clear cache and rebuild
cd ui
rm -rf .next
rm -rf node_modules
npm install
npm run build
```

### Database Connection Issues
```bash
# Test PostgreSQL connection
psql "postgresql://postgres:d7ToQHAA7VecTKi2DxFgNxtlj~xN_HnD@yamabiko.proxy.rlwy.net:15649/railway"

# Check if Railway allows connections from droplet IP
# Add droplet IP to Railway allowlist if needed
```

---

## 🔒 Security Checklist

- [ ] `.env` file has proper permissions (600)
  ```bash
  chmod 600 .env
  ```
- [ ] Firewall configured (only allow 80, 443, 22)
  ```bash
  ufw allow 80
  ufw allow 443
  ufw allow 22
  ufw enable
  ```
- [ ] SSL certificate installed (Let's Encrypt)
  ```bash
  certbot --nginx -d your-domain.com
  ```
- [ ] Regular updates scheduled
  ```bash
  # Add to crontab
  0 2 * * * cd /opt/idudesRAG && git pull && pm2 restart idudes-ui
  ```

---

## 📈 Performance Optimization

### Enable Caching (Nginx)
Add to nginx config:
```nginx
location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}
```

### Enable Compression (Nginx)
```nginx
gzip on;
gzip_vary on;
gzip_min_length 1000;
gzip_types text/plain text/css application/json application/javascript;
```

### Monitor Resources
```bash
# Install htop
apt-get install htop

# Monitor in real-time
htop

# Check disk space
df -h

# Check memory
free -h
```

---

## 🎯 Quick Reference Commands

```bash
# Status check
pm2 status

# View logs
pm2 logs idudes-ui --lines 100

# Restart app
pm2 restart idudes-ui

# Pull latest code and restart
cd /opt/idudesRAG && git pull && cd ui && npm install && npm run build && pm2 restart idudes-ui

# Test endpoints
curl http://localhost:3000/api/test-env
curl http://localhost:3000/api/test-db
curl http://localhost:3000/api/test-spaces

# Check nginx
nginx -t
systemctl status nginx
```

---

*Last Updated: 2025-10-05*  
*Deployment Target: DigitalOcean Droplet*  
*Application: idudesRAG Next.js UI*