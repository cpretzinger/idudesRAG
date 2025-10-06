# ✅ N8N AUTH TESTING CHECKLIST

## 🎯 OVERVIEW

This guide provides a complete testing checklist for the n8n-native auth system. Run these tests to verify all authentication flows work correctly.

---

## 🚀 QUICK TEST SUMMARY

| Test | Endpoint | Expected Result |
|------|----------|-----------------|
| ✅ Login (valid) | POST /webhook/auth/login | `success: true` + session_token |
| ✅ Login (invalid) | POST /webhook/auth/login | `success: false` + error |
| ✅ Validate (active) | POST /webhook/auth/validate | `valid: true` + user data |
| ✅ Validate (expired) | POST /webhook/auth/validate | `valid: false` |
| ✅ Password reset | POST /webhook/auth/reset-password | `success: true` + email sent |

---

## 📋 TEST 1: LOGIN WITH VALID CREDENTIALS

### **cURL Command**

```bash
curl -X POST https://ai.thirdeyediagnostics.com/webhook/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "craig@theidudes.com",
    "password": "idudes2025"
  }'
```

### **Expected Response**

```json
{
  "success": true,
  "session_token": "abc123...xyz789",
  "user": {
    "id": "uuid-here",
    "email": "craig@theidudes.com",
    "name": "Craig Pretzinger",
    "role": "admin"
  }
}
```

### **What to Check**

- ✅ `success` is `true`
- ✅ `session_token` is a 64-character hex string
- ✅ `user` object contains correct email and name
- ✅ `role` matches database (`admin` for Craig)
- ✅ Response time < 500ms

---

## 📋 TEST 2: LOGIN WITH INVALID PASSWORD

### **cURL Command**

```bash
curl -X POST https://ai.thirdeyediagnostics.com/webhook/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "craig@theidudes.com",
    "password": "wrongpassword"
  }'
```

### **Expected Response**

```json
{
  "success": false,
  "error": "Invalid password"
}
```

### **What to Check**

- ✅ `success` is `false`
- ✅ `error` message is descriptive
- ✅ No `session_token` returned
- ✅ No `user` object returned
- ✅ Response time < 300ms

---

## 📋 TEST 3: LOGIN WITH NON-EXISTENT EMAIL

### **cURL Command**

```bash
curl -X POST https://ai.thirdeyediagnostics.com/webhook/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "nonexistent@example.com",
    "password": "anypassword"
  }'
```

### **Expected Response**

```json
{
  "success": false,
  "error": "User not found"
}
```

### **What to Check**

- ✅ `success` is `false`
- ✅ Error message doesn't reveal whether email exists (security)
- ✅ No session created
- ✅ Response time < 300ms

---

## 📋 TEST 4: VALIDATE ACTIVE SESSION

### **cURL Command**

```bash
# First login to get a valid token
TOKEN="abc123...xyz789"  # From Test 1

curl -X POST https://ai.thirdeyediagnostics.com/webhook/auth/validate \
  -H "Content-Type: application/json" \
  -d "{
    \"session_token\": \"$TOKEN\"
  }"
```

### **Expected Response**

```json
{
  "valid": true,
  "user": {
    "id": "uuid-here",
    "email": "craig@theidudes.com",
    "name": "Craig Pretzinger",
    "role": "admin"
  }
}
```

### **What to Check**

- ✅ `valid` is `true`
- ✅ `user` object is complete
- ✅ User data matches login response
- ✅ Response time < 200ms (should be fast!)

---

## 📋 TEST 5: VALIDATE INVALID TOKEN

### **cURL Command**

```bash
curl -X POST https://ai.thirdeyediagnostics.com/webhook/auth/validate \
  -H "Content-Type: application/json" \
  -d '{
    "session_token": "invalid-token-12345"
  }'
```

### **Expected Response**

```json
{
  "valid": false
}
```

### **What to Check**

- ✅ `valid` is `false`
- ✅ No `user` object returned
- ✅ No error (just invalid status)
- ✅ Response time < 100ms

---

## 📋 TEST 6: VALIDATE EXPIRED SESSION

### **Setup**

1. Manually update a session in database:
   ```sql
   UPDATE user_sessions 
   SET expires_at = NOW() - INTERVAL '1 day' 
   WHERE token = 'your-token-here';
   ```

2. Test with that token

### **Expected Response**

