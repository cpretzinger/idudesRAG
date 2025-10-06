# 🎯 n8n WORKFLOW SETUP - ADHD FRIENDLY GUIDE

## 📋 **OVERVIEW**
Create 6 nodes in this exact order. Copy/paste each code block exactly.

---

## 🔥 **STEP 1: CREATE NEW WORKFLOW**
1. Go to: https://ai.thirdeyediagnostics.com
2. Click **"+ Add workflow"**
3. Name it: **"idudesRAG Document Processing"**

---

## 📤 **NODE 1: WEBHOOK (Upload)**

### **Add Node:**
- Click **"+"** → Search **"Webhook"** → Add

### **Settings:**
- **Webhook URL:** `idudesRAG/documents`
- **HTTP Method:** `POST`
- **Response:** `On Received`

### **Test URL will be:**
`https://ai.thirdeyediagnostics.com/webhook/test/idudesRAG/documents`

---

## 💻 **NODE 2: CODE (Process Upload)**

### **Add Node:**
- Click **"+"** → Search **"Code"** → Add

### **Settings:**
- **Mode:** `Run Once for All Items`

### **JavaScript Code:**
```javascript
// Extract and prepare document data
const input = $input.first().json;

// Decode base64 content
let content = '';
if (input.content) {
  try {
    content = Buffer.from(input.content, 'base64').toString('utf8');
  } catch (error) {
    content = input.content; // fallback if not base64
  }
}

// Create document object
const document = {
  filename: input.filename || 'unknown',
  content: content,
  file_size: input.size || 0,
  file_type: input.type || 'unknown',
  metadata: {
    source: 'idudesRAG-upload',
    timestamp: input.timestamp || new Date().toISOString(),
    original_name: input.filename
  }
};

return [{ json: document }];
```

---

## 🗄️ **NODE 3: POSTGRES (Store Document)**

### **Add Node:**
- Click **"+"** → Search **"Postgres"** → Add

### **Settings:**
- **Operation:** `Insert`
- **Schema:** `public`
- **Table:** `documents`

### **Credentials:**
1. Click **"Create New Credential"**
2. **Name:** `iDudes PGVector Railway`
3. **Host:** `yamabiko.proxy.rlwy.net`
4. **Port:** `15649`
5. **Database:** `railway`
6. **User:** `postgres`
7. **Password:** `d7ToQHAA7VecTKi2DxFgNxtlj~xN_HnD`
8. **SSL:** `Disable`

### **Column Mapping:**
- **filename:** `={{ $json.filename }}`
- **content:** `={{ $json.content }}`
- **file_size:** `={{ $json.file_size }}`
- **file_type:** `={{ $json.file_type }}`
- **metadata:** `={{ JSON.stringify($json.metadata) }}`

### **Additional Settings:**
- **Return Fields:** `id`

---

## ✂️ **NODE 4: CODE (Chunk Text)**

### **Add Node:**
- Click **"+"** → Search **"Code"** → Add

### **Settings:**
- **Mode:** `Run Once for All Items`

### **JavaScript Code:**
```javascript
// Chunk text for embeddings
const input = $input.first().json;
const content = input.content || '';
const documentId = input.id;

const chunkSize = 1000;
const overlap = 200;
const chunks = [];

// Split into chunks
for (let i = 0; i < content.length; i += (chunkSize - overlap)) {
  const chunk = content.slice(i, i + chunkSize);
  if (chunk.trim().length > 0) {
    chunks.push({
      document_id: documentId,
      chunk_text: chunk.trim(),
      chunk_index: chunks.length,
      metadata: {
        filename: input.filename,
        chunk_size: chunk.length,
        total_length: content.length
      }
    });
  }
}

return chunks.map(chunk => ({ json: chunk }));
```

---

## 🤖 **NODE 5: OPENAI EMBEDDINGS**

### **Add Node:**
- Click **"+"** → Search **"OpenAI"** → Find **"Embeddings OpenAI"**

### **Credentials:**
1. Click **"Create New Credential"**
2. **Name:** `OpenAI API`
3. **API Key:** `<your-openai-api-key-from-.env-file>`

### **Settings:**
- **Model:** `text-embedding-3-small`
- **Text:** `={{ $json.chunk_text }}`
- **Dimensions:** `1536`

---

## 🗄️ **NODE 6: POSTGRES (Store Embeddings)**

### **Add Node:**
- Click **"+"** → Search **"Postgres"** → Add

### **Settings:**
- **Operation:** `Insert`
- **Schema:** `public`
- **Table:** `document_embeddings`

### **Credentials:**
- **Use existing:** `iDudes PGVector Railway`

### **Column Mapping:**
- **document_id:** `={{ $json.document_id }}`
- **chunk_text:** `={{ $json.chunk_text }}`
- **embedding:** `={{ JSON.stringify($('Embeddings OpenAI').item.json.data) }}`
- **chunk_index:** `={{ $json.chunk_index }}`
- **chunk_metadata:** `={{ JSON.stringify($json.metadata) }}`

---

## 🔗 **STEP 7: CONNECT NODES**

### **Wire them in order:**
1. **Webhook** → **Process Upload**
2. **Process Upload** → **Store Document**
3. **Store Document** → **Chunk Text**
4. **Chunk Text** → **Embeddings OpenAI**
5. **Embeddings OpenAI** → **Store Embeddings**

---

## ✅ **STEP 8: ACTIVATE & TEST**

### **Activate:**
1. Click **"Active"** toggle (top right)
2. **Save** the workflow

### **Get Production URL:**
- **Production URL:** `https://ai.thirdeyediagnostics.com/webhook/idudesRAG/documents`

### **Test with Vercel UI:**
1. Go to: https://ui-hqv6d6k5n-pretzingers-projects.vercel.app
2. Upload a text file
3. Check if it processes

---

## 🔍 **TROUBLESHOOTING**

### **If Upload Fails:**
1. Check webhook is **Active**
2. Verify PostgreSQL credentials
3. Check OpenAI API key
4. Look at **Executions** tab for errors

### **Common Issues:**
- **"Table doesn't exist"** → Check schema name (`public` vs other)
- **"Column doesn't exist"** → Check exact column names in database
- **"Embedding error"** → Verify OpenAI API key and credits

---

## 🎉 **SUCCESS!**
When working, you'll see:
- Documents in `documents` table
- Chunks with vectors in `document_embeddings` table
- Successful executions in n8n

**Total setup time: ~10 minutes** ⏱️