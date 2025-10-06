const express = require('express');
const app = express();
app.use(express.json());

app.get('/', (req, res) => {
  res.json({ status: 'RAG Processor Running', tenant: 'Insurance Dudes' });
});

app.post('/upload', async (req, res) => {
  console.log('Document received:', req.body.filename);
  res.json({ success: true, message: 'Document queued for processing' });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`RAG Processor running on port ${PORT}`);
});
