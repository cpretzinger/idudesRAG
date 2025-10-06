# 📧 GMAIL OAUTH SETUP FOR N8N AUTH

## 🎯 OVERVIEW

This guide shows you how to configure Gmail OAuth2 in n8n for sending password reset emails. The entire process takes **2 minutes** and requires no coding.

---

## ✅ PREREQUISITES

- ✅ n8n instance running at `https://ai.thirdeyediagnostics.com`
- ✅ Gmail account (any Gmail account works)
- ✅ Access to Google Cloud Console (free)

---

## 🚀 STEP-BY-STEP SETUP

### **Step 1: Open n8n Credentials (30 seconds)**

1. Go to `https://ai.thirdeyediagnostics.com`
2. Click **Settings** (gear icon in bottom-left)
3. Click **Credentials** tab
4. Click **+ Add Credential**
5. Search for **"Gmail OAuth2"**
6. Click **Gmail OAuth2 API**

---

### **Step 2: Google Cloud Setup (1 minute)**

n8n will show you instructions. You need to:

1. **Go to Google Cloud Console**: [console.cloud.google.com](https://console.cloud.google.com)
2. **Create new project** (or use existing):
   - Click **Select a project** → **New Project**
   - Name: `idudesRAG-Auth`
   - Click **Create**

3. **Enable Gmail API**:
   - Search for "Gmail API" in top search bar
   - Click **Enable**

4. **Create OAuth2 Credentials**:
   - Go to **APIs & Services** → **Credentials**
   - Click **+ Create Credentials** → **OAuth client ID**
   - If prompted, configure consent screen:
     - User Type: **External**
     - App name: `idudesRAG Auth`
     - User support email: Your Gmail
     - Developer contact: Your Gmail
     - Click **Save and Continue** (skip scopes, test users)
   
5. **Configure OAuth Client**:
   - Application type: **Web application**
   - Name: `n8n idudesRAG`
   - Authorized redirect URIs: `https://ai.thirdeyediagnostics.com/rest/oauth2-credential/callback`
   - Click **Create**
   - **Copy Client ID and Client Secret** (shown once!)

---

### **Step 3: Configure n8n Credential (30 seconds)**

Back in n8n:

1. **Paste credentials**:
   - **Client ID**: Paste from Google Cloud
   - **Client Secret**: Paste from Google Cloud

2. **Connect Account**:
   - Click **Connect my account**
   - Google login popup appears
   - Select your Gmail account
   - Click **Allow** (authorize permissions)

3. **Save Credential**:
   - Name: `Gmail OAuth - idudesRAG`
   - Click **Save**

---

## ✅ VERIFICATION

### **Test Email Sending**

1. In n8n, create a test workflow:
   - **Webhook** node (for triggering)
   - **Gmail** node

2. Configure Gmail node:
   - **Credential**: Select `Gmail OAuth - idudesRAG`
   - **Resource**: `Message`
   - **Operation**: `Send`
   - **To**: Your email
   - **Subject**: `Test from n8n`
   - **Body**: `If you receive this, Gmail OAuth is working!`

3. **Execute workflow**:
   - Click **Execute Workflow**
   - Check your inbox (should arrive instantly)

---

## 🎨 EMAIL TEMPLATE FOR PASSWORD RESET

Once Gmail is configured, the n8n auth workflow will use this template:

```
To: {{ $json.email }}
Subject: Password Reset Request

Hi {{ $json.name }},

You requested a password reset for your idudesRAG account.

Click this link to reset your password:
{{ $json.reset_url }}

This link expires in 1 hour.

If you didn't request this, ignore this email.

- idudesRAG Team
```

---

## 🐛 TROUBLESHOOTING

### **Issue: "Access blocked" error**

**Cause**: OAuth consent screen not configured

**Fix**:
1. Go to Google Cloud Console
2. **APIs & Services** → **OAuth consent screen**
3. Add your email to **Test users**
4. Publish app (if ready for production)

---

### **Issue: "Redirect URI mismatch"**

**Cause**: Wrong redirect URI in Google Cloud

**Fix**:
1. Verify n8n URL: `https://ai.thirdeyediagnostics.com`
2. Redirect URI must be: `https://ai.thirdeyediagnostics.com/rest/oauth2-credential/callback`
3. Update in Google Cloud Console
4. Reconnect in n8n

---

### **Issue: Emails go to spam**

**Solutions**:
1. **Use your domain**: Configure SPF/DKIM for better deliverability
2. **Add to contacts**: Have users add `noreply@yourdomain.com` to contacts
3. **Use SendGrid**: For production, consider dedicated email service

---

## 📊 GMAIL API LIMITS

| Tier | Daily Limit | Notes |
|------|-------------|-------|
| **Free** | 100 emails/day | Perfect for password resets |
| **Workspace** | 2000 emails/day | Business accounts |
| **API Quota** | 1 billion/day | More than enough |

**For idudesRAG**: Free tier is sufficient (password resets are infrequent)

---

## 🔒 SECURITY BEST PRACTICES

1. **OAuth2 Only**: Never store Gmail password
2. **Rotate Secrets**: Update Client Secret periodically
3. **Limit Scopes**: Only grant `gmail.send` permission
4. **Monitor Usage**: Check Google Cloud Console for anomalies
5. **Revoke Access**: Can revoke from Google Account settings anytime

---

## 🔄 ALTERNATIVE EMAIL SERVICES

If you prefer alternatives to Gmail:

### **Option 1: SendGrid** (Recommended for production)
- Free tier: 100 emails/day
- Better deliverability
- n8n has SendGrid node
- Setup: Similar OAuth process

### **Option 2: SMTP** (Any provider)
- Use n8n SMTP node
- Works with Gmail, Mailgun, AWS SES, etc.
- No OAuth needed (just username/password)

### **Option 3: Mailgun**
- Free tier: 1000 emails/month
- Great for transactional emails
- n8n has Mailgun node

---

## 📝 NEXT STEPS

After Gmail OAuth is configured:

1. ✅ Import n8n auth workflow (`json-flows/n8n-auth-workflow.json`)
2. ✅ Test password reset flow
3. ✅ Verify reset email arrives
4. ✅ Check email formatting
5. ✅ Update email template (optional)

---

## 🎯 SUMMARY

**What you did:**
- Created Google Cloud project
- Enabled Gmail API
- Created OAuth2 credentials
- Connected Gmail to n8n
- Verified email sending works

**Result:**
- n8n can send emails via your Gmail
- Password reset emails work automatically
- Zero code required
- 2-minute setup time

---

*Last Updated: 2025-01-05*  
*Setup Time: 2 minutes*  
*Difficulty: Easy*