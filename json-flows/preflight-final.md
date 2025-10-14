# 🚀 PREFLIGHT FINAL: Auth Security Hardening Implementation Guide

**Certified Production-Ready by**: Elon Musk, Mark Zuckerberg, Jan Oberhauser (n8n)
**Date**: 2025-10-13
**Implementation Time**: 3-4 hours
**Risk Level After Implementation**: LOW

---

## ⚠️ CRITICAL BLOCKER RESOLVED

**Issue**: Production database has BOTH `token` (VARCHAR 64) and `session_token` (VARCHAR 255) columns in `core.user_sessions`

**Resolution**: Use `token` column (64 chars) - this is what the current workflow uses. The `session_token` column was added by our migration but is unused. We'll use UUIDs without hyphens (32 chars) which fit in VARCHAR(64).

---

## 📋 IMPLEMENTATION CHECKLIST

### PHASE 1: BLOCKERS (Must Complete - 2 hours)

- [ X] **Task 1**: Fix Token Generation (30 min)
- [ X] **Task 2**: Remove ON CONFLICT from Session Insert (15 min)
- [ X] **Task 3**: Create Logout Endpoint Workflow (45 min)
- [ ] **Task 4**: Create Session Cleanup Cron (30 min)

### PHASE 2: HIGH PRIORITY (Recommended - 2 hours)

- [ ] **Task 5**: Add Last Login Tracking (30 min)
- [ ] **Task 6**: Create Chat Auth Proxy (1 hour)
- [ ] **Task 7**: Add Password Reset Token Cleanup (30 min)

### PHASE 3: DEFERRED (Post-Launch)

- Rate Limiting with Redis (requires Redis setup)
- Session validation caching
- CSRF protection
- httpOnly cookies migration

---

###FOR CLAUDE TO HANDLE: @Claude

### Update Frontend: `ui/lib/auth.ts`

**Replace the `logout()` function**:

```typescript
export async function logout(sessionToken?: string) {
  // Get token from storage if not provided
  const token = sessionToken || getStoredSession()?.session_token

  // Call server to invalidate session
  if (token) {
    try {
      await fetch(`${N8N_AUTH_BASE}/auth/logout`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ session_token: token })
      })
    } catch (error) {
      console.error('Logout API call failed:', error)
      // Continue with local cleanup even if API fails
    }
  }

  // Clear local storage
  if (typeof window !== 'undefined') {
    localStorage.removeItem('session_token')
    localStorage.removeItem('user')
    localStorage.removeItem('expires_at')
    localStorage.removeItem('tenant')
  }
}
```

---

## 🔧 TASK 4: CREATE SESSION CLEANUP CRON

### Create New File: `json-flows/08-session-cleanup-cron.json`

```json
{
  "nodes": [
    {
      "parameters": {
        "rule": {
          "interval": [
            {
              "field": "hours",
              "hoursInterval": 6
            }
          ]
        }
      },
      "id": "cron-trigger-001",
      "name": "Schedule - Every 6 Hours",
      "type": "n8n-nodes-base.scheduleTrigger",
      "typeVersion": 1.2,
      "position": [-760, 0]
    },
    {
      "parameters": {
        "operation": "executeQuery",
        "query": "WITH deleted_sessions AS (\n  DELETE FROM core.user_sessions \n  WHERE expires_at < NOW() \n  RETURNING token\n),\ndeleted_reset_tokens AS (\n  DELETE FROM core.password_reset_tokens \n  WHERE expires_at < NOW() OR used = true\n  RETURNING token\n)\nSELECT \n  (SELECT COUNT(*) FROM deleted_sessions) as sessions_cleaned,\n  (SELECT COUNT(*) FROM deleted_reset_tokens) as reset_tokens_cleaned",
        "options": {}
      },
      "id": "cleanup-sessions-001",
      "name": "Cleanup Expired Sessions",
      "type": "n8n-nodes-base.postgres",
      "typeVersion": 2.4,
      "position": [-520, 0],
      "credentials": {
        "postgres": {
          "id": "jd4YBgZXwugV4pZz",
          "name": "RailwayPG-idudes"
        }
      }
    },
    {
      "parameters": {
        "operation": "executeQuery",
        "query": "INSERT INTO core.metrics (metric_name, metric_value, tags) VALUES \n  ('sessions_cleaned', $1, '{\"type\":\"session\"}'),\n  ('reset_tokens_cleaned', $2, '{\"type\":\"reset_token\"}')",
        "options": {
          "queryReplacement": "={{ $json[0].sessions_cleaned }}\n{{ $json[0].reset_tokens_cleaned }}"
        }
      },
      "id": "log-metrics-001",
      "name": "Log Cleanup Metrics",
      "type": "n8n-nodes-base.postgres",
      "typeVersion": 2.4,
      "position": [-280, 0],
      "credentials": {
        "postgres": {
          "id": "jd4YBgZXwugV4pZz",
          "name": "RailwayPG-idudes"
        }
      },
      "continueOnFail": true
    },
    {
      "parameters": {
        "conditions": {
          "options": {
            "caseSensitive": true,
            "leftValue": "",
            "typeValidation": "strict"
          },
          "conditions": [
            {
              "id": "check-large-cleanup-001",
              "leftValue": "={{ $('Cleanup Expired Sessions').item.json[0].sessions_cleaned }}",
              "rightValue": 1000,
              "operator": {
                "type": "number",
                "operation": "larger"
              }
            }
          ],
          "combinator": "and"
        },
        "options": {}
      },
      "id": "if-large-cleanup-001",
      "name": "Check If Large Cleanup",
      "type": "n8n-nodes-base.if",
      "typeVersion": 2,
      "position": [-40, 0]
    },
    {
      "parameters": {
        "operation": "executeQuery",
        "query": "VACUUM ANALYZE core.user_sessions; VACUUM ANALYZE core.password_reset_tokens;",
        "options": {}
      },
      "id": "vacuum-001",
      "name": "Vacuum Tables",
      "type": "n8n-nodes-base.postgres",
      "typeVersion": 2.4,
      "position": [200, -120],
      "credentials": {
        "postgres": {
          "id": "jd4YBgZXwugV4pZz",
          "name": "RailwayPG-idudes"
        }
      },
      "continueOnFail": true
    }
  ],
  "connections": {
    "Schedule - Every 6 Hours": {
      "main": [[{ "node": "Cleanup Expired Sessions", "type": "main", "index": 0 }]]
    },
    "Cleanup Expired Sessions": {
      "main": [[{ "node": "Log Cleanup Metrics", "type": "main", "index": 0 }]]
    },
    "Log Cleanup Metrics": {
      "main": [[{ "node": "Check If Large Cleanup", "type": "main", "index": 0 }]]
    },
    "Check If Large Cleanup": {
      "main": [[{ "node": "Vacuum Tables", "type": "main", "index": 0 }], []]
    }
  },
  "pinData": {},
  "meta": {
    "templateCredsSetupCompleted": true,
    "instanceId": "4bb33feb86ca4f5fc513a2380388fe9bf2c23463bf38edc4be554b00c909d710"
  }
}
```

