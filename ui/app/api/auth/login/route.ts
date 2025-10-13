import { NextRequest, NextResponse } from 'next/server'
import { login } from '@/lib/auth'

// Handle GET requests - redirect to login page
export async function GET(req: NextRequest) {
  const returnTo = req.nextUrl.searchParams.get('returnTo') || '/dashboard'
  const loginUrl = `/login?returnTo=${encodeURIComponent(returnTo)}`
  return NextResponse.redirect(new URL(loginUrl, req.url))
}

export async function POST(req: NextRequest) {
  try {
    const { email, password } = await req.json()

    if (!email || !password) {
      return NextResponse.json(
        { error: 'Email and password are required' },
        { status: 400 }
      )
    }

    const result = await login(email, password)

    if (!result.success || !result.session_token || !result.user) {
      return NextResponse.json(
        { error: result.error || 'Invalid credentials' },
        { status: 401 }
      )
    }

    const response = NextResponse.json({
      success: true,
      user: result.user
    })

    response.cookies.set('session_token', result.session_token, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'lax',
      maxAge: 7 * 24 * 60 * 60,
      path: '/'
    })

    return response
  } catch (error) {
    console.error('Login error:', error)
    return NextResponse.json(
      { error: 'Login failed' },
      { status: 500 }
    )
  }
}
