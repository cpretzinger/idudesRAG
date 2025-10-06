import { NextRequest, NextResponse } from 'next/server'

export async function POST(req: NextRequest) {
  try {
    const {
      query,
      limit = 10,
      startDate,
      endDate,
      fileTypes,
      minSimilarity = 0.7
    } = await req.json()

    if (!query) {
      return NextResponse.json({ error: 'Query is required' }, { status: 400 })
    }

    // Send to n8n search webhook
    const webhookUrl = process.env.N8N_SEARCH_WEBHOOK_URL || 'https://ai.thirdeyediagnostics.com/webhook/search'

    const response = await fetch(webhookUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'idudesRAG-UI/1.0'
      },
      body: JSON.stringify({
        query,
        limit,
        startDate,
        endDate,
        fileTypes,
        minSimilarity,
        timestamp: new Date().toISOString(),
        source: 'vercel-ui'
      })
    })

    if (!response.ok) {
      console.error('n8n search webhook failed:', response.status, response.statusText)
      return NextResponse.json({
        error: 'Search request failed',
        details: `Webhook returned ${response.status}`
      }, { status: 500 })
    }

    const data = await response.json()

    return NextResponse.json({
      success: true,
      query,
      results: data.results || [],
      count: data.count || 0
    })

  } catch (error) {
    console.error('Search error:', error)
    return NextResponse.json({
      error: 'Search failed',
      details: error instanceof Error ? error.message : 'Unknown error'
    }, { status: 500 })
  }
}

export async function GET(req: NextRequest) {
  const { searchParams } = req.nextUrl
  const query = searchParams.get('q')
  const limit = parseInt(searchParams.get('limit') || '10')

  if (!query) {
    return NextResponse.json({ error: 'Query parameter "q" is required' }, { status: 400 })
  }

  // Redirect GET to POST for consistency
  return POST(new NextRequest(req.url, {
    method: 'POST',
    body: JSON.stringify({ query, limit }),
    headers: { 'Content-Type': 'application/json' }
  }))
}