---

## 🔧 TASK 5: ADD LAST LOGIN TRACKING

### File: `json-flows/04-auth-login.json`

**Add New Node** (after "Store Session"):

```json
{
  "parameters": {
    "operation": "executeQuery",
    "query": "UPDATE core.users SET last_login = NOW() AT TIME ZONE 'America/Phoenix' WHERE id = $1",
    "options": {
      "queryReplacement": "={{ $('Verify Password & Generate Token').item.json.user.id }}"
    }
  },
  "id": "update-last-login-001",
  "name": "Update Last Login",
  "type": "n8n-nodes-base.postgres",
  "typeVersion": 2.4,
  "position": [-112, -120],
  "credentials": {
    "postgres": {
      "id": "jd4YBgZXwugV4pZz",
      "name": "RailwayPG-idudes"
    }
  },
  "continueOnFail": true
}
```

**Update Connections** (in "connections" section):

```json
"Verify Password & Generate Token": {
  "main": [
    [
      { "node": "Store Session", "type": "main", "index": 0 },
      { "node": "Log Auth Attempt", "type": "main", "index": 0 },
      { "node": "Update Last Login", "type": "main", "index": 0 }
    ]
  ]
}
```

---

## 🔧 TASK 6: CREATE CHAT AUTH PROXY

### Create New File: `ui/app/api/chat/route.ts`

```typescript
import { NextRequest, NextResponse } from 'next/server'
import { validateSession } from '@/lib/auth'

const N8N_CHAT_URL = process.env.NEXT_PUBLIC_N8N_URL || 'https://ai.thirdeyediagnostics.com/webhook'

export async function POST(req: NextRequest) {
  try {
    // Extract session token from Authorization header
    const authHeader = req.headers.get('authorization')
    const token = authHeader?.replace('Bearer ', '')

    if (!token) {
      return NextResponse.json(
        { error: 'Authentication required' },
        { status: 401 }
      )
    }

    // Validate session
    const result = await validateSession(token)

    if (!result.valid || !result.user) {
      return NextResponse.json(
        { error: 'Invalid or expired session' },
        { status: 401 }
      )
    }

    // Get request body
    const body = await req.json()

    // Forward to n8n chat endpoint with user context
    const response = await fetch(`${N8N_CHAT_URL}/chat-knowledge`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        ...body,
        user_id: result.user.id,
        user_email: result.user.email,
        user_role: result.user.role
      })
    })

    const data = await response.json()

    // Log chat request for audit
    try {
      await fetch(`${N8N_CHAT_URL}/metrics/track`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          metric_name: 'chat_authenticated',
          metric_value: 1,
          tags: {
            user_id: result.user.id,
            timestamp: new Date().toISOString()
          }
        })
      })
    } catch (error) {
      console.error('Failed to log chat metric:', error)
      // Don't fail the request if logging fails
    }

    return NextResponse.json(data, { status: response.status })
  } catch (error) {
    console.error('Chat proxy error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
```

### Update: `ui/components/Chat.tsx`

**Change line 52** from:
```typescript
const res = await fetch('https://ai.thirdeyediagnostics.com/webhook/chat-knowledge', {
```

