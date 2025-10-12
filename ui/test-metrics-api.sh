#!/bin/bash

echo "Testing /api/metrics/track endpoint..."
echo ""

# Test the metrics tracking endpoint
curl -X POST http://localhost:3000/api/metrics/track \
  -H "Content-Type: application/json" \
  -d '{
    "metric_name": "chat_queries",
    "metric_value": 1,
    "tags": {
      "user_id": "test-api-call",
      "session_id": "test-session-123",
      "timestamp": "'$(date -Iseconds)'"
    }
  }' \
  | jq '.'

echo ""
echo "Check the database to verify the metric was recorded:"
echo "PGPASSWORD='d7ToQHAA7VecTKi2DxFgNxtlj~xN_HnD' psql -h yamabiko.proxy.rlwy.net -p 15649 -U postgres -d railway -c \"SELECT * FROM core.metrics WHERE metric_name = 'chat_queries' ORDER BY recorded_at DESC LIMIT 5;\""
