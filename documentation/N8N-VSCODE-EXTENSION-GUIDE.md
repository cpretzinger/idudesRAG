# 🔧 N8N VSCODE EXTENSION - HOW TO USE

## 📋 WHAT IS THIS?

This guide shows you how to **use the N8N VSCode extension** to work with your N8N workflows directly from VSCode. You can edit, test, and deploy workflows without leaving your editor.

**Why Use the N8N VSCode Extension?**
- ✅ **Edit workflows in VSCode** - No need to switch to browser
- ✅ **Version control** - Track workflow changes in Git
- ✅ **IntelliSense** - Code completion for N8N nodes
- ✅ **Live sync** - Auto-sync with your N8N instance
- ✅ **Local testing** - Test workflows before deploying

---

## ⚠️ IMPORTANT: What Gets Pulled

### **Pull Command Behavior**

When you run **"N8N: Pull Workflows"**, it downloads **ALL workflows** from your N8N instance at `https://ai.thirdeyediagnostics.com`.

**This means:**
- ✅ All workflows from this project
- ⚠️ **ALL workflows from OTHER projects too**
- ⚠️ **Shared team workflows**
- ⚠️ **Test/experimental workflows**

### **Is This a Problem?**

**Depends on your setup:**

**✅ NOT a problem if:**
- This is your only project on that N8N instance
- You want all workflows version-controlled together
- Your team shares one N8N instance

**⚠️ POTENTIAL PROBLEM if:**
- You have multiple unrelated projects on same N8N
- Some workflows contain sensitive logic for other projects
- You want to keep this repo focused on specific workflows

---

## 🛠️ SOLUTIONS FOR MULTI-PROJECT SETUPS

### **Option 1: Use .gitignore (Recommended)**

Only commit workflows relevant to THIS project:

**File:** `.gitignore`
```bash
# Pull all workflows locally but only commit specific ones
n8n-workflows/*

# Then explicitly track the ones you want
!n8n-workflows/PODCAST-INGESTION-WORKFLOW.json
!n8n-workflows/document-processing-workflow.json
# Add your project-specific workflows here
```

**Benefits:**
- ✅ Pull everything for easy editing
- ✅ Only commit relevant workflows to Git
- ✅ Other projects' workflows stay local-only

### **Option 2: Use Workflow Tags/Naming**

Prefix your project workflows consistently:

```
n8n-workflows/
├── idudesRAG-auth-login.json          ← Your project
├── idudesRAG-document-process.json    ← Your project
├── otherproject-payment.json          ← Other project (gitignored)
└── shared-email-sender.json           ← Shared (gitignored)
```

Then update `.gitignore`:
```bash
n8n-workflows/*
!n8n-workflows/idudesRAG-*.json
```

### **Option 3: Separate N8N Instances (Best for Production)**

If you have multiple projects, consider:
- Dev N8N instance: `https://dev-n8n.yourdomain.com`
- Prod N8N instance: `https://n8n.yourdomain.com`
- Per-project instances: `https://project1-n8n.yourdomain.com`

**Update config per project:**
```json
{
  "n8n.instanceUrl": "https://idudesrag-n8n.yourdomain.com"
}
```

### **Option 4: Manual Workflow Selection**

Instead of pulling ALL workflows:

1. **Don't use auto-sync:**
   ```json
   {
     "n8n.workflows": {
       "autoSync": false
     }
   }
   ```

2. **Manually copy specific workflows:**
   - Go to N8N UI
   - Export specific workflow as JSON
   - Save to `n8n-workflows/`
   - Commit to Git

**Benefits:**
- ✅ Full control over what's in repo
- ✅ No accidental pulls

**Drawbacks:**
- ❌ More manual work
- ❌ No auto-sync convenience

---

## ⚡ QUICK START

### **1. Extension Already Installed ✅**

You've already installed the N8N extension. Here's how to use it:

### **2. Get Your N8N API Key**

1. Go to: `https://ai.thirdeyediagnostics.com`
2. Click your **profile icon** (top right)
3. Click **Settings**
4. Go to **API** tab
5. Click **Create API Key**
6. **Copy the key** (shown only once!)

### **3. Configure Extension**

✅ **Already configured!** Your API key is set via environment variable.

The extension is configured to read from `.env`:

