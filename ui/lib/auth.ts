import bcrypt from 'bcryptjs'
import { Pool } from 'pg'
import { randomBytes } from 'crypto'

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
})

export interface User {
  id: string
  email: string
  name: string
  role: 'superadmin' | 'admin' | 'user'
  mustResetPassword: boolean
  lastLogin: Date | null
}

export interface Session {
  id: string
  userId: string
  token: string
  expiresAt: Date
}

// Hash password
export async function hashPassword(password: string): Promise<string> {
  return bcrypt.hash(password, 10)
}

// Verify password
export async function verifyPassword(password: string, hash: string): Promise<boolean> {
  return bcrypt.compare(password, hash)
}

// Generate session token
export function generateSessionToken(): string {
  return randomBytes(32).toString('hex')
}

// Create user session
export async function createSession(userId: string): Promise<Session> {
  const client = await pool.connect()
  try {
    const token = generateSessionToken()
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000) // 7 days

    const result = await client.query(
      'INSERT INTO user_sessions (user_id, session_token, expires_at) VALUES ($1, $2, $3) RETURNING *',
      [userId, token, expiresAt]
    )

    return {
      id: result.rows[0].id,
      userId: result.rows[0].user_id,
      token: result.rows[0].session_token,
      expiresAt: result.rows[0].expires_at
    }
  } finally {
    client.release()
  }
}

// Get user by session token
export async function getUserBySessionToken(token: string): Promise<User | null> {
  const client = await pool.connect()
  try {
    const result = await client.query(`
      SELECT u.id, u.email, u.name, u.role, u.must_reset_password, u.last_login
      FROM users u
      JOIN user_sessions s ON u.id = s.user_id
      WHERE s.session_token = $1 AND s.expires_at > NOW()
    `, [token])

    if (result.rows.length === 0) {
      return null
    }

    const row = result.rows[0]
    return {
      id: row.id,
      email: row.email,
      name: row.name,
      role: row.role,
      mustResetPassword: row.must_reset_password,
      lastLogin: row.last_login
    }
  } finally {
    client.release()
  }
}

// Authenticate user
export async function authenticateUser(email: string, password: string): Promise<User | null> {
  const client = await pool.connect()
  try {
    const result = await client.query(
      'SELECT id, email, name, password_hash, role, must_reset_password, last_login FROM users WHERE email = $1',
      [email]
    )

    if (result.rows.length === 0) {
      return null
    }

    const user = result.rows[0]
    const isValidPassword = await verifyPassword(password, user.password_hash)

    if (!isValidPassword) {
      return null
    }

    // Update last login
    await client.query(
      'UPDATE users SET last_login = NOW() WHERE id = $1',
      [user.id]
    )

    return {
      id: user.id,
      email: user.email,
      name: user.name,
      role: user.role,
      mustResetPassword: user.must_reset_password,
      lastLogin: new Date()
    }
  } finally {
    client.release()
  }
}

// Update user password
export async function updateUserPassword(userId: string, newPassword: string): Promise<boolean> {
  const client = await pool.connect()
  try {
    const hashedPassword = await hashPassword(newPassword)
    await client.query(
      'UPDATE users SET password_hash = $1, must_reset_password = false WHERE id = $2',
      [hashedPassword, userId]
    )
    return true
  } catch (error) {
    console.error('Error updating password:', error)
    return false
  } finally {
    client.release()
  }
}

// Delete session
export async function deleteSession(token: string): Promise<void> {
  const client = await pool.connect()
  try {
    await client.query('DELETE FROM user_sessions WHERE session_token = $1', [token])
  } finally {
    client.release()
  }
}

// Create password reset token
export async function createPasswordResetToken(email: string): Promise<string | null> {
  const client = await pool.connect()
  try {
    // Check if user exists
    const userResult = await client.query('SELECT id FROM users WHERE email = $1', [email])
    if (userResult.rows.length === 0) {
      return null
    }

    const userId = userResult.rows[0].id
    const token = randomBytes(32).toString('hex')
    const expiresAt = new Date(Date.now() + 60 * 60 * 1000) // 1 hour

    await client.query(
      'INSERT INTO password_reset_tokens (user_id, token, expires_at) VALUES ($1, $2, $3)',
      [userId, token, expiresAt]
    )

    return token
  } finally {
    client.release()
  }
}

// Verify password reset token
export async function verifyPasswordResetToken(token: string): Promise<string | null> {
  const client = await pool.connect()
  try {
    const result = await client.query(`
      SELECT user_id FROM password_reset_tokens 
      WHERE token = $1 AND expires_at > NOW() AND used = false
    `, [token])

    if (result.rows.length === 0) {
      return null
    }

    return result.rows[0].user_id
  } finally {
    client.release()
  }
}

// Use password reset token
export async function usePasswordResetToken(token: string): Promise<void> {
  const client = await pool.connect()
  try {
    await client.query('UPDATE password_reset_tokens SET used = true WHERE token = $1', [token])
  } finally {
    client.release()
  }
}

// Check if user has permission
export function hasPermission(userRole: string, requiredRole: string): boolean {
  const roleHierarchy = {
    'user': 0,
    'admin': 1,
    'superadmin': 2
  }

  const userLevel = roleHierarchy[userRole as keyof typeof roleHierarchy] ?? -1
  const requiredLevel = roleHierarchy[requiredRole as keyof typeof roleHierarchy] ?? 999

  return userLevel >= requiredLevel
}