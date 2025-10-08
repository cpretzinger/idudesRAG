# 🔐 VERCEL ENVIRONMENT VARIABLES SETUP

## 🎯 OVERVIEW

This guide shows you how to securely store all credentials in Vercel's dashboard so your Next.js app can access DigitalOcean Spaces, OpenAI, PostgreSQL, and n8n webhooks.

## 🚨 CRITICAL: Webhook Proxy Architecture

**The UI is deployed on Vercel (ui-theta-black.vercel.app), NOT on the DigitalOcean droplet.**

The n8n service runs on DigitalOcean (134.209.72.79) at `ai.thirdeyediagnostics.com`. To allow the Vercel UI to communicate with n8n, we use an API route proxy:

```
Vercel (ui-theta-black.vercel.app)
  └── Next.js UI (Uploader.tsx)
      └── POST /api/webhook/documents (proxy API route)
          └── Forwards to: https://ai.thirdeyediagnostics.com/webhook/documents
              └── n8n workflow on DigitalOcean (134.209.72.79)
```

**Why a proxy?**
- CORS security (browser can't call external webhooks directly)
- Centralized error handling
- Environment variable management
- Request/response logging

---

## ⚡ QUICK SETUP (3 MINUTES)

### **Step 1: Go to Vercel Dashboard**

1. Open **https://vercel.com/dashboard**
2. Select your project: **ui-hqv6d6k5n-pretzingers-projects**
3. Click **Settings** → **Environment Variables**

---

### **Step 2: Add All Credentials**

Click **+ Add** for each variable below:

#### **🚨 CRITICAL: n8n Webhook Configuration**

```
Name: N8N_DOCUMENTS_WEBHOOK_URL
Value: https://ai.thirdeyediagnostics.com/webhook/documents
Environment: Production, Preview, Development
```

**OR** (fallback option):

```
Name: NEXT_PUBLIC_N8N_URL
Value: https://ai.thirdeyediagnostics.com
Environment: Production, Preview, Development
```

**Note**: The proxy route will automatically append `/webhook/documents` if only `NEXT_PUBLIC_N8N_URL` is set. Setting both is recommended.

---

#### **🗄️ Database (Railway PostgreSQL)**

```
Name: DATABASE_URL
Value: postgresql://postgres:d7ToQHAA7VecTKi2DxFgNxtlj~xN_HnD@yamabiko.proxy.rlwy.net:15649/railway
Environment: Production, Preview, Development
```

---

#### **💾 DigitalOcean Spaces (S3-Compatible Storage)**

```
Name: SPACES_ACCESS_KEY
Value: DO801GMC4X89LPH7GYUR
Environment: Production, Preview, Development
```

```
Name: SPACES_SECRET_KEY
Value: 5ETjfL9VsoOx/23w4uwwdNVoJG1+npyGPrXsvSW31gQ
Environment: Production, Preview, Development
```

```
Name: SPACES_BUCKET
Value: datainjestion
Environment: Production, Preview, Development
```

```
Name: SPACES_REGION
Value: nyc3
Environment: Production, Preview, Development
```

```
Name: SPACES_ENDPOINT
Value: https://nyc3.digitaloceanspaces.com
Environment: Production, Preview, Development
```

```
Name: SPACES_CDN_URL
Value: https://datainjestion.nyc3.cdn.digitaloceanspaces.com
Environment: Production, Preview, Development
```

---

#### **🤖 OpenAI API (Embeddings)**

```
Name: OPENAI_API_KEY
Value: sk-proj-WtRG... (your actual key from README)
Environment: Production, Preview, Development
```

---

## ✅ VERIFICATION STEPS

### **Step 1: Check Webhook Configuration**

After setting environment variables and deploying to Vercel, test the webhook proxy:

```bash
curl https://ui-theta-black.vercel.app/api/webhook/documents
```

**Expected Response (Success):**
```json
{
  "status": "ok",
  "configured": true,
  "webhookUrl": "***configured***",
  "message": "Webhook proxy is ready",
  "timestamp": "2025-10-08T03:45:00.000Z"
}
```

**Error Response (Missing Env Var):**
```json
{
  "status": "ok",
  "configured": false,
  "webhookUrl": null,
  "message": "Missing N8N_DOCUMENTS_WEBHOOK_URL or NEXT_PUBLIC_N8N_URL environment variable",
  "timestamp": "2025-10-08T03:45:00.000Z"
}
```

If you see the error response, go back to Vercel dashboard and add the missing environment variable, then redeploy.

---

### **Step 2: Test Document Upload**

1. Visit `https://ui-theta-black.vercel.app`
2. Upload a test PDF or TXT file
3. Check for success message: "✅ Document uploaded successfully!"
4. If upload fails, check Vercel logs (see troubleshooting below)

---

### **Step 3: Monitor Vercel Logs**

```bash
# Install Vercel CLI if needed
npm i -g vercel

# View live logs
vercel logs --follow

# Or in Vercel dashboard:
# Project → Deployments → [Latest] → Runtime Logs
```

**Look for these log entries:**

✅ Success:
```
[Webhook Proxy] Forwarding document to n8n: {
  url: "https://ai.thirdeyediagnostics.com/webhook/documents",
  filename: "test.pdf",
  size: 12345
}
[Webhook Proxy] Document upload successful
```

❌ Error:
```
[Webhook Proxy] Configuration error: N8N_DOCUMENTS_WEBHOOK_URL or NEXT_PUBLIC_N8N_URL must be set
```

---

## 🐛 TROUBLESHOOTING

### **Issue 1: "Webhook configuration error"**

**Symptom:** API returns 500 with "Webhook configuration error"

**Cause:** `N8N_DOCUMENTS_WEBHOOK_URL` not set in Vercel environment variables

**Fix:**
1. Go to Vercel Dashboard → Settings → Environment Variables
2. Add `N8N_DOCUMENTS_WEBHOOK_URL` with value: `https://ai.thirdeyediagnostics.com/webhook/documents`
3. Save and redeploy the application

---

### **Issue 2: "Document processing failed in n8n workflow"**

**Symptom:** Upload fails with n8n error message

**Cause:** n8n workflow is inactive or has an error

**Fix:**
1. SSH into DigitalOcean droplet: `ssh root@134.209.72.79`
2. Check n8n is running: `docker ps | grep ai-n8n`
3. Check n8n logs: `docker logs -f ai-n8n`
4. Open n8n UI: `https://ai.thirdeyediagnostics.com`
5. Verify workflow `02-DocumentUpload&Vectorization` is **active**
6. Test webhook manually:
   ```bash
   curl -X POST https://ai.thirdeyediagnostics.com/webhook/documents \
     -H "Content-Type: application/json" \
     -d '{
       "filename": "test.pdf",
       "content": "base64content",
       "type": "application/pdf",
       "size": 1024,
       "source": "test"
     }'
   ```

---

### **Issue 3: Request Timeout**

**Symptom:** "Request timeout - n8n took too long to respond"

**Cause:** Document processing taking > 30 seconds

**Fix:**
1. Check n8n workflow execution logs for bottlenecks
2. Verify external services (OpenAI, PostgreSQL, Qdrant) are responsive
3. Consider optimizing document chunking/embedding process
4. For large documents, implement async processing with status polling

---

### **Issue 4: CORS Error in Browser**

**Symptom:** Browser console shows "CORS policy blocked"

**Cause:** You're calling the n8n webhook directly instead of using the proxy

**Fix:**
1. Verify [`Uploader.tsx`](../ui/components/Uploader.tsx) calls `/api/webhook/documents` (NOT `/webhook/documents`)
2. The proxy route handles CORS automatically
3. Never call `https://ai.thirdeyediagnostics.com/webhook/documents` directly from browser

---

### **Issue 5: Environment Variable Not Loading**

**Symptom:** Vercel logs show `undefined` for environment variables

**Cause:** Variable not set correctly in Vercel, or deployment happened before variable was added

**Fix:**
1. Check variable exists: Vercel Dashboard → Settings → Environment Variables
2. Verify it's enabled for the correct environment (Production/Preview/Development)
3. Redeploy: Vercel Dashboard → Deployments → [Latest] → **Redeploy**
4. Environment variables are only loaded at build/deploy time, not dynamically

---

## 📝 USING CREDENTIALS IN NEXT.JS

### **Server-Side Usage (API Routes)**

```typescript
// ui/app/api/upload/route.ts
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3'

const s3Client = new S3Client({
  endpoint: process.env.SPACES_ENDPOINT,
  region: process.env.SPACES_REGION,
  credentials: {
    accessKeyId: process.env.SPACES_ACCESS_KEY!,
    secretAccessKey: process.env.SPACES_SECRET_KEY!
  }
})

export async function POST(req: Request) {
  const file = await req.formData()
  
  await s3Client.send(new PutObjectCommand({
    Bucket: process.env.SPACES_BUCKET,
    Key: 'uploads/document.pdf',
    Body: fileBuffer,
    ACL: 'public-read'
  }))
  
  const publicUrl = `${process.env.SPACES_CDN_URL}/uploads/document.pdf`
  return Response.json({ url: publicUrl })
}
```

---

### **Client-Side Usage (Browser)**

```typescript
// ui/app/components/UploadForm.tsx
export default function UploadForm() {
  const n8nUrl = process.env.NEXT_PUBLIC_N8N_URL
  
  const handleUpload = async (file: File) => {
    const res = await fetch(`${n8nUrl}/idudesRAG/documents`, {
      method: 'POST',
      body: formData
    })
    return res.json()
  }
}
```

**Important**: Only `NEXT_PUBLIC_*` variables are available in browser!

---

## 🔒 SECURITY BEST PRACTICES

### **✅ DO:**

1. **Use Environment-Specific Values**
   - Production: Real credentials
   - Preview: Test credentials
   - Development: Local/test credentials

2. **Never Commit Credentials**
   ```gitignore
   # .gitignore
   .env
   .env.local
   .env.production
   ```

3. **Use NEXT_PUBLIC_ Only for Safe Data**
   - ✅ Webhook URLs (public endpoints)
   - ✅ CDN URLs (public URLs)
   - ❌ API Keys (secret!)
   - ❌ Database passwords (secret!)

---

### **❌ DON'T:**

1. **Don't expose secrets in browser**
   ```typescript
   // ❌ WRONG - exposes secret key in browser
   const key = process.env.OPENAI_API_KEY
   fetch('https://api.openai.com', { headers: { 'Authorization': key }})
   
   // ✅ CORRECT - call your API route instead
   fetch('/api/ai/generate', { body: prompt })
   ```

2. **Don't hardcode credentials**
   ```typescript
   // ❌ WRONG
   const key = 'DO801GMC4X89LPH7GYUR'
   
   // ✅ CORRECT
   const key = process.env.SPACES_ACCESS_KEY
   ```

---

## 🔄 LOCAL DEVELOPMENT SETUP

### **Create `.env.local` file**

```bash
# ui/.env.local (for local Next.js dev)
DATABASE_URL=postgresql://postgres:d7ToQHAA7VecTKi2DxFgNxtlj~xN_HnD@yamabiko.proxy.rlwy.net:15649/railway

SPACES_ACCESS_KEY=DO801GMC4X89LPH7GYUR
SPACES_SECRET_KEY=5ETjfL9VsoOx/23w4uwwdNVoJG1+npyGPrXsvSW31gQ
SPACES_BUCKET=datainjestion
SPACES_REGION=nyc3
SPACES_ENDPOINT=https://nyc3.digitaloceanspaces.com
SPACES_CDN_URL=https://datainjestion.nyc3.cdn.digitaloceanspaces.com

OPENAI_API_KEY=sk-proj-WtRG...

NEXT_PUBLIC_N8N_URL=https://ai.thirdeyediagnostics.com/webhook
```

---

## ✅ VERIFICATION

### **Test in Vercel**

1. **Deploy to Vercel** (push to GitHub)
2. **Check build logs** for errors
3. **Test environment variables**:

```bash
# Add this API route for testing
# ui/app/api/test-env/route.ts
export async function GET() {
  return Response.json({
    hasDatabase: !!process.env.DATABASE_URL,
    hasSpaces: !!process.env.SPACES_ACCESS_KEY,
    hasOpenAI: !!process.env.OPENAI_API_KEY,
    n8nUrl: process.env.NEXT_PUBLIC_N8N_URL
  })
}
```

4. **Visit**: `https://your-app.vercel.app/api/test-env`

**Expected Response:**
```json
{
  "hasDatabase": true,
  "hasSpaces": true,
  "hasOpenAI": true,
  "n8nUrl": "https://ai.thirdeyediagnostics.com/webhook"
}
```

---

## 🚀 DEPLOYMENT WORKFLOW

### **Automatic Deployment**

1. **Push to GitHub**
   ```bash
   git add .
   git commit -m "Add environment variables"
   git push origin main
   ```

2. **Vercel auto-deploys**
   - Uses environment variables from dashboard
   - No need to redeploy when changing env vars
   - Just update in Vercel dashboard → auto-applies

---

## 🔧 UPDATING CREDENTIALS

### **In Vercel Dashboard:**

1. Go to **Settings** → **Environment Variables**
2. Click **Edit** on the variable
3. Update value
4. Click **Save**
5. **Redeploy** (Vercel prompts you)

**No code changes needed!**

---

## 📊 COMPLETE ENV VARS CHECKLIST

Use this checklist to ensure all credentials are set in Vercel:

### **Required for Document Upload (CRITICAL)**
- [ ] `N8N_DOCUMENTS_WEBHOOK_URL` - Full webhook URL: `https://ai.thirdeyediagnostics.com/webhook/documents`
- [ ] `NEXT_PUBLIC_N8N_URL` - n8n base URL (fallback): `https://ai.thirdeyediagnostics.com`

### **Database**
- [ ] `DATABASE_URL` - Railway PostgreSQL connection string

### **File Storage**
- [ ] `SPACES_ACCESS_KEY` - DigitalOcean access key
- [ ] `SPACES_SECRET_KEY` - DigitalOcean secret key
- [ ] `SPACES_BUCKET` - Bucket name (datainjestion)
- [ ] `SPACES_REGION` - Region (nyc3)
- [ ] `SPACES_ENDPOINT` - DO endpoint URL
- [ ] `SPACES_CDN_URL` - CDN URL for public access

### **AI Services**
- [ ] `OPENAI_API_KEY` - OpenAI API key for embeddings

### **Deployment Verification**
- [ ] All variables set for **Production**, **Preview**, and **Development** environments
- [ ] Application redeployed after setting variables
- [ ] Health check passes: `curl https://ui-theta-black.vercel.app/api/webhook/documents`
- [ ] Document upload test successful

---

## 🎯 SUMMARY

**What you did:**
- Added all credentials to Vercel dashboard
- Secured secrets (not exposed in browser)
- Made public URLs available in browser
- Set up local development with `.env.local`

**Result:**
- Next.js can upload to DigitalOcean Spaces
- Next.js can query PostgreSQL
- Next.js can call n8n webhooks
- Next.js can use OpenAI (via server-side routes)
- Zero credentials in code
- Easy to update without redeployment

---

*Last Updated: 2025-01-05*  
*Setup Time: 2 minutes*  
*Security: Production-ready*