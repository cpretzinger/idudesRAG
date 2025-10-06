# 🔐 VERCEL ENVIRONMENT VARIABLES SETUP

## 🎯 OVERVIEW

This guide shows you how to securely store all credentials in Vercel's dashboard so your Next.js app can access DigitalOcean Spaces, OpenAI, PostgreSQL, and n8n.

---

## ⚡ QUICK SETUP (2 MINUTES)

### **Step 1: Go to Vercel Dashboard**

1. Open **https://vercel.com/dashboard**
2. Select your project: **ui-hqv6d6k5n-pretzingers-projects**
3. Click **Settings** → **Environment Variables**

---

### **Step 2: Add All Credentials**

Click **+ Add** for each variable below:

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

#### **🔧 n8n Webhooks**

```
Name: NEXT_PUBLIC_N8N_URL
Value: https://ai.thirdeyediagnostics.com/webhook
Environment: Production, Preview, Development
```

**Note**: `NEXT_PUBLIC_` prefix makes it available in browser (safe for webhook URLs)

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

Use this checklist to ensure all credentials are set:

- [ ] `DATABASE_URL` - Railway PostgreSQL connection string
- [ ] `SPACES_ACCESS_KEY` - DigitalOcean access key
- [ ] `SPACES_SECRET_KEY` - DigitalOcean secret key
- [ ] `SPACES_BUCKET` - Bucket name (datainjestion)
- [ ] `SPACES_REGION` - Region (nyc3)
- [ ] `SPACES_ENDPOINT` - DO endpoint URL
- [ ] `SPACES_CDN_URL` - CDN URL for public access
- [ ] `OPENAI_API_KEY` - OpenAI API key
- [ ] `NEXT_PUBLIC_N8N_URL` - n8n webhook base URL

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