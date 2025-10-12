#!/bin/bash

# Test Insurance Podcast Content Extraction Queries

echo "🎙️ Testing Insurance Podcast Content Extraction"
echo "=============================================="
echo ""

# Array of semantic search queries for insurance content
queries=(
  "best tips for selling insurance to small businesses"
  "how to overcome client objections in insurance sales"
  "insurance sales closing techniques"
  "building trust with insurance clients"
  "insurance lead generation strategies"
  "overcoming fear of rejection in insurance sales"
  "time management for insurance agents"
  "insurance cross-selling strategies"
  "how to handle price objections"
  "insurance referral generation tactics"
  "building a successful insurance agency"
  "insurance sales automation tools"
  "effective insurance cold calling scripts"
  "insurance client retention strategies"
  "how to explain complex insurance policies simply"
)

# Run each query
for query in "${queries[@]}"; do
  echo "📊 Query: \"$query\""
  echo "---"
  node test-semantic-search.js "$query" 2>/dev/null | grep -A 20 "Found.*results:" | head -15
  echo ""
  echo ""
done

echo "✅ All queries tested!"
