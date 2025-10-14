'use client'
import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import { useAuth } from '@/contexts/AuthContext'

interface Message {
  role: 'user' | 'assistant'
  content: string
}

export default function ChatPage() {
  const { user, session, loading: authLoading } = useAuth()
  const router = useRouter()
  const [messages, setMessages] = useState<Message[]>([])
  const [input, setInput] = useState('')
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    if (!authLoading && !user) {
      router.push('/login')
    }
  }, [user, authLoading, router])

  if (authLoading) {
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

  const sendMessage = async () => {
    if (!input.trim()) return

    const userMessage = { role: 'user' as const, content: input }
    setMessages(prev => [...prev, userMessage])
    setInput('')
    setLoading(true)

    try {
      const res = await fetch('/api/chat', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${session?.session_token || ''}`
        },
        body: JSON.stringify({
          messages: [...messages, userMessage],
          model: 'gpt-5-nano'
        })
      })

      const data = await res.json()

      if (data.message) {
        setMessages(prev => [...prev, { role: 'assistant', content: data.message }])
      }
    } catch {
      setMessages(prev => [...prev, {
        role: 'assistant',
        content: 'Error: Failed to get response'
      }])
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-black flex flex-col">
      <div className="fixed inset-0 bg-gradient-to-br from-zinc-900 via-neutral-800 to-stone-900" />

      <div className="fixed inset-0 opacity-10"
        style={{
          backgroundImage: `linear-gradient(0deg, #ffffff 1px, transparent 1px),
                           linear-gradient(90deg, #ffffff 1px, transparent 1px)`,
          backgroundSize: '40px 40px'
        }}
      />

      {/* Header */}
      <div className="relative z-10 border-b border-zinc-700/50 bg-zinc-800/90 backdrop-blur-xl">
        <div className="max-w-4xl mx-auto px-6 py-4 flex items-center justify-between">
          <h1 className="text-2xl font-bold bg-gradient-to-r from-zinc-200 via-zinc-100 to-zinc-200 bg-clip-text text-transparent">
            🏢 Insurance Dudes - AI Assistant
          </h1>
          <Link
            href="/dashboard"
            className="text-zinc-400 hover:text-zinc-200 transition-colors text-sm"
          >
            ← Back to Dashboard
          </Link>
        </div>
      </div>

      {/* Chat Container */}
      <div className="relative flex-1 overflow-hidden">
        <div className="max-w-4xl mx-auto h-full flex flex-col px-6 py-8">

          {/* Messages */}
          <div className="flex-1 overflow-y-auto mb-6 space-y-4">
            {messages.length === 0 && (
              <div className="text-center text-zinc-500 mt-20">
                <div className="text-6xl mb-4">💬</div>
                <p className="text-lg">Start a conversation with GPT-5-nano</p>
                <p className="text-sm mt-2">Ask questions, search documents, or generate content</p>
              </div>
            )}

            {messages.map((msg, idx) => (
              <div
                key={idx}
                className={`flex ${msg.role === 'user' ? 'justify-end' : 'justify-start'}`}
              >
                <div
                  className={`max-w-[80%] rounded-2xl px-6 py-4 ${
                    msg.role === 'user'
                      ? 'bg-gradient-to-r from-blue-600 to-cyan-600 text-white'
                      : 'bg-zinc-800/70 border border-zinc-700/50 text-zinc-200'
                  }`}
                >
                  <p className="whitespace-pre-wrap">{msg.content}</p>
                </div>
              </div>
            ))}

            {loading && (
              <div className="flex justify-start">
                <div className="bg-zinc-800/70 border border-zinc-700/50 rounded-2xl px-6 py-4">
                  <div className="flex items-center space-x-2">
                    <div className="w-2 h-2 bg-zinc-400 rounded-full animate-bounce" style={{ animationDelay: '0ms' }} />
                    <div className="w-2 h-2 bg-zinc-400 rounded-full animate-bounce" style={{ animationDelay: '150ms' }} />
                    <div className="w-2 h-2 bg-zinc-400 rounded-full animate-bounce" style={{ animationDelay: '300ms' }} />
                  </div>
                </div>
              </div>
            )}
          </div>

          {/* Input */}
          <div className="relative">
            <div className="bg-zinc-800/90 border border-zinc-700/50 rounded-2xl p-2 flex gap-2">
              <input
                type="text"
                value={input}
                onChange={(e) => setInput(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && !e.shiftKey && sendMessage()}
                placeholder="Ask anything..."
                className="flex-1 bg-transparent text-zinc-200 px-4 py-3 outline-none placeholder-zinc-500"
                disabled={loading}
              />
              <button
                onClick={sendMessage}
                disabled={!input.trim() || loading}
                className="bg-gradient-to-r from-blue-600 to-cyan-600 text-white px-6 py-3 rounded-xl font-semibold hover:from-blue-500 hover:to-cyan-500 disabled:opacity-50 disabled:cursor-not-allowed transition-all"
              >
                Send
              </button>
            </div>
            <p className="text-zinc-600 text-xs mt-2 text-center">
              Powered by GPT-5-nano • Cost optimized for classification and search
            </p>
          </div>
        </div>
      </div>
    </div>
  )
}
