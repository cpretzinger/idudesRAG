'use client'

import { createContext, useContext, useState, useEffect, ReactNode } from 'react'
import { User, AuthSession, login as authLogin, validateSession, logout as authLogout, getStoredSession, storeSession } from '@/lib/auth'

interface AuthContextType {
  user: User | null
  session: AuthSession | null
  loading: boolean
  login: (email: string, password: string) => Promise<{ success: boolean; error?: string }>
  logout: () => Promise<void>
  checkSession: () => Promise<void>
}

const AuthContext = createContext<AuthContextType | undefined>(undefined)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null)
  const [session, setSession] = useState<AuthSession | null>(null)
  const [loading, setLoading] = useState(true)

  const checkSession = async () => {
    const storedSession = getStoredSession()

    if (!storedSession) {
      setLoading(false)
      return
    }

    try {
      const result = await validateSession(storedSession.session_token)

      if (result.valid && result.user) {
        setUser(result.user)
        setSession(storedSession)
      } else {
        // Invalid session - clear storage
        await authLogout()
        setUser(null)
        setSession(null)
      }
    } catch (error) {
      console.error('Session validation failed:', error)
      await authLogout()
      setUser(null)
      setSession(null)
    } finally {
      setLoading(false)
    }
  }

  const login = async (email: string, password: string) => {
    try {
      const result = await authLogin(email, password)

      if (result.success && result.session_token && result.user) {
        const newSession: AuthSession = {
          session_token: result.session_token,
          user: result.user,
          expires_at: result.expires_at || '',
          tenant: result.tenant || 'idudes'
        }

        storeSession(newSession)
        setUser(result.user)
        setSession(newSession)

        return { success: true }
      } else {
        return { success: false, error: result.error || 'Login failed' }
      }
    } catch (error) {
      return { success: false, error: 'Network error - please try again' }
    }
  }

  const logout = async () => {
    await authLogout()
    setUser(null)
    setSession(null)
  }

  useEffect(() => {
    checkSession()
  }, [])

  return (
    <AuthContext.Provider value={{ user, session, loading, login, logout, checkSession }}>
      {children}
    </AuthContext.Provider>
  )
}

export function useAuth() {
  const context = useContext(AuthContext)
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider')
  }
  return context
}
