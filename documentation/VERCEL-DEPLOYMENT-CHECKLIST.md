# ✅ Vercel Deployment Checklist - idudesRAG

## 🎯 Quick Reference

**Deployment URL**: https://ui-theta-black.vercel.app  
**n8n Instance**: https://ai.thirdeyediagnostics.com  
**DigitalOcean Droplet**: 134.209.72.79

---

## 📋 Pre-Deployment Checklist

### 0. Root Directory Configuration (CRITICAL)

**⚠️ IMPORTANT**: The Next.js app is in the `ui/` subdirectory, NOT the repository root!

**🚨 BREAKING CHANGE**: The [`vercel.json`](../vercel.json) file has been **REMOVED** to fix 404 errors on API routes.

#### **✅ REQUIRED: Vercel Dashboard Configuration**
1. Go to Vercel Dashboard → Project Settings → General
2. Find **"Root Directory"** setting
3. Set to: `ui/`
4. Click **Save**
5. **Framework Preset**: Should auto-detect as "Next.js"
6. **Build Command**: Leave blank (auto-detect)
7. **Install Command**: Leave blank (auto-detect)
8. **Output Directory**: Leave blank (auto-detect)
9. Redeploy the project

#### **🐛 Why vercel.json Was Removed**
The custom `buildCommand` in vercel.json was preventing API routes from being deployed properly:
- **Problem**: `/api/webhook/documents` returned 404 in production
- **Root Cause**: Custom build commands interfered with Next.js App Router API route deployment
- **Solution**: Remove vercel.json entirely and use Vercel Dashboard configuration instead

**⚠️ After removing vercel.json, you MUST configure Root Directory in Vercel Dashboard or deployment will fail.**

---

### 1. Environment Variables (CRITICAL)

Ensure these are set in Vercel Dashboard → Settings → Environment Variables:

#### **🚨 Must-Have for Document Upload**
- [ ] `N8N_DOCUMENTS_WEBHOOK_URL` = `https://ai.thirdeyediagnostics.com/webhook/documents`
- [ ] `NEXT_PUBLIC_N8N_URL` = `https://ai.thirdeyediagnostics.com` (fallback)

#### **Database & Storage**
- [ ] `DATABASE_URL` = Railway PostgreSQL connection string
- [ ] `SPACES_ACCESS_KEY` = DigitalOcean Spaces key
- [ ] `SPACES_SECRET_KEY` = DigitalOcean Spaces secret
- [ ] `SPACES_BUCKET` = `datainjestion`
- [ ] `SPACES_REGION` = `nyc3`
- [ ] `SPACES_ENDPOINT` = `https://nyc3.digitaloceanspaces.com`
- [ ] `SPACES_CDN_URL` = CDN endpoint

#### **AI Services**
- [ ] `OPENAI_API_KEY` = OpenAI API key

### 2. Code Verification

- [ ] [`Uploader.tsx`](../ui/components/Uploader.tsx:20) calls `/api/webhook/documents` (NOT `/webhook/documents`)
- [ ] [`route.ts`](../ui/app/api/webhook/documents/route.ts) has proper environment variable handling
- [ ] All TypeScript files compile without errors
- [ ] No console errors in local development

### 3. n8n Configuration (DigitalOcean)

- [ ] n8n container running: `docker ps | grep ai-n8n`
- [ ] Workflow `02-DocumentUpload&Vectorization` is **Active**
- [ ] Webhook endpoint accessible: `https://ai.thirdeyediagnostics.com/webhook/documents`
- [ ] n8n workflow tested manually

---

## 🚀 Deployment Steps

### Step 1: Set Environment Variables in Vercel

```bash
# Via Vercel CLI (recommended)
vercel env add N8N_DOCUMENTS_WEBHOOK_URL production
# Paste: https://ai.thirdeyediagnostics.com/webhook/documents

vercel env add NEXT_PUBLIC_N8N_URL production  
# Paste: https://ai.thirdeyediagnostics.com

# Repeat for Preview and Development environments
vercel env add N8N_DOCUMENTS_WEBHOOK_URL preview
vercel env add N8N_DOCUMENTS_WEBHOOK_URL development
```

