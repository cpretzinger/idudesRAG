'use client'

import { useState } from 'react'

interface Message {
  role: 'user' | 'assistant'
  content: string
}

export default function Chat() {
  const [messages, setMessages] = useState<Message[]>([])
  const [input, setInput] = useState('')
  const [loading, setLoading] = useState(false)

  const sendMessage = async () => {
    if (!input.trim()) return

    const userMessage = { role: 'user' as const, content: input }
    setMessages(prev => [...prev, userMessage])
    setInput('')
    setLoading(true)

    try {
      const res = await fetch('https://ai.thirdeyediagnostics.com/webhook/chat-knowledge', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
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
    <div className="bg-gradient-to-br from-zinc-800/90 to-neutral-900/90 backdrop-blur-xl border border-zinc-700/50 rounded-2xl flex flex-col h-full">
      <div className="p-6 border-b border-zinc-700/50">
        <h2 className="text-xl font-bold bg-gradient-to-r from-zinc-200 to-zinc-100 bg-clip-text text-transparent">
          💬 AI Assistant
        </h2>
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto p-6 space-y-4">
        {messages.length === 0 && (
          <div className="text-center text-zinc-500 mt-12">
            <div className="text-5xl mb-3">💬</div>
            <p className="text-lg">Start a conversation</p>
            <p className="text-sm mt-1 text-zinc-600">Ask questions about your documents</p>
          </div>
        )}

        {messages.map((msg, idx) => (
          <div
            key={idx}
            className={`flex ${msg.role === 'user' ? 'justify-end' : 'justify-start'}`}
          >
            <div
              className={`max-w-[85%] rounded-xl px-4 py-3 ${
                msg.role === 'user'
                  ? 'bg-gradient-to-r from-blue-600 to-cyan-600 text-white'
                  : 'bg-zinc-800/70 border border-zinc-700/50 text-zinc-200'
              }`}
            >
              <p className="whitespace-pre-wrap text-sm">{msg.content}</p>
            </div>
          </div>
        ))}

        {loading && (
          <div className="flex justify-start">
            <div className="bg-zinc-800/70 border border-zinc-700/50 rounded-xl px-4 py-3">
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
      <div className="p-4 border-t border-zinc-700/50">
        <div className="bg-zinc-800/50 border border-zinc-700/50 rounded-xl p-2 flex gap-2">
          <input
            type="text"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyPress={(e) => e.key === 'Enter' && !e.shiftKey && sendMessage()}
            placeholder="Ask anything..."
            className="flex-1 bg-transparent text-zinc-200 px-3 py-2 outline-none placeholder-zinc-500 text-sm"
            disabled={loading}
          />
          <button
            onClick={sendMessage}
            disabled={!input.trim() || loading}
            className="bg-gradient-to-r from-blue-600 to-cyan-600 text-white px-5 py-2 rounded-lg font-semibold text-sm hover:from-blue-500 hover:to-cyan-500 disabled:opacity-50 disabled:cursor-not-allowed transition-all"
          >
            Send
          </button>
        </div>
        <p className="text-zinc-600 text-xs mt-2 text-center">
          Powered by GPT-5-nano
        </p>
      </div>
    </div>
  )
}