```json
{
  "n8n.instanceUrl": "https://ai.thirdeyediagnostics.com",
  "n8n.apiKey": "${env:N8N_API_KEY}",
  "n8n.workflows": {
    "directory": "n8n-workflows",
    "autoSync": true
  },
  "n8n.credentials": {
    "useWorkspace": true
  }
}
```

**Your `.env` file contains:**
```bash
N8N_API_KEY=your_actual_api_key_here
```

**Why use environment variables?**
- ✅ Keep secrets out of version control
- ✅ Easy to update without editing config
- ✅ Same pattern as other credentials

**Alternative:** Add directly to VSCode user settings (Command Palette → "Preferences: Open Settings (JSON)"):

```json
{
  "n8n.instanceUrl": "https://ai.thirdeyediagnostics.com",
  "n8n.apiKey": "YOUR_API_KEY_HERE"
}
```

---COMPLET TO HERE---- 

##HELP WITH:

## 🎯 MAIN FEATURES

### **Feature 1: Pull Workflows from N8N**

**Command Palette** → Type: `N8N: Pull Workflows`

This downloads all workflows from your N8N instance to `n8n-workflows/` directory.

**What You Get:**
```
n8n-workflows/
├── PODCAST-INGESTION-WORKFLOW.json
├── auth-login-workflow.json
├── auth-validate-workflow.json
└── document-processing-workflow.json
```

### **Feature 2: Edit Workflows in VSCode**

1. Open any `.json` file in `n8n-workflows/`
2. Edit the workflow JSON directly
3. VSCode will give you:
   - **JSON validation**
   - **Auto-completion**
   - **Syntax highlighting**
   - **Error detection**

### **Feature 3: Push Changes to N8N**

After editing a workflow:

**Command Palette** → Type: `N8N: Push Workflow`

This uploads your changes to the N8N instance.

### **Feature 4: Create New Workflows**

**Command Palette** → Type: `N8N: Create Workflow`

1. Enter workflow name
2. Extension creates a new `.json` file
3. Edit in VSCode
4. Push to N8N when ready

### **Feature 5: Test Workflows Locally**

**Command Palette** → Type: `N8N: Execute Workflow`

Tests the workflow using your N8N instance's execution engine.

---

## 🛠️ COMMON TASKS

### **Task 1: Sync All Workflows**

Keep your local files in sync with N8N:

```bash
# Pull latest from N8N
Command Palette → N8N: Pull Workflows

# Your local files are now updated
```

**When to use:**
- Starting your work session
- After someone else made changes in N8N UI
- Before making local edits

### **Task 2: Edit a Workflow**

1. **Pull workflows** (if not already synced)
2. Open `n8n-workflows/YOUR-WORKFLOW.json`
3. Make your changes:
   - Add/remove nodes
   - Change node settings
   - Update connections
4. Save the file
5. **Push to N8N**: Command Palette → `N8N: Push Workflow`

### **Task 3: Version Control Workflows**

Since workflows are now JSON files, you can:

```bash
# Stage changes
git add n8n-workflows/

# Commit
git commit -m "Updated auth workflow to add 2FA support"

# Push to GitHub
git push
```

**Benefits:**
- Track who changed what
- Revert to previous versions
- Code review workflow changes
- Collaborate with team

### **Task 4: Duplicate a Workflow**

```bash
# Copy existing workflow
cp n8n-workflows/auth-login.json n8n-workflows/auth-login-v2.json

# Edit the copy
# Change the workflow ID inside the JSON

# Push to N8N
Command Palette → N8N: Push Workflow
```

---

## 📝 WORKFLOW JSON STRUCTURE

Understanding the structure helps you edit effectively:

```json
{
  "name": "Document Processing",
  "nodes": [
    {
      "parameters": {
        "path": "documents",
        "responseMode": "onReceived",
        "options": {}
      },
      "id": "webhook-1",
      "name": "Webhook",
      "type": "n8n-nodes-base.webhook",
      "typeVersion": 1,
      "position": [250, 300]
    },
    {
      "parameters": {
        "operation": "executeQuery",
        "query": "INSERT INTO documents...",
        "options": {}
      },
      "id": "postgres-1",
      "name": "PostgreSQL",
      "type": "n8n-nodes-base.postgres",
      "typeVersion": 2,
      "position": [450, 300],
      "credentials": {
        "postgres": {
          "id": "1",
          "name": "Railway PGVector"
        }
      }
    }
  ],
  "connections": {
    "Webhook": {
      "main": [[{
        "node": "PostgreSQL",
        "type": "main",
        "index": 0
      }]]
    }
  }
}
```

