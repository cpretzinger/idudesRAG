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

    // Get the uploaded file
    const formData = await request.formData()
    const file = formData.get('file')

    if (!file) {
      return NextResponse.json(
        { error: 'No file provided' },
        { status: 400 }
      )
    }

    // Forward to n8n upload endpoint with validated session
    const uploadFormData = new FormData()
    uploadFormData.append('file', file)

    const uploadRes = await fetch(`${N8N_BASE_URL}/upload`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${sessionToken}`
      },
      body: uploadFormData
    })

    const uploadData = await uploadRes.json()

    if (!uploadRes.ok) {
      return NextResponse.json(
        { error: uploadData.error || uploadData.message || 'Upload failed' },
        { status: uploadRes.status }
      )
    }

    return NextResponse.json(uploadData)

  } catch (error) {
    console.error('Upload proxy error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
