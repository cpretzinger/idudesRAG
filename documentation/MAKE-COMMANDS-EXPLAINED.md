# 🤔 What is `make` and `make deploy`?

## 📖 Simple Explanation

**`make`** is just a shortcut tool. Instead of typing long commands, you type short ones.

**`make deploy`** runs these 4 commands for you:

```bash
# 1. Pull latest code from GitHub
git pull origin main

# 2. Stop running containers
docker-compose -f docker-compose.prod.yml down

# 3. Build new image and start containers
docker-compose -f docker-compose.prod.yml up -d --build

# 4. Show logs
docker-compose -f docker-compose.prod.yml logs -f
```

---

## 🎯 If You Don't Want to Use `make`

### Just Copy These Commands Instead:

**Deploy Everything:**
```bash
cd /opt/idudesRAG
git pull origin main
docker-compose -f docker-compose.prod.yml down
docker-compose -f docker-compose.prod.yml up -d --build
docker-compose -f docker-compose.prod.yml logs -f
```

**That's it!** These 5 lines do the exact same thing as `make deploy`.

---

## 🔧 Other `make` Shortcuts → Real Commands

### `make docker-up`
**Does this:**
```bash
docker-compose -f docker-compose.prod.yml up -d
```

### `make docker-down`
**Does this:**
```bash
docker-compose -f docker-compose.prod.yml down
```

### `make docker-logs`
**Does this:**
```bash
docker-compose -f docker-compose.prod.yml logs -f
```

### `make test-all`
**Does this:**
```bash
curl http://localhost:3000/api/test-env
curl http://localhost:3000/api/test-db
curl http://localhost:3000/api/test-spaces
```

---

## 💡 Why Use `make`?

**WITHOUT `make`:**
```bash
docker-compose -f docker-compose.prod.yml up -d --build
```
Long, easy to mistype ❌

**WITH `make`:**
```bash
make docker-up
```
Short, easy to remember ✅

---

## 🚀 EASIEST WAY - No `make` Required

### Deploy Everything (Copy This Block):

```bash
# SSH to your server
ssh root@your-droplet-ip

# Navigate to project
cd /opt/idudesRAG

# Pull latest code
git pull origin main

# Stop old containers
docker-compose -f docker-compose.prod.yml down

# Build and start new containers
docker-compose -f docker-compose.prod.yml up -d --build

# Watch logs (Ctrl+C to exit)
docker-compose -f docker-compose.prod.yml logs -f
```

**Done!** Your app is running.

---

## 🧪 Test Your App

**Check environment:**
```bash
curl http://localhost:3000/api/test-env
```

**Check database:**
```bash
curl http://localhost:3000/api/test-db
```

**Check file storage:**
```bash
curl http://localhost:3000/api/test-spaces
```

All should return JSON with no errors.

---

## 📋 Common Commands Without `make`

### See Running Containers
```bash
docker-compose -f docker-compose.prod.yml ps
```

### Stop Everything
```bash
docker-compose -f docker-compose.prod.yml down
```

### Restart Everything
```bash
docker-compose -f docker-compose.prod.yml restart
```

### View Logs (Last 100 Lines)
```bash
docker-compose -f docker-compose.prod.yml logs --tail=100
```

### Execute Command Inside Container
```bash
docker-compose -f docker-compose.prod.yml exec ui sh
```

---

## 🎓 What Each Part Means

### `docker-compose`
Tool to manage Docker containers

### `-f docker-compose.prod.yml`
Use this specific configuration file

### `up`
Start containers

### `-d`
Run in background (detached)

### `--build`
Rebuild the Docker image first

### `down`
Stop and remove containers

### `logs`
Show output from containers

### `-f` (in logs)
Follow mode - keep showing new logs

---

## ⚡ Quick Reference

| What You Want | Command to Run |
|--------------|----------------|
| Deploy new code | `docker-compose -f docker-compose.prod.yml up -d --build` |
| Stop app | `docker-compose -f docker-compose.prod.yml down` |
| View logs | `docker-compose -f docker-compose.prod.yml logs -f` |
| Check status | `docker-compose -f docker-compose.prod.yml ps` |
| Restart | `docker-compose -f docker-compose.prod.yml restart` |

---

## 🆘 If You Want to Use `make` (Optional)

**Install `make` on Ubuntu/Debian:**
```bash
apt-get update && apt-get install -y make
```

**Then you can use:**
```bash
make deploy        # Instead of 5 long commands
make docker-up     # Instead of docker-compose up
make docker-logs   # Instead of docker-compose logs
make test-all      # Test everything at once
```

**But you DON'T have to!** The long commands work just fine.

---

*Last Updated: 2025-10-05*  
*`make` is optional - use whatever you're comfortable with!*