```json
{
  "valid": false
}
```

### **What to Check**

- ✅ Expired sessions return `valid: false`
- ✅ Session is not deleted (for audit purposes)
- ✅ User cannot use expired session

---

## 📋 TEST 7: PASSWORD RESET (EXISTING USER)

### **cURL Command**

```bash
curl -X POST https://ai.thirdeyediagnostics.com/webhook/auth/reset-password \
  -H "Content-Type: application/json" \
  -d '{
    "email": "craig@theidudes.com"
  }'
```

### **Expected Response**

```json
{
  "success": true,
  "message": "Reset email sent"
}
```

### **What to Check**

- ✅ `success` is `true`
- ✅ Email arrives in inbox (within 10 seconds)
- ✅ Email contains reset link
- ✅ Reset link format: `https://yourapp.vercel.app/reset-password?token=abc123`
- ✅ Email subject: "Password Reset Request"
- ✅ Email sender: Your Gmail or noreply@yourdomain.com

---

## 📋 TEST 8: PASSWORD RESET (NON-EXISTENT USER)

### **cURL Command**

```bash
curl -X POST https://ai.thirdeyediagnostics.com/webhook/auth/reset-password \
  -H "Content-Type: application/json" \
  -d '{
    "email": "nonexistent@example.com"
  }'
```

### **Expected Response**

```json
{
  "success": false,
  "error": "User not found"
}
```

### **What to Check**

- ✅ `success` is `false`
- ✅ No email sent (verify inbox)
- ✅ Error message is generic (security)
- ✅ Response time similar to valid email (prevent email enumeration)

---

## 📋 TEST 9: SESSION PERSISTENCE

### **Test Scenario**

1. Login (Test 1)
2. Get session token
3. Wait 5 minutes
4. Validate session (Test 4)
5. Verify session still valid

### **Expected Behavior**

- ✅ Session valid for 7 days
- ✅ Session survives server restarts
- ✅ Session stored in PostgreSQL (persistent)

---

## 📋 TEST 10: CONCURRENT SESSIONS

### **Test Scenario**

1. Login from Browser 1 (get token A)
2. Login from Browser 2 (get token B)
3. Validate token A
4. Validate token B
5. Both should work

### **Expected Behavior**

- ✅ Multiple sessions allowed per user
- ✅ Each session has unique token
- ✅ Both sessions valid until expiry
- ✅ Logout from one doesn't affect other

---

## 🔒 SECURITY TESTS

### **Test 11: SQL Injection**

```bash
curl -X POST https://ai.thirdeyediagnostics.com/webhook/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@example.com; DROP TABLE users;--",
    "password": "anything"
  }'
```

**Expected**: Safe failure, no database damage

---

### **Test 12: Password Brute Force**

```bash
# Try 10 rapid login attempts with wrong password
for i in {1..10}; do
  curl -X POST https://ai.thirdeyediagnostics.com/webhook/auth/login \
    -H "Content-Type: application/json" \
    -d '{
      "email": "craig@theidudes.com",
      "password": "wrong'$i'"
    }'
done
```

**Expected**: 
- All fail with `success: false`
- Consider adding rate limiting if needed

---

### **Test 13: Session Token Guessing**

```bash
# Try random tokens
curl -X POST https://ai.thirdeyediagnostics.com/webhook/auth/validate \
  -H "Content-Type: application/json" \
  -d '{
    "session_token": "0000000000000000000000000000000000000000000000000000000000000000"
  }'
```

**Expected**: `valid: false` (tokens are cryptographically random)

---

## 📊 PERFORMANCE BENCHMARKS

### **Test 14: Response Time Test**

```bash
# Time 10 login requests
for i in {1..10}; do
  time curl -X POST https://ai.theideyediagnostics.com/webhook/auth/login \
    -H "Content-Type: application/json" \
    -d '{"email":"craig@theidudes.com","password":"idudes2025"}'
done
```

**Expected Times**:
- Login: < 500ms
- Validate: < 200ms
- Reset: < 600ms

---

### **Test 15: Load Test (Optional)**

Use `ab` (ApacheBench) or `wrk`:

```bash
ab -n 100 -c 10 -p login.json -T application/json \
  https://ai.thirdeyediagnostics.com/webhook/auth/login
```

**Expected**: 
- No errors
- Average response time < 500ms
- 99th percentile < 1000ms

---

