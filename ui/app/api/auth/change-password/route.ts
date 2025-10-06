import { NextRequest, NextResponse } from 'next/server'
import { createAuthHandler } from '@/lib/middleware'
import { updateUserPassword, verifyPassword, hashPassword } from '@/lib/auth'
import { Pool } from 'pg'

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
})

export const POST = createAuthHandler(async (req: NextRequest, user) => {
  try {
    const { currentPassword, newPassword } = await req.json()

    if (!currentPassword || !newPassword) {
      return NextResponse.json(
        { error: 'Current password and new password are required' },
        { status: 400 }
      )
    }

    if (newPassword.length < 8) {
      return NextResponse.json(
        { error: 'New password must be at least 8 characters long' },
        { status: 400 }
      )
    }

    // Get current password hash
    const client = await pool.connect()
    try {
      const result = await client.query(
        'SELECT password_hash FROM users WHERE id = $1',
        [user.id]
      )

      if (result.rows.length === 0) {
        return NextResponse.json(
          { error: 'User not found' },
          { status: 404 }
        )
      }

      const currentHash = result.rows[0].password_hash

      // Verify current password
      const isValidCurrentPassword = await verifyPassword(currentPassword, currentHash)
      if (!isValidCurrentPassword) {
        return NextResponse.json(
          { error: 'Current password is incorrect' },
          { status: 400 }
        )
      }

      // Update password
      const success = await updateUserPassword(user.id, newPassword)
      
      if (!success) {
        return NextResponse.json(
          { error: 'Failed to update password' },
          { status: 500 }
        )
      }

      return NextResponse.json({
        success: true,
        message: 'Password updated successfully'
      })
    } finally {
      client.release()
    }
  } catch (error) {
    console.error('Change password error:', error)
    return NextResponse.json(
      { error: 'Failed to change password' },
      { status: 500 }
    )
  }
})