import { NextRequest, NextResponse } from 'next/server'
import { getUserBySessionToken, hasPermission, type User } from './auth'

export interface AuthenticatedRequest extends NextRequest {
  user?: User
}

export async function withAuth(
  req: NextRequest,
  requiredRole: 'user' | 'admin' | 'superadmin' = 'user'
): Promise<{ user: User | null; error: NextResponse | null }> {
  const token = req.cookies.get('session_token')?.value

  if (!token) {
    return {
      user: null,
      error: NextResponse.json(
        { error: 'Authentication required', code: 'NO_TOKEN' },
        { status: 401 }
      )
    }
  }

  try {
    const user = await getUserBySessionToken(token)

    if (!user) {
      return {
        user: null,
        error: NextResponse.json(
          { error: 'Invalid session', code: 'INVALID_SESSION' },
          { status: 401 }
        )
      }
    }

    if (!hasPermission(user.role, requiredRole)) {
      return {
        user: null,
        error: NextResponse.json(
          { error: 'Insufficient permissions', code: 'INSUFFICIENT_PERMISSIONS' },
          { status: 403 }
        )
      }
    }

    return { user, error: null }
  } catch (error) {
    console.error('Auth middleware error:', error)
    return {
      user: null,
      error: NextResponse.json(
        { error: 'Authentication error', code: 'AUTH_ERROR' },
        { status: 500 }
      )
    }
  }
}

export function createAuthHandler<T>(
  handler: (req: NextRequest, user: User) => Promise<NextResponse>,
  requiredRole: 'user' | 'admin' | 'superadmin' = 'user'
) {
  return async (req: NextRequest): Promise<NextResponse> => {
    const { user, error } = await withAuth(req, requiredRole)
    
    if (error || !user) {
      return error || NextResponse.json({ error: 'Authentication failed' }, { status: 401 })
    }

    return handler(req, user)
  }
}