/**
 * N8N-Native Authentication Wrapper
 * 
 * This minimal wrapper delegates all auth logic to n8n webhooks.
 * Zero dependencies - uses native fetch API.
 * 
 * Architecture:
 * - Login: POST to n8n webhook, get session token
 * - Validate: POST to n8n webhook, check session validity
 * - Reset: POST to n8n webhook, send reset email via Gmail
 */

// ============================================================================
// TYPE DEFINITIONS
// ============================================================================

/**
 * User entity returned from auth endpoints
 */
export interface User {
  id: string
  email: string
  name: string
  role: 'admin' | 'user'
}

/**
 * Login response from n8n webhook
 */
export interface LoginResponse {
  success: boolean
  session_token?: string
  user?: User
  error?: string
}

/**
 * Session validation response from n8n webhook
 */
export interface ValidateResponse {
  valid: boolean
  user?: User
}

/**
 * Password reset response from n8n webhook
 */
export interface ResetResponse {
  success: boolean
  message?: string
  error?: string
}

// ============================================================================
// CONFIGURATION
// ============================================================================

const N8N_BASE_URL = process.env.NEXT_PUBLIC_N8N_URL || 'https://ai.thirdeyediagnostics.com/webhook'

// ============================================================================
// AUTH FUNCTIONS
// ============================================================================

/**
 * Login user with email and password
 * Calls n8n webhook which validates credentials and creates session
 */
export async function login(email: string, password: string): Promise<LoginResponse> {
  try {
    const response = await fetch(`${N8N_BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password })
    })

    if (!response.ok) {
      return {
        success: false,
        error: 'Login request failed'
      }
    }

    return await response.json()
  } catch (error) {
    console.error('Login error:', error)
    return {
      success: false,
      error: 'Network error during login'
    }
  }
}

/**
 * Validate session token
 * Calls n8n webhook which checks session in database
 * Returns user data if session is valid and not expired
 */
export async function validateSession(token: string): Promise<User | null> {
  try {
    const response = await fetch(`${N8N_BASE_URL}/auth/validate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ session_token: token })
    })

    if (!response.ok) {
      return null
    }

    const data: ValidateResponse = await response.json()
    return data.valid ? (data.user || null) : null
  } catch (error) {
    console.error('Session validation error:', error)
    return null
  }
}

/**
 * Request password reset email
 * Calls n8n webhook which sends reset email via Gmail OAuth
 */
export async function requestPasswordReset(email: string): Promise<boolean> {
  try {
    const response = await fetch(`${N8N_BASE_URL}/auth/reset-password`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email })
    })

    if (!response.ok) {
      return false
    }

    const data: ResetResponse = await response.json()
    return data.success || false
  } catch (error) {
    console.error('Password reset error:', error)
    return false
  }
}

/**
 * Logout user by deleting session
 * Note: Session deletion is handled client-side by clearing cookie
 * Could optionally call n8n to delete session from database
 */
export async function logout(): Promise<void> {
  // Optional: Call n8n to delete session from database
  // For now, just clear client-side cookie (handled by Next.js API route)
  try {
    await fetch('/api/auth/logout', { method: 'POST' })
  } catch (error) {
    console.error('Logout error:', error)
  }
}

// ============================================================================
// MIDDLEWARE HELPER
// ============================================================================

/**
 * Check if user has required role
 * Used for role-based access control
 */
export function hasRole(userRole: User['role'], requiredRole: User['role']): boolean {
  const roleHierarchy: Record<User['role'], number> = {
    user: 0,
    admin: 1
  }
  
  return roleHierarchy[userRole] >= roleHierarchy[requiredRole]
}