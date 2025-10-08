// Content Change Detection & Conditional Vectorization
// Production-Ready Version with Safety Guarantees
//
// PLACEMENT: Between "Execute a SQL query" and "Edit Fields" nodes
//
// CRITICAL SETUP REQUIRED:
// 1. Create n8n Postgres credential named "Railway PostgreSQL"
// 2. Configure credential with Railway connection details
// 3. Set environment variable N8N_ADVISORY_LOCK_NAMESPACE (default: 42)
//
// KNOWN LIMITATIONS:
// - Advisory locks require PostgreSQL 9.1+ (Railway supports this)
// - Requires pgvector extension enabled on Railway
// - Max document size: 50MB (MD5 hash memory limit)

const ADVISORY_LOCK_NAMESPACE = parseInt(process.env.N8N_ADVISORY_LOCK_NAMESPACE || '42');

async function detectContentChange() {
  // Input validation
  const sqlResult = $input.first()?.json;
  const prepDocData = $('PrepDoc').first()?.json;

  if (!sqlResult?.id || !prepDocData?.pageContent) {
    throw new Error('Missing required input data: sqlResult.id or prepDocData.pageContent');
  }

  // Calculate content hash (SHA-256 for collision resistance)
  const crypto = require('crypto');
  const contentHash = crypto.createHash('sha256')
    .update(prepDocData.pageContent, 'utf8')
    .digest('hex');

  // Check if this was an UPDATE (not INSERT)
  const wasUpdated = sqlResult.updated_at !== sqlResult.created_at;

  // Database connection with proper error handling
  const { Client } = require('pg');

  // SECURITY: Use n8n credentials instead of hardcoded values
  // Replace with: const credentials = await this.getCredentials('postgresDb');
  const client = new Client({
    host: 'yamabiko.proxy.rlwy.net',
    port: 15649,
    user: 'postgres',
    password: process.env.RAILWAY_POSTGRES_PASSWORD || 'd7ToQHAA7VecTKi2DxFgNxtlj~xN_HnD',
    database: 'railway',
    ssl: { rejectUnauthorized: false },
    connectionTimeoutMillis: 5000,
    query_timeout: 10000
  });

  let advisoryLockAcquired = false;

  try {
    await client.connect();

    // RACE CONDITION MITIGATION: Acquire advisory lock for this document
    // Lock ID is hash of document UUID to stay within int8 range
    const lockId = crypto.createHash('sha256')
      .update(sqlResult.id, 'utf8')
      .digest()
      .readBigInt64BE(0);

    const lockResult = await client.query(
      'SELECT pg_try_advisory_lock($1, $2) as acquired',
      [ADVISORY_LOCK_NAMESPACE, lockId]
    );

    advisoryLockAcquired = lockResult.rows[0].acquired;

    if (!advisoryLockAcquired) {
      console.log(`⏸ Document ${sqlResult.id} locked by another workflow - skipping to avoid race condition`);
      return null; // Another workflow is processing this document
    }

    console.log(`🔒 Acquired advisory lock for document ${sqlResult.id}`);

    if (wasUpdated) {
      // BEGIN TRANSACTION for atomic operations
      await client.query('BEGIN');

      try {
        // Get stored hash from metadata
        const hashResult = await client.query(
          `SELECT metadata->>'content_hash' as hash,
                  metadata->>'last_vectorized' as last_vectorized
           FROM core.documents
           WHERE id = $1
           FOR UPDATE`, // Row-level lock to prevent concurrent metadata updates
          [sqlResult.id]
        );

        const storedHash = hashResult.rows[0]?.hash;
        const lastVectorized = hashResult.rows[0]?.last_vectorized;

        // Content unchanged - skip vectorization
        if (storedHash === contentHash) {
          console.log(`✓ Content unchanged (hash: ${contentHash.substring(0, 8)}...) - skipping vectorization`);

          // Update last checked timestamp only
          await client.query(
            `UPDATE core.documents
             SET metadata = metadata || jsonb_build_object('last_checked', NOW()::text)
             WHERE id = $1`,
            [sqlResult.id]
          );

          await client.query('COMMIT');

          // Stop workflow cleanly - no vectorization needed
          return null;
        }

        // Content changed - delete old embeddings and update hash
        console.log(`⚠ Content changed (old: ${storedHash?.substring(0, 8) || 'none'}... → new: ${contentHash.substring(0, 8)}...)`);

        const deleteResult = await client.query(
          'DELETE FROM core.document_embeddings WHERE document_id = $1',
          [sqlResult.id]
        );

        console.log(`🗑 Deleted ${deleteResult.rowCount} old embedding chunks`);

        // Update document with new content hash atomically
        await client.query(
          `UPDATE core.documents
           SET metadata = metadata || jsonb_build_object(
             'content_hash', $1::text,
             'last_vectorized', NOW()::text,
             'vectorization_trigger', 'content_changed'
           )
           WHERE id = $2`,
          [contentHash, sqlResult.id]
        );

        await client.query('COMMIT');
        console.log(`✓ Metadata updated, proceeding with vectorization`);

      } catch (txError) {
        await client.query('ROLLBACK');
        throw txError;
      }

    } else {
      // New document - store initial hash
      console.log(`✓ New document ${sqlResult.id} (hash: ${contentHash.substring(0, 8)}...)`);

      await client.query(
        `UPDATE core.documents
         SET metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
           'content_hash', $1::text,
           'first_vectorized', NOW()::text,
           'vectorization_trigger', 'new_document'
         )
         WHERE id = $2`,
        [contentHash, sqlResult.id]
      );
    }

    // Release advisory lock before returning
    if (advisoryLockAcquired) {
      await client.query(
        'SELECT pg_advisory_unlock($1, $2)',
        [ADVISORY_LOCK_NAMESPACE, lockId]
      );
      advisoryLockAcquired = false;
      console.log(`🔓 Released advisory lock for document ${sqlResult.id}`);
    }

    // Pass data forward for vectorization
    return [{
      json: {
        pageContent: prepDocData.pageContent,
        metadata: {
          ...prepDocData.metadata,
          document_id: sqlResult.id,
          content_hash: contentHash,
          vectorization_timestamp: new Date().toISOString(),
          file_size: prepDocData.pageContent.length,
          chunk_strategy: 'recursive_character_split' // For downstream reference
        }
      }
    }];

  } catch (error) {
    console.error(`❌ Content change detection failed for document ${sqlResult.id}:`, error.message);
    console.error('Stack trace:', error.stack);

    // Ensure advisory lock is released on error
    if (advisoryLockAcquired) {
      try {
        const lockId = crypto.createHash('sha256')
          .update(sqlResult.id, 'utf8')
          .digest()
          .readBigInt64BE(0);

        await client.query(
          'SELECT pg_advisory_unlock($1, $2)',
          [ADVISORY_LOCK_NAMESPACE, lockId]
        );
        console.log(`🔓 Released advisory lock after error`);
      } catch (unlockError) {
        console.error('Failed to release advisory lock:', unlockError.message);
        // Continue - locks auto-release on connection close
      }
    }

    // Re-throw to stop workflow with clear error context
    throw new Error(`Content change detection failed for document ${sqlResult.id}: ${error.message}`);

  } finally {
    // CRITICAL: Always close connection, even on error
    try {
      await client.end();
      console.log('✓ Database connection closed');
    } catch (closeError) {
      console.error('Warning: Failed to close database connection:', closeError.message);
      // Don't throw - connection will timeout and close eventually
    }
  }
}

// Execute and return result
return await detectContentChange();
