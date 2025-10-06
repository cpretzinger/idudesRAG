-- Users and Authentication Schema
-- Add to existing PostgreSQL database

-- Create users table
CREATE TABLE IF NOT EXISTS users (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL CHECK (role IN ('superadmin', 'admin', 'user')),
    must_reset_password BOOLEAN DEFAULT true,
    last_login TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Create sessions table for JWT alternative
CREATE TABLE IF NOT EXISTS user_sessions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    session_token VARCHAR(255) UNIQUE NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Create password reset tokens table
CREATE TABLE IF NOT EXISTS password_reset_tokens (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    token VARCHAR(255) UNIQUE NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    used BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Insert initial users with default password 'idudes2025'
-- Password hash for 'idudes2025' using bcrypt
INSERT INTO users (email, name, password_hash, role, must_reset_password) VALUES
    ('craig@theidudes.com', 'Craig Pretzinger', '$2b$10$rQr0Vv8X9yGz7gQV2oKJ1ePcA8nS7lD8xF4tR9wE5kJ2mN6pL3qH7', 'superadmin', true),
    ('jwfeltman@gmail.com', 'Jason Feltman', '$2b$10$rQr0Vv8X9yGz7gQV2oKJ1ePcA8nS7lD8xF4tR9wE5kJ2mN6pL3qH7', 'superadmin', true),
    ('lannie@theidudes.com', 'Lannie', '$2b$10$rQr0Vv8X9yGz7gQV2oKJ1ePcA8nS7lD8xF4tR9wE5kJ2mN6pL3qH7', 'admin', true),
    ('nv@theidudes.com', 'Labiba (NV)', '$2b$10$rQr0Vv8X9yGz7gQV2oKJ1ePcA8nS7lD8xF4tR9wE5kJ2mN6pL3qH7', 'user', true),
    ('yaminnv@gmail.com', 'NV (Yamin)', '$2b$10$rQr0Vv8X9yGz7gQV2oKJ1ePcA8nS7lD8xF4tR9wE5kJ2mN6pL3qH7', 'user', true),
    ('rizwanvayani28@gmail.com', 'Rizwan Vayani', '$2b$10$rQr0Vv8X9yGz7gQV2oKJ1ePcA8nS7lD8xF4tR9wE5kJ2mN6pL3qH7', 'user', true)
ON CONFLICT (email) DO NOTHING;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_user_sessions_token ON user_sessions(session_token);
CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id ON user_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_token ON password_reset_tokens(token);

-- Update function for updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Add trigger for users table
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();