import { NextRequest, NextResponse } from 'next/server'

const N8N_BASE_URL = process.env.NEXT_PUBLIC_N8N_URL || process.env.N8N_WEBHOOK_URL || 'https://ai.thirdeyediagnostics.com/webhook'

export async function POST(req: NextRequest) {
  try {
    const { token, newPassword } = await req.json()

    if (!token || !newPassword) {
      return NextResponse.json(
        { error: 'Token and newPassword are required' },
        { status: 400 }
      )
    }

    const resp = await fetch(`${N8N_BASE_URL}/auth/reset-confirm`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token, new_password: newPassword })
    })

    const data = await resp.json()

    if (!resp.ok || !data.success) {
      return NextResponse.json(
        { error: data.error || 'Reset failed' },
        { status: resp.ok ? 400 : resp.status }
      )
    }

    return NextResponse.json({ success: true, message: 'Password reset successful' })
  } catch {
    return NextResponse.json(
      { error: 'Reset failed' },
      { status: 500 }
    )
  }
}