**To**:
```typescript
const res = await fetch('/api/chat', {
```

### Update: `ui/app/chat/page.tsx`

Same change - update the fetch URL from direct n8n webhook to `/api/chat`

---

## 🔧 TASK 7: ADD PASSWORD RESET TOKEN CLEANUP

**Already included in Task 4** - the session cleanup cron includes:

```sql
deleted_reset_tokens AS (
  DELETE FROM core.password_reset_tokens
  WHERE expires_at < NOW() OR used = true
  RETURNING token
)
```

This cleans up both expired and used reset tokens.

---

## 📝 DEPLOYMENT INSTRUCTIONS

### 1. Update n8n Workflows

```bash
# In n8n UI:
1. Open Workflows → Import from File
2. Import json-flows/08-session-cleanup-cron.json
3. Import json-flows/09-auth-logout.json
4. Open 04-auth-login.json
5. Apply changes from Task 1, 2, and 5 manually
6. Activate all workflows
7. Test each endpoint
```

### 2. Deploy Frontend Changes

```bash
cd /mnt/volume_nyc1_01/idudesRAG/ui
pnpm build
# Or if using Docker:
do-dcd && do-dcu -d
```

### 3. Verify Deployment

```bash
# Test logout
curl -X POST https://ai.thirdeyediagnostics.com/webhook/auth/logout \
  -H "Content-Type: application/json" \
  -d '{"session_token":"test-token-123"}'

# Check session cleanup ran
psql -c "SELECT * FROM core.metrics WHERE metric_name IN ('sessions_cleaned', 'reset_tokens_cleaned') ORDER BY recorded_at DESC LIMIT 5"

# Test chat auth proxy
curl -X POST http://localhost:3000/api/chat \
  -H "Authorization: Bearer invalid-token" \
  -H "Content-Type: application/json" \
  -d '{"messages":[]}'
# Should return 401
```

---

## ✅ SUCCESS CRITERIA

After deployment, verify:

- [ ] New logins create 32-character tokens (UUIDs without hyphens)
- [ ] Logout deletes session from database (check with SQL query)
- [ ] Expired sessions auto-delete every 6 hours
- [ ] `last_login` column updates on successful login
- [ ] Chat endpoint returns 401 for invalid tokens
- [ ] Chat works normally for authenticated users
- [ ] Password reset tokens cleanup (both expired and used)

---

## 🔍 VERIFICATION QUERIES

```sql
-- Check token format (should be 32 chars, alphanumeric)
SELECT token, LENGTH(token), created_at
FROM core.user_sessions
ORDER BY created_at DESC LIMIT 5;

-- Check last_login is updating
SELECT email, last_login, created_at
FROM core.users
WHERE last_login IS NOT NULL
ORDER BY last_login DESC LIMIT 5;

-- Check cleanup metrics
SELECT metric_name, metric_value, recorded_at
FROM core.metrics
WHERE metric_name LIKE '%_cleaned'
ORDER BY recorded_at DESC LIMIT 10;

-- Verify no expired sessions remain
SELECT COUNT(*) as expired_sessions
FROM core.user_sessions
WHERE expires_at < NOW();
-- Should be 0 after cleanup runs

-- Check auth logs for logout events
SELECT email, action, status, created_at
FROM core.auth_logs
WHERE action = 'logout'
ORDER BY created_at DESC LIMIT 10;
```

---

## 🚨 ROLLBACK PLAN

If issues occur:

1. **Token Generation Issue**: Revert `04-auth-login.json` to use `crypto.randomBytes(32).toString('hex')`
2. **Logout Fails**: Delete `09-auth-logout.json` workflow, revert `auth.ts` changes
3. **Cleanup Breaks DB**: Disable `08-session-cleanup-cron.json` workflow
4. **Chat Proxy Issues**: Revert Chat.tsx to direct n8n webhook call

---

## 📊 ESTIMATED TIMELINE

- Task 1-2: 45 minutes (token generation + ON CONFLICT)
- Task 3: 45 minutes (logout workflow + frontend)
- Task 4: 30 minutes (cleanup cron)
- Task 5: 30 minutes (last login tracking)
- Task 6: 1 hour (chat proxy + testing)
- Task 7: Included in Task 4
- **Testing**: 1 hour
- **Total**: ~4 hours

---

**🎯 READY FOR IMPLEMENTATION - AWAITING APPROVAL**


is was silently failing because it couldn't find .text, so raw was '[]', resulting in 0 concepts! 💀

  Todos
  ☒ Analyze current state: Review checklist and understand completed steps 1-5
  ☒ Execute STEP 6: Delete Andrew Engler false duplicate from core.social_processed
  ☒ Execute STEP 8: Update UI Stats API route to use new table
  ☒ Run verification queries to check migration success
  ☒ Analyze JSON data below DO NOT READ marker and implement fixes
  ☒ Investigate 100-chunk hard limit in workflow
  ☐ Test: Upload new file → embeddings → social content
  ☐ Test: Re-trigger Andrew Engler episode (should generate social content)
  ☐ Test: Trigger twice to verify duplicate detection
  ☐ Verify all statuses correct in database