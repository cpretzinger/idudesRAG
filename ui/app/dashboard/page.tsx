'use client'

import { useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { useAuth } from '@/contexts/AuthContext'
import { isAdmin } from '@/lib/auth'
import Uploader from '@/components/Uploader'
import Stats from '@/components/Stats'
import Chat from '@/components/Chat'

export default function DashboardPage() {
  const { user, loading, logout } = useAuth()
  const router = useRouter()

  useEffect(() => {
    if (!loading && !user) {
      router.push('/login')
    }
  }, [user, loading, router])

  if (loading) {
    return (
      <div className="min-h-screen bg-black flex items-center justify-center">
        <div className="text-zinc-500">
          <svg className="animate-spin h-8 w-8" viewBox="0 0 24 24">
            <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" fill="none" />
            <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
          </svg>
        </div>
      </div>
    )
  }

  if (!user) return null

  const userIsAdmin = isAdmin(user)

  return (
    <div className="min-h-screen bg-black">
      {/* Metallic gradient background */}
      <div className="fixed inset-0 bg-gradient-to-br from-zinc-900 via-neutral-800 to-stone-900" />

      {/* Subtle grid overlay */}
      <div className="fixed inset-0 opacity-5"
        style={{
          backgroundImage: `linear-gradient(0deg, #ffffff 1px, transparent 1px),
                           linear-gradient(90deg, #ffffff 1px, transparent 1px)`,
          backgroundSize: '40px 40px'
        }}
      />

      {/* Header */}
      <div className="relative z-10 border-b border-zinc-700/50 bg-zinc-800/90 backdrop-blur-xl">
        <div className="max-w-7xl mx-auto px-6 py-4 flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold bg-gradient-to-r from-zinc-200 via-zinc-100 to-zinc-200 bg-clip-text text-transparent">
              🏢 Insurance Dudes RAG
            </h1>
            <p className="text-zinc-500 text-sm mt-1">
              Welcome, {user.name} • <span className="text-cyan-400">{user.role}</span>
            </p>
          </div>
          <button
            onClick={logout}
            className="px-4 py-2 rounded-lg bg-zinc-800/50 border border-zinc-700/50 text-zinc-300 hover:bg-zinc-700/50 hover:text-zinc-100 transition-all text-sm"
          >
            Logout
          </button>
        </div>
      </div>

      {/* Dashboard Content */}
      <div className="relative z-10 max-w-7xl mx-auto px-6 py-8">
        {userIsAdmin ? (
          /* Admin/Superadmin Layout - 3 components */
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 h-[calc(100vh-140px)]">
            {/* Left Column - Uploader + Stats */}
            <div className="lg:col-span-1 space-y-6">
              <Uploader />
              <Stats />
            </div>

            {/* Right Column - Chat (takes 2/3 width) */}
            <div className="lg:col-span-2">
              <Chat />
            </div>
          </div>
        ) : (
          /* User Layout - Chat only */
          <div className="h-[calc(100vh-140px)]">
            <Chat />
          </div>
        )}
      </div>
    </div>
  )
}
