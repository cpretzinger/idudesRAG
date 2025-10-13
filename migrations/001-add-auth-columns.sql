-- Migration: Add missing authentication columns to users table
-- Date: 2025-10-13
-- Purpose: Add must_reset_password and last_login columns for enhanced security
-- Schema: core

-- Add must_reset_password column (forces password change on first login)
ALTER TABLE core.users
ADD COLUMN IF NOT EXISTS must_reset_password BOOLEAN DEFAULT true;

-- Add last_login column (tracks user login activity)
ALTER TABLE core.users
ADD COLUMN IF NOT EXISTS last_login TIMESTAMP;

-- Update existing users to require password reset on next login
UPDATE core.users
SET must_reset_password = true
WHERE must_reset_password IS NULL;

-- Verify migration
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'core'
        AND table_name = 'users'
        AND column_name = 'must_reset_password'
    ) THEN
        RAISE NOTICE 'SUCCESS: must_reset_password column added';
    ELSE
        RAISE EXCEPTION 'FAILED: must_reset_password column not found';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'core'
        AND table_name = 'users'
        AND column_name = 'last_login'
    ) THEN
        RAISE NOTICE 'SUCCESS: last_login column added';
    ELSE
        RAISE EXCEPTION 'FAILED: last_login column not found';
    END IF;
END $$;

-- Show updated table structure
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'core'
AND table_name = 'users'
ORDER BY ordinal_position;
