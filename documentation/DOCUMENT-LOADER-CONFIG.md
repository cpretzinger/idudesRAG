# 📄 DOCUMENT LOADER NODE - COMPLETE CONFIG

## 🎯 **ADD DOCUMENT LOADER NODE**
- Click **"+"** → Search **"Document Loader"** → Select **"Default Data Loader"**

---

## ⚙️ **DOCUMENT LOADER SETTINGS**

### **Mode:**
- Select: **"Load Specific Data"**

### **Data:**
```
{{ $json.content }}
```

### **Text Splitting:**
- Select: **"Custom"**

---

## 🏷️ **METADATA CONFIGURATION**

### **Click "Add Metadata" for each:**

#### **Metadata Item 1:**
- **Name:** `filename`
- **Value:** `{{ $json.filename }}`

#### **Metadata Item 2:**
- **Name:** `source`
- **Value:** `{{ $json.metadata.source }}`

#### **Metadata Item 3:**
- **Name:** `file_type`
- **Value:** `{{ $json.file_type }}`

#### **Metadata Item 4:**
- **Name:** `file_size`
- **Value:** `{{ $json.file_size }}`

#### **Metadata Item 5:**
- **Name:** `upload_timestamp`
- **Value:** `{{ $json.metadata.timestamp }}`

#### **Metadata Item 6:**
- **Name:** `document_id`
- **Value:** `{{ $json.id }}`

#### **Metadata Item 7:**
- **Name:** `chunk_index`
- **Value:** `{{ $itemIndex }}`

#### **Metadata Item 8:**
- **Name:** `processing_date`
- **Value:** `{{ new Date().toISOString() }}`

---

## 🔧 **OPERATION MODE (Next Section)**

### **Operation Mode:**
- Select: **"Insert Documents"**

### **Table Name:**
```
document_embeddings
```

### **Embedding Batch Size:**
```
200
```

---

## 🔗 **CONNECTION ORDER**

Connect this node between:
1. **Previous Node:** Code (Process Upload)
2. **Next Node:** Embeddings OpenAI

---

## ✅ **VERIFICATION**

After setup, your Document Loader should:
- ✅ Load document content from `{{ $json.content }}`
- ✅ Add 8 metadata fields
- ✅ Split text for processing
- ✅ Pass to embeddings node

---

## 🎯 **FINAL NODE FLOW**

```
Webhook → Code (Process) → Document Loader → Embeddings → PostgreSQL
```

This replaces the chunking code - the Document Loader handles text splitting automatically!