**Or via Vercel Dashboard:**
1. Go to https://vercel.com/dashboard
2. Select project
3. Settings → Environment Variables
4. Add each variable for Production, Preview, Development

### Step 2: Deploy to Vercel

```bash
cd ui
vercel --prod
```

**Or push to GitHub** (if auto-deploy is configured):
```bash
git add .
git commit -m "fix: update webhook proxy for Vercel deployment"
git push origin main
```

### Step 3: Verify Deployment

#### A. Health Check (immediate)
```bash
curl https://ui-theta-black.vercel.app/api/webhook/documents
```

**Expected Response:**
```json
{
  "status": "ok",
  "configured": true,
  "webhookUrl": "***configured***",
  "message": "Webhook proxy is ready",
  "timestamp": "2025-10-08T03:45:00.000Z"
}
```

#### B. Test Document Upload
1. Visit https://ui-theta-black.vercel.app
2. Click file upload area
3. Select a test PDF/TXT file
4. Click "Upload Document"
5. Verify: "✅ Document uploaded successfully!"

#### C. Check Logs

**Vercel Logs:**
```bash
vercel logs --follow
```

**n8n Logs (on droplet):**
```bash
ssh root@134.209.72.79
docker logs -f ai-n8n
```

---

## 🔍 Post-Deployment Verification

### Success Indicators

✅ **Health Check Passes**
- `/api/webhook/documents` returns `"configured": true`

✅ **Document Upload Works**
- UI shows success message
- Document appears in n8n workflow execution logs
- File stored in DigitalOcean Spaces
- Embeddings created in Qdrant/PostgreSQL

✅ **Logs Show Success**
```
[Webhook Proxy] Forwarding document to n8n: { url: "https://...", filename: "test.pdf" }
[Webhook Proxy] Document upload successful
```

✅ **No Errors in Browser Console**
- No CORS errors
- No 404 errors on API routes
- No configuration errors

---

## 🐛 Troubleshooting Guide

### Issue 0: API Routes Return 404 Error (FIXED)

**Symptoms:**
- `/api/webhook/documents` returns `404 This page could not be found`
- API routes exist in codebase but not deployed to Vercel
- Health check fails with 404 error

**Root Cause:**
The custom `buildCommand` in `vercel.json` was interfering with Next.js App Router API route deployment. When Vercel uses custom build commands, it can skip proper API route compilation.

**✅ SOLUTION IMPLEMENTED:**
1. **Removed [`vercel.json`](../vercel.json) entirely**
2. **Configure via Vercel Dashboard instead:**
   - Go to: Vercel Dashboard → Your Project → Settings → General
   - Set **Root Directory**: `ui/`
   - Leave all other fields blank (auto-detect)
   - Click **Save** and redeploy

**Verification:**
After fixing, API routes should work:
```bash
curl https://ui-theta-black.vercel.app/api/webhook/documents
# Should return: {"status":"ok","configured":true,...}
```

---

### Issue 1: "No Next.js version detected" Build Error

**Symptoms:**
- Vercel build fails with: `Error: No Next.js version detected`
- Error mentions checking Root Directory setting

**Root Cause:**
The Next.js app is in the `ui/` subdirectory, not the repository root.

**Fix:**
1. Go to: Vercel Dashboard → Your Project → Settings → General
2. Set **Root Directory**: `ui/`
3. Click **Save** and redeploy

**Verification:**
Build logs should show:
```
✓ Detected Next.js version: 15.5.4
✓ Building in /vercel/path/ui directory
✓ next build completed successfully
```

---

### Issue 2: "Webhook configuration error"

**Symptoms:**
- Health check returns `"configured": false`
- Error: "Missing N8N_DOCUMENTS_WEBHOOK_URL"

**Fix:**
1. Verify environment variable in Vercel dashboard
2. Ensure variable is set for all environments (Production/Preview/Development)
3. Redeploy application
4. Clear browser cache and retry

