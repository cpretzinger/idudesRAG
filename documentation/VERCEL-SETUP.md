# 🚀 VERCEL QUICK SETUP - Document Ingestion UI

## 📋 Prerequisites
- Vercel account (free tier works)
- GitHub account
- Your existing Railway PostgreSQL & Redis

---

## 🎯 STEP 1: Create GitHub Repo & Push

```bash
# Create repo using GitHub CLI (install: brew install gh)
cd ~/projects/idudesRAG
gh auth login  # First time only
gh repo create idudesRAG --public --source=. --remote=origin --push

# Or if gh is not installed, do it manually:
git init
git add .
git commit -m "Initial setup"
# Create repo at github.com/new, then:
git remote add origin https://github.com/YOUR_USERNAME/idudesRAG.git
git branch -M main
git push -u origin main
```

---

## 🔧 STEP 2: Create Simple Next.js App

```bash
# Create the UI
npx create-next-app@latest ui --typescript --tailwind --app
cd ui
```

---

## 📝 STEP 3: Add Document Upload Page

### `ui/app/page.tsx`
```tsx
'use client'
import { useState } from 'react'

export default function Home() {
  const [file, setFile] = useState<File | null>(null)
  const [status, setStatus] = useState('')

  const upload = async () => {
    if (!file) return
    setStatus('Uploading...')
    
    const formData = new FormData()
    formData.append('file', file)
    
    const res = await fetch('/api/upload', {
      method: 'POST',
      body: formData
    })
    
    setStatus(res.ok ? '✅ Success!' : '❌ Failed')
  }

  return (
    <div className="min-h-screen bg-gray-900 flex items-center justify-center">
      <div className="bg-gray-800 p-8 rounded-lg w-96">
        <h1 className="text-2xl font-bold text-white mb-6">📄 Document Upload</h1>
        
        <input
          type="file"
          onChange={(e) => setFile(e.target.files?.[0] || null)}
          className="mb-4 text-white"
          accept=".pdf,.txt,.doc,.docx"
        />
        
        <button
          onClick={upload}
          className="w-full bg-blue-600 text-white py-2 rounded hover:bg-blue-700"
        >
          Upload Document
        </button>
        
        {status && <p className="mt-4 text-white">{status}</p>}
      </div>
    </div>
  )
}
```

### `ui/app/api/upload/route.ts`
```typescript
import { NextRequest, NextResponse } from 'next/server'

export async function POST(req: NextRequest) {
  const formData = await req.formData()
  const file = formData.get('file') as File
  
  // Convert to base64
  const bytes = await file.arrayBuffer()
  const buffer = Buffer.from(bytes)
  const base64 = buffer.toString('base64')
  
  // Send to n8n webhook
  const response = await fetch(process.env.N8N_WEBHOOK_URL!, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      filename: file.name,
      content: base64,
      type: file.type,
      timestamp: new Date().toISOString()
    })
  })
  
  return NextResponse.json({ 
    success: response.ok,
    message: response.ok ? 'Document queued' : 'Upload failed'
  })
}
```

---

## ⚙️ STEP 4: Environment Variables

### `ui/.env.local`
```env
N8N_WEBHOOK_URL=https://your-n8n.com/webhook/documents
NEXT_PUBLIC_APP_URL=https://your-app.vercel.app
```

---

## 🚀 STEP 5: Deploy to Vercel

### Option A: CLI Deploy
```bash
npm i -g vercel
vercel
# Follow prompts, accept defaults
```

### Option B: GitHub Deploy
1. Push code to GitHub
2. Go to [vercel.com/new](https://vercel.com/new)
3. Import GitHub repo
4. Add environment variables:
   - `N8N_WEBHOOK_URL`
5. Click "Deploy"

---

## 🔗 STEP 6: Connect to n8n

### Create n8n Workflow:
1. **Webhook Node** → Listen for documents
2. **Extract Text** → Process PDF/DOC
3. **OpenAI Embeddings** → Generate vectors
4. **PostgreSQL** → Store in `core.memories`
5. **Redis** → Cache for deduplication

---

## ✅ STEP 7: Test It!

1. Visit: `https://your-app.vercel.app`
2. Upload a PDF
3. Check PostgreSQL: 
   ```sql
   SELECT * FROM core.memories ORDER BY created_at DESC LIMIT 5;
   ```

---

## 🎨 BONUS: Add Features

### Search Documents
```typescript
// ui/app/api/search/route.ts
export async function GET(req: NextRequest) {
  const query = req.nextUrl.searchParams.get('q')
  
  // Call your PostgreSQL vector search
  const results = await fetch(process.env.DATABASE_URL!, {
    method: 'POST',
    body: JSON.stringify({
      query: `SELECT * FROM core.fn_retrieve_memories($1, 10)`,
      params: [query]
    })
  })
  
  return NextResponse.json(await results.json())
}
```

---

## 📊 Monitoring

### Add Basic Analytics
```typescript
// Track uploads
await fetch('/api/track', {
  method: 'POST',
  body: JSON.stringify({
    event: 'document_uploaded',
    filename: file.name,
    size: file.size
  })
})
```

---

## 🔒 Security

### Add Rate Limiting
```typescript
import { Ratelimit } from '@upstash/ratelimit'
import { Redis } from '@upstash/redis'

const ratelimit = new Ratelimit({
  redis: Redis.fromEnv(),
  limiter: Ratelimit.slidingWindow(10, '1 m'), // 10 uploads per minute
})

// In your upload handler
const { success } = await ratelimit.limit(req.ip ?? 'anonymous')
if (!success) return new Response('Too many uploads', { status: 429 })
```

---

## 🏃 Quick Commands

```bash
# Local development
npm run dev

# Build for production
npm run build

# Deploy updates
vercel --prod

# View logs
vercel logs
```

---

## 💡 Tips for ADHD

- **One command at a time** - Copy/paste each block
- **Visual feedback** - Status messages show progress
- **No complex configs** - Everything is pre-configured
- **Test immediately** - See results right away
- **Simple UI** - Just drag & drop

---

## 🆘 Troubleshooting

| Issue | Fix |
|-------|-----|
| Upload fails | Check n8n webhook is active |
| No vector search | Verify PostgreSQL pgvector extension |
| Slow uploads | Use Redis for queue management |
| CORS errors | Add your domain to n8n CORS settings |

---

## 📈 Next Steps

1. **Add authentication** (NextAuth.js)
2. **Batch uploads** (multiple files)
3. **Progress bars** (real-time updates)
4. **Search UI** (find your documents)
5. **Download originals** (from MinIO)

---

**Total Setup Time: ~15 minutes** ⏱️