**Key Sections:**
- `name`: Workflow name
- `nodes`: Array of all nodes
- `connections`: How nodes are connected
- `parameters`: Node-specific settings
- `credentials`: References to stored credentials

---

## 🔄 AUTO-SYNC FEATURE

With `autoSync: true` in your config, the extension will:

✅ **Auto-pull** when you open VSCode
✅ **Detect conflicts** if N8N version is newer
✅ **Show diff** before overwriting
✅ **Backup** your local version before pull

**To disable auto-sync:**
```json
{
  "n8n.workflows": {
    "directory": "n8n-workflows",
    "autoSync": false
  }
}
```

---

## 🔐 CREDENTIALS MANAGEMENT

**Important:** The extension does NOT download credentials (for security).

**What this means:**
- Workflows reference credentials by ID
- You can't see credential values in VSCode
- Credentials must be configured in N8N UI
- When pushing workflows, credential references are preserved

**Example in workflow JSON:**
```json
{
  "credentials": {
    "postgres": {
      "id": "5",
      "name": "Railway PGVector"
    }
  }
}
```

This references credential ID `5` which exists in your N8N instance.

---

## 🐛 TROUBLESHOOTING

### **Issue: "Could not connect to N8N instance"**

**Causes:**
1. Wrong instance URL
2. Invalid API key
3. N8N instance is down

**Fix:**
```bash
# Check N8N is running
curl https://ai.thirdeyediagnostics.com

# Verify API key in settings
# Command Palette → Preferences: Open Settings (JSON)

# Check URL format (no trailing slash)
"n8n.instanceUrl": "https://ai.thirdeyediagnostics.com"
```

---

### **Issue: "Workflow push failed"**

**Causes:**
1. Invalid JSON syntax
2. Missing required fields
3. Invalid node types

**Fix:**
```bash
# Validate JSON
Command Palette → JSON: Format Document

# Check for syntax errors in VSCode Problems panel
# Fix any red squiggly lines

# Try pulling latest version first
Command Palette → N8N: Pull Workflows
```

---

### **Issue: "Credentials not found"**

**Cause:** Workflow references a credential that doesn't exist in N8N

**Fix:**
1. Go to N8N UI: `https://ai.thirdeyediagnostics.com`
2. Settings → Credentials
3. Create the missing credential
4. Note the credential ID
5. Update workflow JSON with correct ID

---

### **Issue: "Auto-sync conflicts"**

**Scenario:** You edited locally, but someone changed it in N8N UI

**What happens:**
- Extension detects conflict
- Shows diff of changes
- Asks which version to keep

**Options:**
1. **Keep local** - Your changes overwrite N8N
2. **Keep remote** - N8N version overwrites local
3. **Merge manually** - You resolve conflicts

---

## 📊 KEYBOARD SHORTCUTS

**Common Actions:**

| Action | Shortcut |
|--------|----------|
| Pull workflows | `Cmd+Shift+P` → "N8N: Pull" |
| Push workflow | `Cmd+Shift+P` → "N8N: Push" |
| Execute workflow | `Cmd+Shift+P` → "N8N: Execute" |
| Format JSON | `Shift+Alt+F` |

**Tip:** You can customize these in VSCode keyboard shortcuts settings.

---

## 🎨 WORKFLOW DEVELOPMENT WORKFLOW

**Recommended Process:**

1. **Start Session:**
   ```
   Command Palette → N8N: Pull Workflows
   ```

2. **Make Changes:**
   - Edit JSON in VSCode
   - Save frequently (Cmd+S)
   - VSCode validates syntax

3. **Test:**
   ```
   Command Palette → N8N: Execute Workflow
   ```

4. **Deploy:**
   ```
   Command Palette → N8N: Push Workflow
   ```

5. **Version Control:**
   ```bash
   git add n8n-workflows/
   git commit -m "Added email validation to auth workflow"
   git push
   ```

