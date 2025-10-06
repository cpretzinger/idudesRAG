import { NextRequest, NextResponse } from 'next/server'
import { createAuthHandler } from '@/lib/middleware'

export const GET = createAuthHandler(async (req: NextRequest, user) => {
  return NextResponse.json({
    success: true,
    user: {
      id: user.id,
      email: user.email,
      name: user.name,
      role: user.role,
      mustResetPassword: user.mustResetPassword,
      lastLogin: user.lastLogin
    }
  })
})