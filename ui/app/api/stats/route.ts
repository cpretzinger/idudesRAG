import { NextResponse } from 'next/server'

// Railway PostgreSQL connection
const DB_CONFIG = {
  host: process.env.RAILWAY_PGVECTOR_HOST || 'yamabiko.proxy.rlwy.net',
  port: parseInt(process.env.RAILWAY_PGVECTOR_PORT || '15649'),
  user: process.env.RAILWAY_PGVECTOR_USER || 'postgres',
  password: process.env.RAILWAY_PGVECTOR_PASSWORD || 'd7ToQHAA7VecTKi2DxFgNxtlj~xN_HnD',
  database: process.env.RAILWAY_PGVECTOR_DB || 'railway'
}

export async function GET() {
  try {
    const { Client } = require('pg')
    const client = new Client({
      ...DB_CONFIG,
      ssl: { rejectUnauthorized: false }
    })

    await client.connect()

    // Get all stats in parallel
    const [documentsResult, embeddingsResult, queriesResult] = await Promise.all([
      // Total documents
      client.query('SELECT COUNT(*) as count FROM core.documents'),

      // Total embeddings (chunks)
      client.query('SELECT COUNT(*) as count FROM core.document_embeddings'),

      // Total queries (if you have a queries table, otherwise mock it)
      // Replace with actual query if you track chat queries
      Promise.resolve({ rows: [{ count: 0 }] })
    ])

    // Calculate average document size
    const avgSizeResult = await client.query(`
      SELECT AVG(file_size) as avg_size
      FROM core.documents
      WHERE file_size > 0
    `)

    await client.end()

    return NextResponse.json({
      total_documents: parseInt(documentsResult.rows[0].count),
      total_embeddings: parseInt(embeddingsResult.rows[0].count),
      total_queries: parseInt(queriesResult.rows[0].count), // TODO: track actual queries
      avg_document_size: Math.round(avgSizeResult.rows[0].avg_size || 0),
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
