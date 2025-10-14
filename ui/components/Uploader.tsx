'use client'

import { useState } from 'react'
import { useAuth } from '@/contexts/AuthContext'

export default function Uploader() {
  const { session } = useAuth()
  const [file, setFile] = useState<File | null>(null)
  const [status, setStatus] = useState('')
  const [uploading, setUploading] = useState(false)

  const upload = async () => {
    if (!file) return
    setUploading(true)
    setStatus('Uploading...')

    try {
      // Create FormData to send file as binary (required by n8n workflow)
      const formData = new FormData()
      formData.append('file', file, file.name)

      // Send to Next.js API proxy which validates session
      const res = await fetch('/api/upload', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${session?.session_token || ''}`
        },
        body: formData
      })

      const data = await res.json()
      setStatus(res.ok ? '✅ Document uploaded successfully to RAG-Pending!' : `❌ ${data.message || data.error || 'Upload failed'}`)

      if (res.ok) {
        setFile(null)
      }
    } catch {
      setStatus('❌ Upload failed - please try again')
    } finally {
      setUploading(false)
    }
  }

  return (
    <div className="bg-gradient-to-br from-zinc-800/90 to-neutral-900/90 backdrop-blur-xl border border-zinc-700/50 rounded-2xl p-6">
      <h2 className="text-xl font-bold bg-gradient-to-r from-zinc-200 to-zinc-100 bg-clip-text text-transparent mb-6">
        📤 Document Upload
      </h2>

      <div className="space-y-4">
        {/* Upload area */}
        <div className="relative group">
          <div className="absolute -inset-0.5 bg-gradient-to-r from-blue-600 to-cyan-600 rounded-xl opacity-0 group-hover:opacity-50 blur transition duration-300" />
          <div className="relative bg-zinc-800/50 border border-zinc-700 rounded-xl p-6 text-center hover:bg-zinc-800/70 transition-all duration-300">
            <input
              type="file"
              onChange={(e) => setFile(e.target.files?.[0] || null)}
              className="hidden"
              id="file-upload"
              accept=".pdf,.txt,.doc,.docx,.md"
            />
            <label htmlFor="file-upload" className="cursor-pointer">
              {file ? (
                <div>
                  <div className="text-blue-400 text-3xl mb-2">📎</div>
                  <p className="text-zinc-200 font-semibold">{file.name}</p>
                  <p className="text-zinc-500 text-sm mt-1">{(file.size / 1024).toFixed(2)} KB</p>
                </div>
              ) : (
                <div>
                  <div className="text-zinc-600 text-4xl mb-3">📤</div>
                  <p className="text-zinc-400 font-medium">Drop document here</p>
                  <p className="text-zinc-600 text-sm mt-1">PDF, DOC, TXT, MD supported</p>
                </div>
              )}
            </label>
          </div>
        </div>

        {/* Upload button */}
        <button
          onClick={upload}
          disabled={!file || uploading}
          className="relative w-full group"
        >
          <div className="absolute -inset-0.5 bg-gradient-to-r from-blue-600 to-cyan-500 rounded-xl blur opacity-75 group-hover:opacity-100 transition duration-300" />
          <div className="relative w-full bg-gradient-to-r from-blue-600 to-cyan-600 text-white py-3 px-6 rounded-xl font-semibold hover:from-blue-500 hover:to-cyan-500 disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-300">
            {uploading ? (
              <span className="flex items-center justify-center">
                <svg className="animate-spin h-5 w-5 mr-2" viewBox="0 0 24 24">
                  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" fill="none" />
                  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
                </svg>
                Processing...
              </span>
            ) : (
              'Upload Document'
            )}
          </div>
        </button>

        {/* Status */}
        {status && (
          <div className={`p-3 rounded-xl backdrop-blur-sm ${
            status.includes('✅')
              ? 'bg-green-900/20 border border-green-700/50'
              : 'bg-red-900/20 border border-red-700/50'
          }`}>
            <p className={`text-sm font-medium ${
              status.includes('✅') ? 'text-green-300' : 'text-red-300'
            }`}>
              {status}
            </p>
          </div>
        )}
      </div>
    </div>
  )
}
