'use client'

import { useState, useEffect } from 'react'

interface StatsData {
  total_documents: number
  total_embeddings: number
  total_queries: number
  avg_document_size: number
  last_updated?: string
}

export default function Stats() {
  const [stats, setStats] = useState<StatsData | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(false)

  useEffect(() => {
    fetchStats()
    // Refresh stats every 30 seconds
    const interval = setInterval(fetchStats, 30000)
    return () => clearInterval(interval)
  }, [])

  const fetchStats = async () => {
    try {
      const res = await fetch('/api/stats')
      if (!res.ok) throw new Error('Failed to fetch')

      const data = await res.json()
      setStats(data)
      setError(false)
    } catch (err) {
      console.error('Failed to fetch stats:', err)
      setError(true)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="bg-gradient-to-br from-zinc-800/90 to-neutral-900/90 backdrop-blur-xl border border-zinc-700/50 rounded-2xl p-6">
      <h2 className="text-xl font-bold bg-gradient-to-r from-zinc-200 to-zinc-100 bg-clip-text text-transparent mb-6">
        📊 System Stats
      </h2>

      {loading ? (
        <div className="flex items-center justify-center py-12">
          <svg className="animate-spin h-8 w-8 text-zinc-500" viewBox="0 0 24 24">
            <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" fill="none" />
            <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
          </svg>
        </div>
      ) : error ? (
        <div className="text-center py-12">
          <div className="text-zinc-500 mb-3">Failed to load stats</div>
          <button
            onClick={fetchStats}
            className="text-sm text-cyan-400 hover:text-cyan-300 transition-colors"
          >
            Retry
          </button>
        </div>
      ) : stats ? (
        <div>
          <div className="grid grid-cols-2 gap-4">
            {/* Documents */}
            <div className="bg-zinc-800/50 border border-zinc-700/50 rounded-xl p-4">
              <div className="text-3xl mb-2">📄</div>
              <div className="text-2xl font-bold text-zinc-100">{stats.total_documents.toLocaleString()}</div>
              <div className="text-sm text-zinc-500">Documents</div>
            </div>

            {/* Embeddings */}
            <div className="bg-zinc-800/50 border border-zinc-700/50 rounded-xl p-4">
              <div className="text-3xl mb-2">🔢</div>
              <div className="text-2xl font-bold text-zinc-100">{stats.total_embeddings.toLocaleString()}</div>
              <div className="text-sm text-zinc-500">Vector Chunks</div>
            </div>

            {/* Queries */}
            <div className="bg-zinc-800/50 border border-zinc-700/50 rounded-xl p-4">
              <div className="text-3xl mb-2">💬</div>
              <div className="text-2xl font-bold text-zinc-100">{stats.total_queries.toLocaleString()}</div>
              <div className="text-sm text-zinc-500">Chat Queries</div>
            </div>

            {/* Avg Document Size */}
            <div className="bg-zinc-800/50 border border-zinc-700/50 rounded-xl p-4">
              <div className="text-3xl mb-2">📊</div>
              <div className="text-2xl font-bold text-zinc-100">{(stats.avg_document_size / 1024).toFixed(1)}KB</div>
              <div className="text-sm text-zinc-500">Avg Doc Size</div>
            </div>
          </div>

          {stats.last_updated && (
            <div className="mt-3 text-xs text-zinc-600 text-center">
              Last updated: {new Date(stats.last_updated).toLocaleTimeString()}
            </div>
          )}
        </div>
      ) : null}
    </div>
  )
}