6. **Verify in N8N UI:**
   - Go to `https://ai.thirdeyediagnostics.com`
   - Check workflow is updated
   - Test execution in N8N

---

## 💡 PRO TIPS

### **Tip 1: Use JSON Snippets**

Create snippets for common node patterns:

**File:** `.vscode/n8n-snippets.json`
```json
{
  "N8N Webhook Node": {
    "prefix": "n8n-webhook",
    "body": [
      "{",
      "  \"parameters\": {",
      "    \"path\": \"${1:endpoint}\",",
      "    \"responseMode\": \"onReceived\"",
      "  },",
      "  \"type\": \"n8n-nodes-base.webhook\",",
      "  \"name\": \"${2:Webhook}\"",
      "}"
    ]
  }
}
```

### **Tip 2: Search Across Workflows**

Use VSCode search to find specific nodes or patterns:

```
Cmd+Shift+F

Search: "n8n-nodes-base.postgres"
```

Finds all PostgreSQL nodes across all workflows.

### **Tip 3: Batch Edit Credentials**

Need to update credential ID across multiple workflows?

```bash
# Use find and replace
Cmd+Shift+H

Find: "\"id\": \"5\""
Replace: "\"id\": \"10\""

# In: n8n-workflows/*.json
```

### **Tip 4: Compare Workflow Versions**

```bash
# View changes
git diff n8n-workflows/auth-workflow.json

# Compare with specific commit
git diff HEAD~1 n8n-workflows/auth-workflow.json
```

---

## 📚 ADVANCED USAGE

### **Custom Node Development**

The extension supports custom nodes:

1. Create custom node in `nodes/` directory
2. Reference in workflow JSON
3. Test locally
4. Push to N8N with custom node installed

### **Environment-Specific Workflows**

Manage different workflows for dev/staging/prod:

```
n8n-workflows/
├── dev/
│   └── auth-workflow.json
├── staging/
│   └── auth-workflow.json
└── production/
    └── auth-workflow.json
```

**Switch environments:**
```json
{
  "n8n.workflows": {
    "directory": "n8n-workflows/dev"
  }
}
```

---

## 🎯 CURRENT PROJECT SETUP

**Your N8N Instance:**
- URL: `https://ai.thirdeyediagnostics.com`
- Workflows directory: `n8n-workflows/`
- Existing workflows: 
  - PODCAST-INGESTION-WORKFLOW.json
  - (Any auth workflows you create)

**To Start Using:**

1. **Get API key** from N8N settings
2. **Add to `.env`**: `N8N_API_KEY=your_key`
3. **Pull workflows**: Command Palette → `N8N: Pull Workflows`
4. **Setup .gitignore** (if you have multiple projects on same N8N)
5. **Start editing** in VSCode!

---

## ✅ SUCCESS CHECKLIST

- [ ] N8N VSCode extension installed
- [ ] API key obtained from N8N
- [ ] API key added to `.env` as `N8N_API_KEY`
- [ ] Config file created (`.vscode/n8n-extension.json`)
- [ ] Decided on .gitignore strategy (if multi-project)
- [ ] Workflows pulled successfully
- [ ] Can edit workflows in VSCode
- [ ] Can push changes to N8N
- [ ] Relevant workflows tracked in Git

---

## 🔗 RESOURCES

- **N8N Docs:** https://docs.n8n.io/
- **VSCode Extension:** Search "n8n" in VSCode extensions
- **Your N8N Instance:** https://ai.thirdeyediagnostics.com
- **Workflow Directory:** `n8n-workflows/`

---

## 🎉 SUMMARY

**What You Can Do Now:**

1. ✅ **Edit workflows in VSCode** - Better than browser editor
2. ✅ **Version control** - Track all workflow changes
3. ✅ **Collaborate** - Code review workflow changes
4. ✅ **Test locally** - Before deploying to production
5. ✅ **Batch operations** - Find/replace across workflows
6. ✅ **IDE benefits** - IntelliSense, validation, etc.
7. ✅ **Selective commits** - Use .gitignore for multi-project setups

**You're ready to develop N8N workflows in VSCode! 🚀**

---

*Last Updated: 2025-10-06*  
*Setup Time: 5 minutes*  
*Difficulty: Easy*
