import { NextRequest, NextResponse } from 'next/server'

const N8N_BASE_URL = process.env.NEXT_PUBLIC_N8N_URL || 'https://ai.thirdeyediagnostics.com/webhook'

export async function POST(request: NextRequest) {
  try {
    const authHeader = request.headers.get('authorization')
    const sessionToken = authHeader?.replace('Bearer ', '')

    if (!sessionToken) {
      return NextResponse.json(
        { error: 'Unauthorized - No session token provided' },
        { status: 401 }
      )
    }

    // Validate session with n8n
    const validateRes = await fetch(`${N8N_BASE_URL}/validate-session`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ session_token: sessionToken })
    })

    if (!validateRes.ok) {
      return NextResponse.json(
        { error: 'Unauthorized - Invalid or expired session' },
        { status: 401 }
      )
    }

    const validationData = await validateRes.json()

    if (!validationData.valid) {
      return NextResponse.json(
        { error: 'Unauthorized - Session validation failed' },
        { status: 401 }
      )
    }

    // Get request body
    const body = await request.json()

    // Forward to n8n chat endpoint with validated session
    const chatRes = await fetch(`${N8N_BASE_URL}/chat-knowledge`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${sessionToken}`
      },
      body: JSON.stringify({
        ...body,
        user_id: validationData.user?.id // Add validated user_id
      })
    })

    const chatData = await chatRes.json()

    if (!chatRes.ok) {
      return NextResponse.json(
        { error: chatData.error || 'Chat request failed' },
        { status: chatRes.status }
      )
    }

    return NextResponse.json(chatData)

  } catch (error) {
    console.error('Chat proxy error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
