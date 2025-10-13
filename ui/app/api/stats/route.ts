import { NextResponse } from 'next/server'
import { Client, type ClientConfig } from 'pg'

// Type definition for database row counts
interface CountResult {
  count: string
}

// Type definition for average size calculation
interface AvgSizeResult {
  avg_size: number | null
}

// Type definition for API response
interface StatsResponse {
  total_documents: number
  total_embeddings: number
  total_queries: number
  avg_document_size: number
  last_updated: string
}

// Railway PostgreSQL connection configuration
const DB_CONFIG: ClientConfig = {
  host: process.env.RAILWAY_PGVECTOR_HOST || 'yamabiko.proxy.rlwy.net',
  port: parseInt(process.env.RAILWAY_PGVECTOR_PORT || '15649'),
  user: process.env.RAILWAY_PGVECTOR_USER || 'postgres',
  password: process.env.RAILWAY_PGVECTOR_PASSWORD || 'd7ToQHAA7VecTKi2DxFgNxtlj~xN_HnD',
  database: process.env.RAILWAY_PGVECTOR_DB || 'railway'
}

export async function GET(): Promise<NextResponse<StatsResponse | { error: string }>> {
  try {
    const client = new Client({
      ...DB_CONFIG,
      ssl: { rejectUnauthorized: false }
    })

    await client.connect()

    // Get all stats in parallel
    const [filesResult, embeddingsResult, queriesResult] = await Promise.all([
      // Total files (from file_status table)
      client.query<CountResult>("SELECT COUNT(*)::text as count FROM core.file_status WHERE status = 'completed'"),

      // Total embeddings (chunks)
      client.query<CountResult>("SELECT COUNT(*)::text as count FROM core.embeddings"),

      // Total queries from metrics table (return 0 if no metrics exist)
      client.query<CountResult>(`
        SELECT COALESCE(SUM(metric_value), 0)::text as count
        FROM core.metrics
        WHERE metric_name = 'chat_queries'
      `)
    ])

    // Calculate average chunk size from embeddings
    const avgSizeResult = await client.query<AvgSizeResult>(`
      SELECT COALESCE(AVG(chunk_size), 0) as avg_size
      FROM core.embeddings
      WHERE chunk_size > 0
    `)

    await client.end()

    return NextResponse.json({
      total_documents: parseInt(filesResult.rows[0]?.count || '0'),
      total_embeddings: parseInt(embeddingsResult.rows[0]?.count || '0'),
      total_queries: parseInt(queriesResult.rows[0]?.count || '0'),
      avg_document_size: Math.round(avgSizeResult.rows[0]?.avg_size || 0),
      last_updated: new Date().toISOString()
    })

  } catch (error) {
    console.error('Stats API error:', error)
    return NextResponse.json(
      { error: 'Failed to fetch stats' },
      { status: 500 }
    )
  }
}
