# HOW TO FIX N8N ATOM EXTENSION ON DROPLET

## 🔧 **One-Liner Commands for Droplet**

### **1. Connect to Droplet**
```bash
ssh root@134.209.72.79
```

### **2. Find idudesRAG Project**
```bash
find / -name "*idudesRAG*" -type d 2>/dev/null | head -5
```

### **3. Navigate to Project**
```bash
cd /path/to/idudesRAG  # Replace with actual path found above
```

### **4. Check Current Docker Compose**
```bash
cat docker-compose.yml | grep "node:"
```

### **5. Update Node.js Version in Docker Compose**
```bash
sed -i 's/node:20-alpine/node:22-alpine/g' docker-compose.yml
```

### **6. Update UI Dockerfile**
```bash
sed -i 's/FROM node:20-alpine/FROM node:22-alpine/g' ui/Dockerfile
```

### **7. Verify Changes**
```bash
grep -n "node:22-alpine" docker-compose.yml ui/Dockerfile
```

### **8. Stop Containers**
```bash
docker-compose down
```

### **9. Rebuild with Node.js 22**
```bash
docker-compose build --no-cache
```

### **10. Start Updated Containers**
```bash
docker-compose up -d
```

### **11. Check Container Status**
```bash
docker-compose ps
```

### **12. Verify Node.js Version in Container**
```bash
docker-compose exec ui node --version
docker-compose exec doc-processor node --version
```

## 🚨 **If Project Not Found, Search Common Locations**

```bash
# Check common project directories
ls -la /opt/ | grep -i idudes
ls -la /home/ | grep -i idudes  
ls -la /root/ | grep -i idudes
find /var/www -name "*idudes*" 2>/dev/null
```

## ✅ **Expected Results**
- Node.js version should show `v22.x.x` 
- n8n Atom extension should work in VSCode
- No more "Node.js version not supported" errors

## 🔄 **If Still Fails**
```bash
# Check if containers are using external network
docker network ls | grep 3e-network

# Create network if missing
docker network create 3e-network

# Restart containers
docker-compose up -d
```