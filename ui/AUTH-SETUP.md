# Auth System Setup - Insurance Dudes RAG

## Overview

Complete role-based authentication system with metallic gradient design integrating with n8n workflows.

## User Roles

- **user** - Chat access only
- **admin** - Uploader + Stats + Chat
- **superadmin** - Uploader + Stats + Chat (future: additional admin features)

## Pages

### `/login`
- Metallic gradient login form
- Integrates with n8n `/auth/login` webhook
- Session token stored in localStorage
- Auto-redirects to dashboard if already authenticated

### `/dashboard`
- **Protected route** - requires authentication
- **Users**: See only Chat component (full screen)
- **Admins/Superadmins**: See 3-column layout:
  - Left column: Uploader + Stats (stacked)
  - Right column (2/3 width): Chat

## Components

### `AuthProvider` (contexts/AuthContext.tsx)
- Global auth state management
- Session validation with n8n
- Login/logout functionality
- Auto-checks session on mount

### `Uploader` (components/Uploader.tsx)
- Document upload with drag & drop
- Base64 encoding for n8n webhook
- Status feedback
- Admin/Superadmin only

### `Stats` (components/Stats.tsx)
- Real-time system metrics
- 4 stat cards: Documents, Embeddings, Queries, Avg Response Time
- TODO: Connect to actual stats API
- Admin/Superadmin only

### `Chat` (components/Chat.tsx)
- AI assistant interface
- Connects to n8n `/chat-knowledge` webhook
- GPT-5-nano powered
- Available to all authenticated users

## n8n Workflows Required

### 1. `/auth/login`
**File**: `json-flows/04-auth-login.json`

**Request**:
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

**Response (Success)**:
```json
{
  "success": true,
  "session_token": "abc123...",
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "name": "John Doe",
    "role": "admin"
  },
  "expires_at": "2025-01-15T00:00:00.000Z",
  "tenant": "idudes"
}
```

**Response (Failure)**:
```json
{
  "success": false,
  "error": "Invalid credentials"
}
```

### 2. `/auth/validate`
**File**: `json-flows/05-auth-validate.json`

**Request**:
```json
{
  "session_token": "abc123..."
}
```

**Response (Valid)**:
```json
{
  "valid": true,
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "name": "John Doe",
    "role": "admin"
  },
  "expires_at": "2025-01-15T00:00:00.000Z",
  "tenant": "idudes"
}
```

**Response (Invalid)**:
```json
{
  "valid": false,
  "error": "Invalid or expired session"
}
```

### 3. `/auth/reset-password`
**File**: `json-flows/06-auth-reset-password.json`
**Status**: TODO

## Database Schema Required

### `users` table
```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('user', 'admin', 'superadmin')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### `user_sessions` table
```sql
CREATE TABLE user_sessions (
  token TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### `auth_logs` table
```sql
CREATE TABLE auth_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant TEXT NOT NULL,
  email TEXT NOT NULL,
  action TEXT NOT NULL,
  status TEXT NOT NULL,
  ip_address TEXT,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

## Environment Variables

### `/ui/.env.local`
```bash
NEXT_PUBLIC_N8N_URL=https://ai.thirdeyediagnostics.com/webhook
```

## Setup Steps

1. **Deploy n8n workflows**:
   - Import `04-auth-login.json` to n8n
   - Import `05-auth-validate.json` to n8n
   - Update PostgreSQL credential IDs in workflows

2. **Create database tables**:
   - Run SQL schema above on Railway PostgreSQL

3. **Create test user**:
   ```sql
   INSERT INTO users (email, name, password_hash, role)
   VALUES (
     'admin@idudes.com',
     'Admin User',
     '$2b$10$...',  -- bcrypt hash of 'password123'
     'admin'
   );
   ```

4. **Start UI**:
   ```bash
   cd ui
   pnpm install
   pnpm dev
   ```

5. **Test login**:
   - Navigate to `http://localhost:3000/login`
   - Login with test credentials
   - Should redirect to `/dashboard`
   - Verify role-based component visibility

## Design System

### Colors
- **Background**: Black with zinc/neutral/stone gradients
- **Cards**: `from-zinc-800/90 to-neutral-900/90` with backdrop blur
- **Borders**: `border-zinc-700/50` for glass effect
- **Primary Action**: `from-blue-600 to-cyan-600` gradient
- **Text**: Zinc gradients for metallic effect

### Typography
- **Headings**: Gradient text with `bg-clip-text text-transparent`
- **Body**: `text-zinc-200` on dark backgrounds
- **Muted**: `text-zinc-500` or `text-zinc-600`

### Effects
- **Metallic shine**: Gradient overlays with opacity
- **Hover states**: Opacity and color transitions
- **Glass morphism**: Backdrop blur + semi-transparent backgrounds
- **Grid overlay**: Subtle repeating linear gradient at 5-10% opacity

## Security Notes

- Session tokens stored in localStorage (consider httpOnly cookies for production)
- No automatic token refresh (user must re-login after 7 days)
- Passwords hashed with bcrypt in n8n workflow
- All auth attempts logged to `auth_logs` table
- IP and user agent tracked for security auditing

## Next Steps

1. Implement password reset flow (`06-auth-reset-password.json`)
2. Add "Remember me" functionality
3. Implement token refresh endpoint
4. Add admin panel for user management (superadmin only)
5. Connect Stats component to actual API
6. Add email verification for new signups
7. Implement 2FA (optional)

---

**Status**: ✅ Complete and ready for testing
**Last Updated**: 2025-10-07
