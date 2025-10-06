import { NextRequest, NextResponse } from 'next/server'
import { Pool } from 'pg'
import { createAuthHandler } from '@/lib/middleware'

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
})

export const POST = createAuthHandler(async (req: NextRequest, user) => {
  try {
    const { query, limit = 10 } = await req.json()
    
    if (!query) {
      return NextResponse.json({ error: 'Query is required' }, { status: 400 })
    }

    // Generate embedding for query
    const embeddingResponse = await fetch('https://api.openai.com/v1/embeddings', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        input: query,
        model: 'text-embedding-3-small',
        dimensions: 1536
      })
    })

    if (!embeddingResponse.ok) {
      throw new Error('Failed to generate embedding')
    }

    const embeddingData = await embeddingResponse.json()
    const queryEmbedding = embeddingData.data[0].embedding

    // Search documents using vector similarity
    const client = await pool.connect()
    
    const searchQuery = `
      SELECT 
        d.id as document_id,
        d.filename,
        d.spaces_url,
        de.chunk_text,
        1 - (de.embedding <=> $1::vector) as similarity
      FROM document_embeddings de
      JOIN documents d ON d.id = de.document_id
      WHERE 1 - (de.embedding <=> $1::vector) > 0.7
      ORDER BY de.embedding <=> $1::vector
      LIMIT $2
    `
    
    const result = await client.query(searchQuery, [JSON.stringify(queryEmbedding), limit])
    client.release()

    return NextResponse.json({
      success: true,
      query,
      results: result.rows,
      count: result.rows.length
    })

  } catch (error) {
    console.error('Search error:', error)
    return NextResponse.json({
      error: 'Search failed',
      details: error instanceof Error ? error.message : 'Unknown error'
    }, { status: 500 })
  }
})

export const GET = createAuthHandler(async (req: NextRequest, user) => {
  const { searchParams } = req.nextUrl
  const query = searchParams.get('q')
  const limit = parseInt(searchParams.get('limit') || '10')

  if (!query) {
    return NextResponse.json({ error: 'Query parameter "q" is required' }, { status: 400 })
  }

  // Redirect GET to POST for consistency
  return POST(new NextRequest(req.url, {
    method: 'POST',
    body: JSON.stringify({ query, limit }),
    headers: { 'Content-Type': 'application/json' }
  }))
})