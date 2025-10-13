'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { useAuth } from '@/contexts/AuthContext'
import { requestPasswordReset } from '@/lib/auth'

export default function LoginPage() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [info, setInfo] = useState('')
  const [loading, setLoading] = useState(false)
  const { login, user } = useAuth()
  const router = useRouter()

  useEffect(() => {
    if (user) {
      router.push('/dashboard')
    }
  }, [user, router])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    setInfo('')
    setLoading(true)

    const result = await login(email, password)

    if (result.success) {
      router.push('/dashboard')
    } else {
      setError(result.error || 'Login failed')
      setLoading(false)
    }
  }

  const handleForgotPassword = async () => {
    setError('')
    setInfo('')
    if (!email) {
      setError('Enter your email above first')
      return
    }
    setLoading(true)
    const res = await requestPasswordReset(email)
    setLoading(false)
    if (res.success) {
      setInfo('If an account exists, a reset link was sent.')
    } else {
      setError(res.error || 'Could not request password reset')
    }
  }

  return (
    <div className="min-h-screen bg-black flex items-center justify-center p-4 relative overflow-hidden">
      {/* Animated metallic gradient background */}
      <div className="absolute inset-0 bg-gradient-to-br from-zinc-900 via-neutral-800 to-stone-900">
        <div className="absolute inset-0 bg-[radial-gradient(circle_at_50%_50%,rgba(120,119,198,0.1),transparent_50%)]" />
        <div className="absolute inset-0 bg-gradient-to-tr from-zinc-800/20 via-transparent to-neutral-700/20 animate-pulse" />
      </div>

      {/* Metallic shine overlay */}
      <div className="absolute inset-0 bg-gradient-to-br from-white/5 via-transparent to-white/5 pointer-events-none" />

      <div className="relative z-10 w-full max-w-md">
        {/* Login card with metallic border */}
        <div className="relative backdrop-blur-xl bg-gradient-to-br from-zinc-900/90 via-neutral-900/80 to-stone-900/90 border border-zinc-700/50 rounded-2xl shadow-2xl shadow-black/50 overflow-hidden">
          {/* Metallic top edge highlight */}
          <div className="absolute top-0 left-0 right-0 h-px bg-gradient-to-r from-transparent via-zinc-500 to-transparent" />

          <div className="p-8">
            {/* Logo/Title */}
            <div className="text-center mb-8">
              <h1 className="text-3xl font-bold bg-gradient-to-r from-zinc-200 via-neutral-100 to-stone-200 bg-clip-text text-transparent mb-2">
                iDudes RAG
              </h1>
              <p className="text-zinc-400 text-sm">Secure Authentication</p>
            </div>

            {/* Error/Info messages */}
            {error && (
              <div className="mb-6 p-4 rounded-lg bg-red-500/10 border border-red-500/30 backdrop-blur-sm">
                <p className="text-red-400 text-sm flex items-center gap-2">
                  <span className="text-lg">⚠️</span>
                  {error}
                </p>
              </div>
            )}
            {info && !error && (
              <div className="mb-6 p-4 rounded-lg bg-emerald-500/10 border border-emerald-500/30 backdrop-blur-sm">
                <p className="text-emerald-400 text-sm flex items-center gap-2">
                  <span className="text-lg">✅</span>
                  {info}
                </p>
              </div>
            )}

            {/* Login form */}
            <form onSubmit={handleSubmit} className="space-y-6">
              <div>
                <label htmlFor="email" className="block text-sm font-medium text-zinc-300 mb-2">
                  Email Address
                </label>
                <input
                  id="email"
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  required
                  disabled={loading}
                  className="w-full px-4 py-3 rounded-lg bg-zinc-800/50 border border-zinc-700/50 text-zinc-100 placeholder-zinc-500 focus:outline-none focus:ring-2 focus:ring-zinc-500/50 focus:border-zinc-500 transition-all disabled:opacity-50 disabled:cursor-not-allowed backdrop-blur-sm"
                  placeholder="you@example.com"
                />
              </div>

              <div>
                <label htmlFor="password" className="block text-sm font-medium text-zinc-300 mb-2">
                  Password
                </label>
                <input
                  id="password"
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  required
                  disabled={loading}
                  className="w-full px-4 py-3 rounded-lg bg-zinc-800/50 border border-zinc-700/50 text-zinc-100 placeholder-zinc-500 focus:outline-none focus:ring-2 focus:ring-zinc-500/50 focus:border-zinc-500 transition-all disabled:opacity-50 disabled:cursor-not-allowed backdrop-blur-sm"
                  placeholder="••••••••"
                />
              </div>

              <button
                type="submit"
                disabled={loading}
                className="w-full py-3 px-4 rounded-lg font-medium text-white relative overflow-hidden group disabled:opacity-50 disabled:cursor-not-allowed transition-all"
              >
                {/* Metallic gradient background */}
                <div className="absolute inset-0 bg-gradient-to-r from-zinc-700 via-neutral-600 to-stone-700 group-hover:from-zinc-600 group-hover:via-neutral-500 group-hover:to-stone-600 transition-all duration-300" />

                {/* Shine effect */}
                <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/20 to-transparent translate-x-[-100%] group-hover:translate-x-[100%] transition-transform duration-700" />

                {/* Button text */}
                <span className="relative z-10">
                  {loading ? (
                    <span className="flex items-center justify-center gap-2">
                      <svg className="animate-spin h-5 w-5" viewBox="0 0 24 24">
                        <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" fill="none" />
                        <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
                      </svg>
                      Signing in...
                    </span>
                  ) : (
                    'Sign In'
                  )}
                </span>
              </button>
            </form>

            {/* Footer links */}
            <div className="mt-6 text-center">
              <button onClick={handleForgotPassword} className="text-sm text-zinc-400 hover:text-zinc-300 transition-colors">
                Forgot password?
              </button>
            </div>
          </div>

          {/* Metallic bottom edge highlight */}
          <div className="absolute bottom-0 left-0 right-0 h-px bg-gradient-to-r from-transparent via-zinc-700 to-transparent" />
        </div>

        {/* Subtle glow effect */}
        <div className="absolute inset-0 -z-10 bg-gradient-to-b from-zinc-500/5 to-transparent blur-3xl" />
      </div>
    </div>
  )
}
