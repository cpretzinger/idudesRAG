// Auth utilities and types
export type UserRole = 'user' | 'admin' | 'superadmin'

export interface User {
  id: string
  email: string
  name: string
  role: UserRole
}

export interface AuthSession {
  session_token: string
  user: User
  expires_at: string
  tenant: string
}

export interface AuthResponse {
  success: boolean
  session_token?: string
  user?: User
  expires_at?: string
  tenant?: string
  error?: string
}

const N8N_AUTH_BASE = process.env.NEXT_PUBLIC_N8N_URL || 'https://ai.thirdeyediagnostics.com/webhook'

export async function login(email: string, password: string): Promise<AuthResponse> {
  const res = await fetch(`${N8N_AUTH_BASE}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password })
  })

  return res.json()
}

export async function validateSession(sessionToken: string): Promise<{ valid: boolean; user?: User; error?: string }> {
  const res = await fetch(`${N8N_AUTH_BASE}/auth/validate`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ session_token: sessionToken })
  })

  return res.json()
}

export async function requestPasswordReset(email: string): Promise<{ success: boolean; message?: string; error?: string }> {
  const res = await fetch(`${N8N_AUTH_BASE}/auth/reset-password`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email })
  })

  if (!res.ok) {
    return { success: false, error: 'Reset request failed' }
  }

  return res.json()
}

export async function logout() {
  if (typeof window !== 'undefined') {
    localStorage.removeItem('session_token')
    localStorage.removeItem('user')
  }
}

export function getStoredSession(): AuthSession | null {
  if (typeof window === 'undefined') return null

  const token = localStorage.getItem('session_token')
  const userStr = localStorage.getItem('user')
  const expiresAt = localStorage.getItem('expires_at')
  const tenant = localStorage.getItem('tenant')

  if (!token || !userStr) return null

  try {
    return {
      session_token: token,
      user: JSON.parse(userStr),
      expires_at: expiresAt || '',
      tenant: tenant || 'idudes'
    }
  } catch {
    return null
  }
}

export function storeSession(session: AuthSession) {
  if (typeof window === 'undefined') return

  localStorage.setItem('session_token', session.session_token)
  localStorage.setItem('user', JSON.stringify(session.user))
  localStorage.setItem('expires_at', session.expires_at)
  localStorage.setItem('tenant', session.tenant)
}

export function hasRole(user: User | null, allowedRoles: UserRole[]): boolean {
  if (!user) return false
  return allowedRoles.includes(user.role)
}

export function isAdmin(user: User | null): boolean {
  return hasRole(user, ['admin', 'superadmin'])
}

export function isSuperAdmin(user: User | null): boolean {
  return hasRole(user, ['superadmin'])
}
