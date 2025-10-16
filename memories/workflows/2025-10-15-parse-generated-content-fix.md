# Parse Generated Content - Cache Response Fix

## Problem
When cache hits, Parse Generated Content gets empty strings for instagram/facebook/linkedin content because `response_data` from PostgreSQL is JSON-encoded (wrapped in quotes).

## Database Structure
```sql
-- response_data is stored as TEXT with JSON string value:
response_data = "\"### INSTAGRAM REEL\\nContent here...\""
```

## Fix for Parse Generated Content

Add JSON unwrapping at the start of the `readFromInputs()` function:

```javascript
const readFromInputs = () => {
  const all = $input.all();
  for (const it of all) {
    const j = it.json || {};

    // Try each field in priority order
    let candidate = j.response_data || j.generated_content || j.strict_output || j.output || j.text || j.content;

    // If it's a string, check if it's JSON-wrapped
    if (typeof candidate === 'string') {
      candidate = candidate.trim();
      if (candidate) {
        // Try to unwrap if it's JSON-encoded
        try {
          const parsed = JSON.parse(candidate);
          if (typeof parsed === 'string') {
            return parsed; // It was JSON-wrapped, return unwrapped
          }
        } catch {
          // Not JSON, just return as-is
        }
        return candidate;
      }
    }
  }
  return '';
};
```

This handles:
- Fresh generation: `response_data` = direct string ✅
- Cache hit: `response_data` = `"\"### INSTAGRAM..."` → unwraps to `"### INSTAGRAM..."` ✅
