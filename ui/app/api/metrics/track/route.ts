import { NextRequest, NextResponse } from 'next/server'
import { Client, type ClientConfig } from 'pg'

// Railway PostgreSQL connection configuration
const DB_CONFIG: ClientConfig = {
  host: process.env.RAILWAY_PGVECTOR_HOST || 'yamabiko.proxy.rlwy.net',
  port: parseInt(process.env.RAILWAY_PGVECTOR_PORT || '15649'),
  user: process.env.RAILWAY_PGVECTOR_USER || 'postgres',
  password: process.env.RAILWAY_PGVECTOR_PASSWORD || 'd7ToQHAA7VecTKi2DxFgNxtlj~xN_HnD',
  database: process.env.RAILWAY_PGVECTOR_DB || 'railway'
}

interface TrackMetricRequest {
  metric_name: string
  metric_value: number
  tags?: Record<string, string | number | boolean>
}

export async function POST(request: NextRequest): Promise<NextResponse> {
  try {
    const body: TrackMetricRequest = await request.json()

    // Validate required fields
    if (!body.metric_name || body.metric_value === undefined) {
      return NextResponse.json(
        { error: 'metric_name and metric_value are required' },
        { status: 400 }
      )
    }

    const client = new Client({
      ...DB_CONFIG,
      ssl: { rejectUnauthorized: false }
    })

    await client.connect()

    // Insert metric into core.metrics table
    await client.query(
      `INSERT INTO core.metrics (metric_name, metric_value, tags)
       VALUES ($1, $2, $3)`,
      [
        body.metric_name,
        body.metric_value,
        JSON.stringify(body.tags || {})
      ]
    )

    await client.end()

    return NextResponse.json({
      success: true,
      message: 'Metric tracked successfully'
    })

  } catch (error) {
    console.error('Metrics tracking error:', error)
    return NextResponse.json(
      { error: 'Failed to track metric' },
      { status: 500 }
    )
  }
}
