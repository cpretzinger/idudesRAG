import { NextRequest, NextResponse } from 'next/server'
import { validateSession } from '@/lib/auth'

const N8N_BASE_URL = process.env.NEXT_PUBLIC_N8N_URL || process.env.N8N_WEBHOOK_URL || 'https://ai.thirdeyediagnostics.com/webhook'

export async function POST(req: NextRequest) {
  try {
    // Get token from Authorization header or cookie
    const authHeader = req.headers.get('authorization')
    const token = authHeader?.replace('Bearer ', '') || req.cookies.get('session_token')?.value

    if (!token) {
      return NextResponse.json(
        { error: 'Not authenticated' },
        { status: 401 }
      )
    }

    const result = await validateSession(token)

    if (!result.valid || !result.user) {
      return NextResponse.json(
        { error: 'Invalid session' },
        { status: 401 }
      )
    }

    const { currentPassword, newPassword, force_reset } = await req.json()

    // If force_reset or user must reset password, skip current password check
    const requireCurrentPassword = !force_reset && !result.user.must_reset_password

    if (requireCurrentPassword && !currentPassword) {
      return NextResponse.json(
        { error: 'Current password is required' },
        { status: 400 }
      )
    }

    if (!newPassword) {
      return NextResponse.json(
        { error: 'New password is required' },
        { status: 400 }
      )
    }

    if (newPassword.length < 8) {
      return NextResponse.json(
        { error: 'New password must be at least 8 characters long' },
        { status: 400 }
      )
    }

    const response = await fetch(`${N8N_BASE_URL}/auth/change-password`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        user_id: result.user.id,
        current_password: currentPassword || null,
        new_password: newPassword,
        force_reset: !requireCurrentPassword
      })
    })

    const changeResult = await response.json()

    if (!response.ok || !changeResult.success) {
      return NextResponse.json(
        { error: changeResult.error || 'Failed to change password' },
        { status: response.ok ? 400 : response.status }
      )
    }

    return NextResponse.json({
      success: true,
      message: 'Password updated successfully'
    })
  } catch (error) {
    console.error('Change password error:', error)
    return NextResponse.json(
      { error: 'Failed to change password' },
      { status: 500 }
    )
  }
}
