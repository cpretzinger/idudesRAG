import { NextRequest, NextResponse } from 'next/server'

export const maxDuration = 60
export const dynamic = 'force-dynamic'

export async function POST(req: NextRequest) {
  try {
    const { messages, model = 'gpt-5-nano' } = await req.json()

    if (!messages || !Array.isArray(messages)) {
      return NextResponse.json({ error: 'Messages array required' }, { status: 400 })
    }

    // Send to n8n chat webhook
    const webhookUrl = process.env.N8N_CHAT_WEBHOOK_URL || 'https://ai.thirdeyediagnostics.com/webhook/chat'

    const response = await fetch(webhookUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'idudesRAG-UI/1.0'
      },
      body: JSON.stringify({
        messages,
        model,
        timestamp: new Date().toISOString(),
        source: 'vercel-ui'
      })
    })

    if (!response.ok) {
      console.error('n8n chat webhook failed:', response.status, response.statusText)
      return NextResponse.json({
        error: 'Chat request failed',
        details: `Webhook returned ${response.status}`
      }, { status: 500 })
    }

    const data = await response.json()

    return NextResponse.json({
      success: true,
      message: data.message || data.response,
      model: model,
      usage: data.usage
    })

  } catch (error) {
    console.error('Chat error:', error)
    return NextResponse.json({
      error: 'Chat failed',
      details: error instanceof Error ? error.message : 'Unknown error'
    }, { status: 500 })
  }
}