---

### Issue 3: Document upload fails with 500 error

**Symptoms:**
- Upload button shows error
- Vercel logs show n8n webhook error

**Fix:**
1. Check n8n is running:
   ```bash
   ssh root@134.209.72.79
   docker ps | grep ai-n8n
   ```
2. Verify workflow is active in n8n UI
3. Test webhook directly:
   ```bash
   curl -X POST https://ai.thirdeyediagnostics.com/webhook/documents \
     -H "Content-Type: application/json" \
     -d '{"filename":"test.pdf","content":"dGVzdA==","type":"application/pdf","size":100,"source":"test"}'
   ```
4. Check n8n logs: `docker logs -f ai-n8n`

---

### Issue 4: Request timeout

**Symptoms:**
- "Request timeout - n8n took too long to respond"

**Fix:**
1. Check n8n workflow execution logs for bottlenecks
2. Verify external services (OpenAI, PostgreSQL, Qdrant) are responsive
3. For large files (>5MB), consider implementing async processing

---

### Issue 5: CORS errors in browser

**Symptoms:**
- Browser console: "CORS policy blocked"

**Fix:**
1. Verify [`Uploader.tsx`](../ui/components/Uploader.tsx) calls `/api/webhook/documents` (NOT direct n8n URL)
2. Clear browser cache
3. Check proxy route exists: `ui/app/api/webhook/documents/route.ts`

---

### Issue 5: Environment variables not loading

**Symptoms:**
- Vercel logs show `undefined` for env vars
- Health check fails after deployment

**Fix:**
1. Verify variables exist in Vercel dashboard
2. Check they're enabled for current environment
3. **Redeploy** - env vars only load at build/deploy time
4. Wait 1-2 minutes after deployment for propagation

---

## 📊 Monitoring

### Key Metrics

Monitor these in Vercel Dashboard → Analytics:

- **API Response Time**: `/api/webhook/documents` should be < 5s
- **Error Rate**: Should be < 1%
- **Function Invocations**: Track upload volume
- **Bandwidth**: Monitor file transfer costs

### Alerts to Set Up

1. **Error rate > 5%** → Investigate n8n workflow
2. **Response time > 10s** → Check n8n performance
3. **Failed deployments** → Check build logs

---

## 🔄 Redeployment Process

When making changes:

1. **Test locally first**:
   ```bash
   cd ui
   npm run dev
   ```

2. **Commit changes**:
   ```bash
   git add .
   git commit -m "feat: update webhook handling"
   git push origin main
   ```

3. **Verify auto-deployment** (or trigger manually):
   ```bash
   vercel --prod
   ```

4. **Run verification steps** (health check + upload test)

---

## 📝 Quick Command Reference

| Task | Command |
|------|---------|
| Deploy to production | `vercel --prod` |
| View live logs | `vercel logs --follow` |
| Health check | `curl https://ui-theta-black.vercel.app/api/webhook/documents` |
| Test upload | Visit UI and upload file |
| Check n8n status | `ssh root@134.209.72.79 "docker ps \| grep ai-n8n"` |
| View n8n logs | `ssh root@134.209.72.79 "docker logs -f ai-n8n"` |

---

## ✅ Final Checklist

Before marking deployment as complete:

- [ ] **Root Directory** set to `ui/` in Vercel Dashboard (or vercel.json configured)
- [ ] All environment variables set in Vercel
- [ ] Application deployed successfully
- [ ] Health check returns `"configured": true`
- [ ] Test document upload successful
- [ ] Vercel logs show no errors
- [ ] n8n workflow received and processed document
- [ ] Document appears in storage (Spaces)
- [ ] Vector embeddings created (if applicable)
- [ ] No CORS errors in browser console
- [ ] Response times acceptable (< 5s)

---

**Last Updated**: 2025-10-08  
**Maintainer**: Craig Pretzinger  
**Deployment URL**: https://ui-theta-black.vercel.app