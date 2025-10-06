-- ============================================================================
-- N8N-NATIVE AUTH - SIMPLE DATABASE SCHEMA
-- ============================================================================
-- This schema creates 2 minimal tables for n8n-powered authentication
-- No password reset tokens table needed (handled in-memory by n8n)
-- ============================================================================

-- Drop existing tables if they exist (careful in production!)
DROP TABLE IF EXISTS user_sessions CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- ============================================================================
-- TABLE 1: users
-- ============================================================================
CREATE TABLE users (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(50) DEFAULT 'user' CHECK (role IN ('admin', 'user')),
    created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- TABLE 2: user_sessions
-- ============================================================================
CREATE TABLE user_sessions (
    token VARCHAR(64) PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- INDEXES for performance
-- ============================================================================
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_sessions_user_id ON user_sessions(user_id);
CREATE INDEX idx_sessions_expires ON user_sessions(expires_at);

-- ============================================================================
-- DEFAULT USERS
-- ============================================================================
-- Password for all users: "idudes2025"
-- Hash generated with: bcrypt.hash("idudes2025", 10)
-- ============================================================================

INSERT INTO users (email, name, password_hash, role) VALUES
    ('craig@theidudes.com', 'Craig Pretzinger', '$2b$10$rQr0Vv8X9yGz7gQV2oKJ1ePcA8nS7lD8xF4tR9wE5kJ2mN6pL3qH7', 'admin'),
    ('jwfeltman@gmail.com', 'Jason Feltman', '$2b$10$rQr0Vv8X9yGz7gQV2oKJ1ePcA8nS7lD8xF4tR9wE5kJ2mN6pL3qH7', 'admin'),
    ('lannie@theidudes.com', 'Lannie', '$2b$10$rQr0Vv8X9yGz7gQV2oKJ1ePcA8nS7lD8xF4tR9wE5kJ2mN6pL3qH7', 'admin'),
    ('nv@theidudes.com', 'Labiba (NV)', '$2b$10$rQr0Vv8X9yGz7gQV2oKJ1ePcA8nS7lD8xF4tR9wE5kJ2mN6pL3qH7', 'user'),
    ('yaminnv@gmail.com', 'NV (Yamin)', '$2b$10$rQr0Vv8X9yGz7gQV2oKJ1ePcA8nS7lD8xF4tR9wE5kJ2mN6pL3qH7', 'user'),
    ('rizwanvayani28@gmail.com', 'Rizwan Vayani', '$2b$10$rQr0Vv8X9yGz7gQV2oKJ1ePcA8nS7lD8xF4tR9wE5kJ2mN6pL3qH7', 'user')
ON CONFLICT (email) DO NOTHING;

-- ============================================================================
-- AUTOMATIC SESSION CLEANUP (Optional)
-- ============================================================================
-- Create a function to delete expired sessions
CREATE OR REPLACE FUNCTION cleanup_expired_sessions()
RETURNS void AS $$
BEGIN
    DELETE FROM user_sessions WHERE expires_at < NOW();
END;
$$ LANGUAGE plpgsql;

-- To run cleanup manually: SELECT cleanup_expired_sessions();
-- To schedule automatic cleanup, use pg_cron or external scheduler

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================
-- Run these to verify the schema was created correctly:
-- 
-- Check users table:
-- SELECT id, email, name, role, created_at FROM users;
-- 
-- Check sessions table (should be empty):
-- SELECT * FROM user_sessions;
-- 
-- Check indexes:
-- SELECT tablename, indexname FROM pg_indexes WHERE tablename IN ('users', 'user_sessions');
-- ============================================================================

-- Schema created successfully!
-- Next step: Import n8n workflow (json-flows/n8n-auth-workflow.json)