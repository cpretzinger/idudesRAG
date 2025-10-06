'use client'
import { useState } from 'react'

export default function Home() {
  const [file, setFile] = useState<File | null>(null)
  const [status, setStatus] = useState('')
  const [uploading, setUploading] = useState(false)

  const upload = async () => {
    if (!file) return
    setUploading(true)
    setStatus('Uploading...')
    
    const formData = new FormData()
    formData.append('file', file)
    
    try {
      const res = await fetch('/api/upload', {
        method: 'POST',
        body: formData
      })
      
      const data = await res.json()
      setStatus(res.ok ? '✅ Document uploaded successfully!' : `❌ ${data.message || 'Upload failed'}`)
    } catch (error) {
      setStatus('❌ Upload failed - please try again')
    } finally {
      setUploading(false)
    }
  }

  return (
    <div className="min-h-screen bg-black flex items-center justify-center p-4">
      {/* Metallic gradient background */}
      <div className="fixed inset-0 bg-gradient-to-br from-zinc-900 via-neutral-800 to-stone-900" />
      
      {/* Subtle grid pattern overlay */}
      <div className="fixed inset-0 opacity-10" 
        style={{
          backgroundImage: `linear-gradient(0deg, #ffffff 1px, transparent 1px),
                           linear-gradient(90deg, #ffffff 1px, transparent 1px)`,
          backgroundSize: '40px 40px'
        }} 
      />
      
      <div className="relative bg-gradient-to-br from-zinc-800/90 to-neutral-900/90 backdrop-blur-xl border border-zinc-700/50 p-10 rounded-2xl shadow-2xl w-full max-w-lg">
        {/* Logo and title with metallic text effect */}
        <div className="mb-10 text-center">
          <div className="mb-4">
            <div className="text-6xl font-bold bg-gradient-to-r from-blue-400 via-cyan-300 to-blue-400 bg-clip-text text-transparent">
              🏢
            </div>
          </div>
          <h1 className="text-4xl font-bold mb-3 bg-gradient-to-r from-zinc-200 via-zinc-100 to-zinc-200 bg-clip-text text-transparent">
            Insurance Dudes
          </h1>
          <p className="text-zinc-500 font-medium">Intelligent Document Processing</p>
        </div>
        
        <div className="space-y-6">
          {/* Upload area with glass effect */}
          <div className="relative group">
            <div className="absolute -inset-0.5 bg-gradient-to-r from-blue-600 to-cyan-600 rounded-xl opacity-0 group-hover:opacity-50 blur transition duration-300" />
            <div className="relative bg-zinc-800/50 border border-zinc-700 rounded-xl p-8 text-center hover:bg-zinc-800/70 transition-all duration-300">
              <input
                type="file"
                onChange={(e) => setFile(e.target.files?.[0] || null)}
                className="hidden"
                id="file-upload"
                accept=".pdf,.txt,.doc,.docx,.md"
              />
              <label 
                htmlFor="file-upload" 
                className="cursor-pointer"
              >
                {file ? (
                  <div>
                    <div className="text-blue-400 text-4xl mb-3">📎</div>
                    <p className="text-zinc-200 font-semibold text-lg">{file.name}</p>
                    <p className="text-zinc-500 text-sm mt-2">{(file.size / 1024).toFixed(2)} KB</p>
                  </div>
                ) : (
                  <div>
                    <div className="text-zinc-600 text-5xl mb-4">📤</div>
                    <p className="text-zinc-400 font-medium text-lg">Drop document here</p>
                    <p className="text-zinc-600 text-sm mt-2">PDF, DOC, TXT, MD supported</p>
                  </div>
                )}
              </label>
            </div>
          </div>
          
          {/* Upload button with metallic gradient */}
          <button
            onClick={upload}
            disabled={!file || uploading}
            className="relative w-full group"
          >
            <div className="absolute -inset-0.5 bg-gradient-to-r from-blue-600 to-cyan-500 rounded-xl blur opacity-75 group-hover:opacity-100 transition duration-300" />
            <div className="relative w-full bg-gradient-to-r from-blue-600 to-cyan-600 text-white py-4 px-6 rounded-xl font-semibold text-lg hover:from-blue-500 hover:to-cyan-500 disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-300">
              {uploading ? (
                <span className="flex items-center justify-center">
                  <svg className="animate-spin h-5 w-5 mr-3" viewBox="0 0 24 24">
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
          
          {/* Status message with glass effect */}
          {status && (
            <div className={`relative p-4 rounded-xl backdrop-blur-sm ${
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
        
        {/* Footer */}
        <div className="mt-10 text-center">
          <p className="text-zinc-600 text-xs">
            Powered by RAG-as-a-Service © 2024
          </p>
        </div>
      </div>
    </div>
  )
}