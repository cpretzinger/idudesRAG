#!/usr/bin/env node

/**
 * Add Users to Railway PostgreSQL Database
 *
 * Users to add:
 * 1. craig.pretzinger@gmail.com (superadmin)
 * 2. jwfeltman@gmail.com (admin)
 * 3. nv@theidudes.com - Labiba (user)
 * 4. yaminnv@gmail.com - NV (user)
 * 5. rizwanvayani28@gmail.com - Rizwan (user)
 */

const { Client } = require('pg');
const bcrypt = require('bcrypt');

const RAILWAY_DB_URL = 'postgres://postgres:d7ToQHAA7VecTKi2DxFgNxtlj~xN_HnD@yamabiko.proxy.rlwy.net:15649/railway';
const SALT_ROUNDS = 10;

const users = [
  {
    name: 'Craig Pretzinger',
    email: 'craig.pretzinger@gmail.com',
    password: 'AllstateSucksDick22!',
    role: 'superadmin'
  },
  {
    name: 'Jason Feltman',
    email: 'jwfeltman@gmail.com',
    password: 'AllstateSucksDick22!',
    role: 'admin'
  },
  {
    name: 'Labiba',
    email: 'nv@theidudes.com',
    password: 'content43',
    role: 'user'
  },
  {
    name: 'NV',
    email: 'yaminnv@gmail.com',
    password: 'content33',
    role: 'user'
  },
  {
    name: 'Rizwan',
    email: 'rizwanvayani28@gmail.com',
    password: 'content54',
    role: 'user'
  }
];

async function addUsers() {
  const client = new Client({
    connectionString: RAILWAY_DB_URL,
    ssl: { rejectUnauthorized: false }
  });

  try {
    console.log('Connecting to Railway PostgreSQL...');
    await client.connect();
    console.log('✅ Connected successfully\n');

    // Check if users table exists
    const tableCheck = await client.query(`
      SELECT EXISTS (
        SELECT FROM information_schema.tables
        WHERE table_name = 'users'
      );
    `);

    if (!tableCheck.rows[0].exists) {
      console.log('❌ Users table does not exist. Creating table...\n');

      // Create users table
      await client.query(`
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
      `);

      console.log('✅ Users table created\n');
    }

    // Add each user
    for (const user of users) {
      console.log(`Processing: ${user.name} (${user.email})...`);

      // Check if user already exists
      const existingUser = await client.query(
        'SELECT id, email FROM users WHERE email = $1',
        [user.email]
      );

      if (existingUser.rows.length > 0) {
        console.log(`⚠️  User already exists: ${user.email}\n`);
        continue;
      }

      // Hash password
      console.log('  Hashing password...');
      const passwordHash = await bcrypt.hash(user.password, SALT_ROUNDS);

      // Insert user
      console.log('  Inserting into database...');
      const result = await client.query(`
        INSERT INTO users (name, email, password_hash, role, must_reset_password)
        VALUES ($1, $2, $3, $4, $5)
        RETURNING id, email, name, role
      `, [user.name, user.email, passwordHash, user.role, false]);

      console.log(`✅ User added successfully:`, result.rows[0]);
      console.log();
    }

    // Display all users
    console.log('\n📋 All Users in Database:');
    console.log('=' .repeat(80));
    const allUsers = await client.query(`
      SELECT id, name, email, role, created_at
      FROM users
      ORDER BY role DESC, name ASC
    `);

    allUsers.rows.forEach((user, index) => {
      console.log(`${index + 1}. ${user.name}`);
      console.log(`   Email: ${user.email}`);
      console.log(`   Role: ${user.role}`);
      console.log(`   Created: ${user.created_at}`);
      console.log();
    });

    console.log('✅ All operations completed successfully!');

  } catch (error) {
    console.error('❌ Error:', error.message);
    console.error(error);
    process.exit(1);
  } finally {
    await client.end();
    console.log('\n🔌 Database connection closed');
  }
}

// Run the script
addUsers();