## 🐛 ERROR HANDLING TESTS

### **Test 16: Malformed JSON**

```bash
curl -X POST https://ai.thirdeyediagnostics.com/webhook/auth/login \
  -H "Content-Type: application/json" \
  -d '{invalid json'
```

**Expected**: Graceful error response (not 500)

---

### **Test 17: Missing Fields**

```bash
curl -X POST https://ai.thirdeyediagnostics.com/webhook/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "craig@theidudes.com"
  }'
```

**Expected**: `error: "Password required"` or similar

---

### **Test 18: Empty Fields**

```bash
curl -X POST https://ai.thirdeyediagnostics.com/webhook/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "",
    "password": ""
  }'
```

**Expected**: Validation error

---

## ✅ COMPLETE TESTING CHECKLIST

Run through all tests in order:

- [ ] Test 1: Login valid credentials
- [ ] Test 2: Login invalid password
- [ ] Test 3: Login non-existent email
- [ ] Test 4: Validate active session
- [ ] Test 5: Validate invalid token
- [ ] Test 6: Validate expired session
- [ ] Test 7: Password reset existing user
- [ ] Test 8: Password reset non-existent user
- [ ] Test 9: Session persistence (5 min wait)
- [ ] Test 10: Concurrent sessions
- [ ] Test 11: SQL injection protection
- [ ] Test 12: Brute force handling
- [ ] Test 13: Token guessing protection
- [ ] Test 14: Response time benchmark
- [ ] Test 15: Load test (optional)
- [ ] Test 16: Malformed JSON
- [ ] Test 17: Missing fields
- [ ] Test 18: Empty fields

---

## 🎯 ACCEPTANCE CRITERIA

Auth system is ready for production when:

- ✅ All 18 tests pass
- ✅ Login response time < 500ms
- ✅ Validate response time < 200ms
- ✅ Reset emails arrive within 10 seconds
- ✅ No SQL injection vulnerabilities
- ✅ Sessions persist across restarts
- ✅ Error messages are user-friendly
- ✅ n8n execution history shows no errors

---

## 🔍 DEBUGGING TIPS

### **Check n8n Execution History**

1. Go to `https://ai.thirdeyediagnostics.com`
2. Open auth workflow
3. Click **Executions** tab
4. View each execution:
   - Input data
   - Each node's output
   - Error details (if any)
   - Execution time

### **Check Database**

```sql
-- View all users
SELECT id, email, name, role, created_at FROM users;

-- View active sessions
SELECT token, user_id, expires_at, created_at 
FROM user_sessions 
WHERE expires_at > NOW();

-- View expired sessions
SELECT token, user_id, expires_at, created_at 
FROM user_sessions 
WHERE expires_at < NOW();
```

### **Common Issues**

**Issue**: Login succeeds but returns no token
- **Check**: n8n "Generate Token" node
- **Fix**: Verify crypto.randomBytes() works

**Issue**: Session validation always fails
- **Check**: Token format (should be 64-char hex)
- **Fix**: Verify database query uses exact token

**Issue**: Emails not sending
- **Check**: Gmail OAuth connection
- **Fix**: Re-authenticate in n8n credentials

---

## 📈 MONITORING

### **Key Metrics to Track**

| Metric | Target | Alert If |
|--------|--------|----------|
| Login success rate | > 95% | < 90% |
| Avg login time | < 300ms | > 500ms |
| Session validation time | < 100ms | > 200ms |
| Email delivery rate | > 99% | < 95% |
| Failed login attempts | < 5% | > 10% |

### **Monitoring Tools**

- **n8n Execution History**: Built-in monitoring
- **PostgreSQL Logs**: Database query performance
- **Gmail Quota**: Check daily send limit
- **Application Logs**: Client-side errors

---

## 🎯 PRODUCTION CHECKLIST

Before deploying to production:

- [ ] All 18 tests pass
- [ ] Load testing completed (100+ concurrent users)
- [ ] Gmail OAuth verified
- [ ] Database indexes created
- [ ] Session expiry set to 7 days
- [ ] Error messages reviewed (no sensitive data)
- [ ] n8n workflow activated
- [ ] Backup strategy in place
- [ ] Monitoring configured
- [ ] Documentation reviewed

---

*Last Updated: 2025-01-05*  
*Total Tests: 18*  
*Estimated Testing Time: 15 minutes*