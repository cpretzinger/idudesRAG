import { NextRequest, NextResponse } from 'next/server'
import { createAuthHandler } from '@/lib/middleware'

export const maxDuration = 60
export const dynamic = 'force-dynamic'

export const POST = createAuthHandler(async (req: NextRequest, user) => {
  try {
    const formData = await req.formData()
    const file = formData.get('file') as File
    
    if (!file) {
      return NextResponse.json({ error: 'No file provided' }, { status: 400 })
    }

    // Convert to base64
    const bytes = await file.arrayBuffer()
    const buffer = Buffer.from(bytes)
    const base64 = buffer.toString('base64')
    
    // Send to n8n webhook
    const webhookUrl = process.env.N8N_WEBHOOK_URL || 'https://ai.thirdeyediagnostics.com/webhook/idudesRAG/documents'
    
    const response = await fetch(webhookUrl, {
      method: 'POST',
      headers: { 
        'Content-Type': 'application/json',
        'User-Agent': 'idudesRAG-UI/1.0'
      },
      body: JSON.stringify({
        filename: file.name,
        content: base64,
        type: file.type,
        size: file.size,
        timestamp: new Date().toISOString(),
        source: 'vercel-ui'
      })
    })
    
    if (!response.ok) {
      console.error('n8n webhook failed:', response.status, response.statusText)
      return NextResponse.json({ 
        error: 'Processing failed',
        details: `Webhook returned ${response.status}`
      }, { status: 500 })
    }

    const result = await response.json()
    
    return NextResponse.json({ 
      success: true,
      message: 'Document uploaded and queued for processing',
      documentId: result.documentId || 'pending'
    })
    
  } catch (error) {
    console.error('Upload error:', error)
    return NextResponse.json({ 
      error: 'Upload failed',
      details: error instanceof Error ? error.message : 'Unknown error'
    }, { status: 500 })
  }
})