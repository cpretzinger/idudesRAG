#!/bin/bash

# Test n8n API Key Authentication
# Replace YOUR_REAL_API_KEY with the key from n8n UI

echo "🔑 Testing n8n API Key Authentication..."

# Test 1: Get workflows
echo "Test 1: Get workflows"
curl -X GET \
  "https://ai.thirdeyediagnostics.com/api/v1/workflows" \
  -H "accept: application/json" \
  -H "X-N8N-API-KEY: YOUR_REAL_API_KEY"

echo -e "\n\nTest 2: Get active workflows"
curl -X GET \
  "https://ai.thirdeyediagnostics.com/api/v1/workflows?active=true" \
  -H "accept: application/json" \
  -H "X-N8N-API-KEY: YOUR_REAL_API_KEY"

echo -e "\n\n✅ If you see JSON data above, your API key works!"
echo "❌ If you see errors, check your API key generation."