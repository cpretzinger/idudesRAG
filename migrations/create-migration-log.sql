-- Create migration log table for tracking schema changes
CREATE TABLE IF NOT EXISTS core.migration_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    migration_name VARCHAR(255) NOT NULL,
    phase VARCHAR(100) NOT NULL,
    status VARCHAR(50) NOT NULL, -- 'started', 'completed', 'failed'
    details TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Index for querying migration history
CREATE INDEX IF NOT EXISTS idx_migration_log_name_phase ON core.migration_log(migration_name, phase);
CREATE INDEX IF NOT EXISTS idx_migration_log_created_at ON core.migration_log(created_at DESC);