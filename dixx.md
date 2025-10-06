FULL WORKFLOW -- EMBEDINGS WORKFING FOR "SISTER DB"

REPLACE ALL CONDIFS WITH .env configs for the repo we are IN 

DO NOT USE ACTAL SETTINGS IN EZAMPLE JSON BELOW:

{
  "nodes": [
    {
      "parameters": {
        "httpMethod": "POST",
        "path": "memory-search",
        "options": {}
      },
      "id": "d3d5fab7-9f0f-42db-8c9e-a244641af365",
      "name": "Webhook - Memory Search",
      "type": "n8n-nodes-base.webhook",
      "typeVersion": 2,
      "position": [
        -1104,
        144
      ],
      "webhookId": "memory-search-v2"
    },
    {
      "parameters": {
        "jsCode": "// Validate and parse search request\nconst input = $input.first().json;\n\n// Default values\nconst defaults = {\n  query: '',\n  limit: 10,\n  filters: {\n    timeframe: '24h',\n    source: null,\n    channel: null,\n    kind: null,\n    minImportance: 0\n  },\n  searchType: 'hybrid' // 'keyword', 'semantic', or 'hybrid'\n};\n\n// Merge with defaults\nconst searchParams = {\n  query: input.query || defaults.query,\n  limit: Math.min(input.limit || defaults.limit, 100),\n  filters: { ...defaults.filters, ...(input.filters || {}) },\n  searchType: input.searchType || defaults.searchType\n};\n\n// Calculate time window\nlet timeWindow;\nswitch(searchParams.filters.timeframe) {\n  case '1h': timeWindow = '1 hour'; break;\n  case '24h': timeWindow = '24 hours'; break;\n  case '7d': timeWindow = '7 days'; break;\n  case '30d': timeWindow = '30 days'; break;\n  default: timeWindow = '24 hours';\n}\n\nreturn {\n  query: searchParams.query,\n  limit: searchParams.limit,\n  timeWindow: timeWindow,\n  filters: searchParams.filters,\n  searchType: searchParams.searchType\n};"
      },
      "id": "1252f2ed-4a93-4b5c-9d6e-23dd14a2787b",
      "name": "Validate Input",
      "type": "n8n-nodes-base.code",
      "typeVersion": 2,
      "position": [
        -880,
        144
      ]
    },
    {
      "parameters": {
        "rules": {
          "values": [
            {
              "conditions": {
                "options": {
                  "caseSensitive": true,
                  "leftValue": "",
                  "typeValidation": "strict"
                },
                "conditions": [
                  {
                    "leftValue": "={{ $json.searchType }}",
                    "rightValue": "keyword",
                    "operator": {
                      "type": "string",
                      "operation": "equals"
                    }
                  }
                ],
                "combinator": "and"
              },
              "renameOutput": true,
              "outputKey": "keyword"
            },
            {
              "conditions": {
                "options": {
                  "caseSensitive": true,
                  "leftValue": "",
                  "typeValidation": "strict"
                },
                "conditions": [
                  {
                    "leftValue": "={{ $json.searchType }}",
                    "rightValue": "semantic",
                    "operator": {
                      "type": "string",
                      "operation": "equals"
                    }
                  }
                ],
                "combinator": "and"
              },
              "renameOutput": true,
              "outputKey": "semantic"
            },
            {
              "conditions": {
                "options": {
                  "caseSensitive": true,
                  "leftValue": "",
                  "typeValidation": "strict"
                },
                "conditions": [
                  {
                    "leftValue": "={{ $json.searchType }}",
                    "rightValue": "hybrid",
                    "operator": {
                      "type": "string",
                      "operation": "equals"
                    }
                  }
                ],
                "combinator": "and"
              },
              "renameOutput": true,
              "outputKey": "hybrid"
            }
          ]
        },
        "options": {}
      },
      "id": "47506168-46dd-4d45-a701-cefbcc1e69db",
      "name": "Search Type Router",
      "type": "n8n-nodes-base.switch",
      "typeVersion": 3,
      "position": [
        -208,
        64
      ]
    },
    {
      "parameters": {
        "operation": "executeQuery",
        "query": "-- Keyword search using trigram similarity\nSELECT \n  m.id,\n  m.text,\n  m.source,\n  m.channel,\n  m.kind,\n  m.topic,\n  m.importance,\n  m.created_at,\n  m.metadata,\n  similarity(m.text, '{{ $json.query }}') as text_similarity\nFROM core.memories m\nWHERE m.created_at > NOW() - INTERVAL '{{ $json.timeWindow }}'\n  AND m.text % '{{ $json.query }}' -- Trigram similarity operator\n  {{ $json.filters.source ? \"AND m.source = '\" + $json.filters.source + \"'\" : \"\" }}\n  {{ $json.filters.channel ? \"AND m.channel = '\" + $json.filters.channel + \"'\" : \"\" }}\n  {{ $json.filters.kind ? \"AND m.kind = '\" + $json.filters.kind + \"'\" : \"\" }}\n  AND m.importance >= {{ $json.filters.minImportance }}\nORDER BY text_similarity DESC, m.created_at DESC\nLIMIT {{ $json.limit }};",
        "options": {}
      },
      "id": "6028005e-de4d-49dd-8747-9eb194a05290",
      "name": "Keyword Search",
      "type": "n8n-nodes-base.postgres",
      "typeVersion": 2.5,
      "position": [
        0,
        -112
      ],
      "credentials": {
        "postgres": {
          "id": "B9PQ9q9Ncxmk9lYg",
          "name": "ai-asst"
        }
      }
    },
    {
      "parameters": {
        "operation": "executeQuery",
        "query": "-- Semantic vector search\nWITH query_embedding AS (\n  -- Get embedding for most similar existing memory\n  SELECT embedding\n  FROM core.memory_embeddings e\n  JOIN core.memories m ON e.memory_id = m.id\n  WHERE m.text ILIKE '%' || '{{ $json.query }}' || '%'\n  ORDER BY m.created_at DESC\n  LIMIT 1\n)\nSELECT \n  m.id,\n  m.text,\n  m.source,\n  m.channel,\n  m.kind,\n  m.topic,\n  m.importance,\n  m.created_at,\n  m.metadata,\n  1 - (e.embedding <=> q.embedding) as semantic_similarity\nFROM core.memory_embeddings e\nJOIN core.memories m ON e.memory_id = m.id\nCROSS JOIN query_embedding q\nWHERE m.created_at > NOW() - INTERVAL '{{ $json.timeWindow }}'\n  {{ $json.filters.source ? \"AND m.source = '\" + $json.filters.source + \"'\" : \"\" }}\n  {{ $json.filters.channel ? \"AND m.channel = '\" + $json.filters.channel + \"'\" : \"\" }}\n  {{ $json.filters.kind ? \"AND m.kind = '\" + $json.filters.kind + \"'\" : \"\" }}\n  AND m.importance >= {{ $json.filters.minImportance }}\nORDER BY e.embedding <=> q.embedding\nLIMIT {{ $json.limit }};",
        "options": {}
      },
      "id": "14bc83e6-7dec-47b5-80ad-32d47bcccc6f",
      "name": "Semantic Search",
      "type": "n8n-nodes-base.postgres",
      "typeVersion": 2.5,
      "position": [
        0,
        64
      ],
      "credentials": {
        "postgres": {
          "id": "B9PQ9q9Ncxmk9lYg",
          "name": "ai-asst"
        }
      }
    },
    {
      "parameters": {
        "operation": "executeQuery",
        "query": "-- Hybrid search combining keyword and semantic\nWITH keyword_results AS (\n  SELECT \n    m.id,\n    m.text,\n    m.source,\n    m.channel,\n    m.kind,\n    m.topic,\n    m.importance,\n    m.created_at,\n    m.metadata,\n    similarity(m.text, '{{ $json.query }}') as text_similarity,\n    0 as semantic_similarity\n  FROM core.memories m\n  WHERE m.created_at > NOW() - INTERVAL '{{ $json.timeWindow }}'\n    AND m.text % '{{ $json.query }}'\n    {{ $json.filters.source ? \"AND m.source = '\" + $json.filters.source + \"'\" : \"\" }}\n    {{ $json.filters.channel ? \"AND m.channel = '\" + $json.filters.channel + \"'\" : \"\" }}\n    {{ $json.filters.kind ? \"AND m.kind = '\" + $json.filters.kind + \"'\" : \"\" }}\n    AND m.importance >= {{ $json.filters.minImportance }}\n  ORDER BY text_similarity DESC\n  LIMIT {{ $json.limit }}\n),\nquery_embedding AS (\n  SELECT embedding\n  FROM core.memory_embeddings e\n  JOIN core.memories m ON e.memory_id = m.id\n  WHERE m.text ILIKE '%' || '{{ $json.query }}' || '%'\n  ORDER BY m.created_at DESC\n  LIMIT 1\n),\nsemantic_results AS (\n  SELECT \n    m.id,\n    m.text,\n    m.source,\n    m.channel,\n    m.kind,\n    m.topic,\n    m.importance,\n    m.created_at,\n    m.metadata,\n    0 as text_similarity,\n    1 - (e.embedding <=> q.embedding) as semantic_similarity\n  FROM core.memory_embeddings e\n  JOIN core.memories m ON e.memory_id = m.id\n  CROSS JOIN query_embedding q\n  WHERE m.created_at > NOW() - INTERVAL '{{ $json.timeWindow }}'\n    {{ $json.filters.source ? \"AND m.source = '\" + $json.filters.source + \"'\" : \"\" }}\n    {{ $json.filters.channel ? \"AND m.channel = '\" + $json.filters.channel + \"'\" : \"\" }}\n    {{ $json.filters.kind ? \"AND m.kind = '\" + $json.filters.kind + \"'\" : \"\" }}\n    AND m.importance >= {{ $json.filters.minImportance }}\n  ORDER BY e.embedding <=> q.embedding\n  LIMIT {{ $json.limit }}\n),\ncombined_results AS (\n  SELECT \n    id,\n    MAX(text) as text,\n    MAX(source) as source,\n    MAX(channel) as channel,\n    MAX(kind) as kind,\n    MAX(topic) as topic,\n    MAX(importance) as importance,\n    MAX(created_at) as created_at,\n    MAX(metadata::text)::jsonb as metadata,\n    MAX(text_similarity) as text_similarity,\n    MAX(semantic_similarity) as semantic_similarity,\n    -- Combined score: 60% semantic, 40% keyword\n    (0.6 * MAX(semantic_similarity) + 0.4 * MAX(text_similarity)) as combined_score\n  FROM (\n    SELECT * FROM keyword_results\n    UNION ALL\n    SELECT * FROM semantic_results\n  ) all_results\n  GROUP BY id\n)\nSELECT \n  id,\n  text,\n  source,\n  channel,\n  kind,\n  topic,\n  importance,\n  created_at,\n  metadata,\n  ROUND(text_similarity::numeric, 4) as keyword_score,\n  ROUND(semantic_similarity::numeric, 4) as semantic_score,\n  ROUND(combined_score::numeric, 4) as final_score\nFROM combined_results\nORDER BY combined_score DESC\nLIMIT {{ $json.limit }};",
        "options": {}
      },
      "id": "0eb251b6-ae54-4583-9b52-8e2d7233d12f",
      "name": "Hybrid Search",
      "type": "n8n-nodes-base.postgres",
      "typeVersion": 2.5,
      "position": [
        0,
        224
      ],
      "credentials": {
        "postgres": {
          "id": "B9PQ9q9Ncxmk9lYg",
          "name": "ai-asst"
        }
      }
    },
    {
      "parameters": {
        "mode": "combine",
        "combineBy": "combineByPosition",
        "numberInputs": 3,
        "options": {
          "includeUnpaired": true
        }
      },
      "id": "7ff9441e-441f-4684-ba12-16e94586f99f",
      "name": "Merge Results",
      "type": "n8n-nodes-base.merge",
      "typeVersion": 3,
      "position": [
        208,
        64
      ]
    },
    {
      "parameters": {
        "jsCode": "// Format the response\nconst items = $input.all();\nconst results = items.map(item => item.json);\n\n// Add search metadata\nconst response = {\n  success: true,\n  query: $node[\"validate_input\"].json.query,\n  searchType: $node[\"validate_input\"].json.searchType,\n  resultCount: results.length,\n  results: results,\n  metadata: {\n    timeWindow: $node[\"validate_input\"].json.timeWindow,\n    filters: $node[\"validate_input\"].json.filters,\n    timestamp: new Date().toISOString()\n  }\n};\n\nreturn response;"
      },
      "id": "76003b89-c380-4bfa-9a78-f703d09b0724",
      "name": "Format Response",
      "type": "n8n-nodes-base.code",
      "typeVersion": 2,
      "position": [
        400,
        64
      ]
    },
    {
      "parameters": {
        "options": {}
      },
      "id": "7c34ff4c-a2e8-41d8-a3b0-36c5d350fb64",
      "name": "Respond to Webhook",
      "type": "n8n-nodes-base.respondToWebhook",
      "typeVersion": 1.1,
      "position": [
        656,
        64
      ]
    },
    {
      "parameters": {
        "options": {
          "dimensions": 1536,
          "batchSize": 512
        }
      },
      "type": "@n8n/n8n-nodes-langchain.embeddingsOpenAi",
      "typeVersion": 1.2,
      "position": [
        -672,
        448
      ],
      "id": "6e32f7af-ec7c-4561-86ed-650c791760ae",
      "name": "Embeddings OpenAI",
      "credentials": {
        "openAiApi": {
          "id": "SKlesqKDEYktKT37",
          "name": "OpenAi account"
        }
      }
    },
    {
      "parameters": {
        "mode": "load",
        "tableName": "core.memory_embeddings",
        "prompt": "={{ $json.query }}",
        "topK": 20,
        "options": {
          "distanceStrategy": "cosine",
          "metadata": {
            "metadataValues": [
              {
                "name": "Embedding",
                "value": "embedding"
              },
              {
                "name": "Content",
                "value": "memory_id"
              },
              {
                "name": "Metadata",
                "value": "metadata"
              }
            ]
          }
        }
      },
      "type": "@n8n/n8n-nodes-langchain.vectorStorePGVector",
      "typeVersion": 1.3,
      "position": [
        -608,
        128
      ],
      "id": "5116cd39-3cfb-47a9-bae5-35f4b1655e8a",
      "name": "Semantic Search1",
      "credentials": {
        "postgres": {
          "id": "B9PQ9q9Ncxmk9lYg",
          "name": "ai-asst"
        }
      }
    },
    {
      "parameters": {
        "jsCode": "// FINAL VERSION - CLOSE DB CONNECTIONS NODE FOR n8n\n// Copy this entire code into a Code node (JavaScript) at the end of your workflow\n// This version works without external modules\n\n// 1. Clean up any global connection objects\nconst globalCleanup = () => {\n  const targets = ['pgPool', 'pgClient', 'dbConn', 'redisClient'];\n  let cleaned = 0;\n\n  targets.forEach(name => {\n    if (global[name]) {\n      try {\n        delete global[name];\n        cleaned++;\n      } catch (e) {\n        // Silent fail\n      }\n    }\n  });\n\n  return cleaned;\n};\n\n// 2. Generate cleanup report\nconst generateReport = (cleaned) => {\n  return {\n    workflow: $workflow.name || 'Unknown',\n    workflowId: $workflow.id,\n    execution: $execution.id,\n    timestamp: new Date().toISOString(),\n    connectionsCleared: cleaned,\n    status: 'success'\n  };\n};\n\n// 3. Execute cleanup\nconst cleaned = globalCleanup();\nconst report = generateReport(cleaned);\n\n// 4. Log the results\nconsole.log('🧹 Cleanup Complete:', JSON.stringify(report, null, 2));\n\n// 5. Pass through the data with cleanup metadata\nreturn $input.all().map(item => ({\n  ...item,\n  json: {\n    ...item.json,\n    _cleanup: report\n  }\n}));"
      },
      "type": "n8n-nodes-base.code",
      "typeVersion": 2,
      "position": [
        1440,
        -176
      ],
      "id": "092261b1-6423-4798-b7a7-a03a7e1f4415",
      "name": "CLOSECONNECTION"
    },
    {
      "parameters": {
        "method": "POST",
        "url": "https://ai.thirdeyediagnostics.com/webhook/search",
        "sendBody": true,
        "specifyBody": "json",
        "jsonBody": "={{ $json }}",
        "options": {}
      },
      "id": "8293c36f-8a03-4f75-a5ce-10412881b1b3",
      "name": "Send to MemoryWriteGate2",
      "type": "n8n-nodes-base.httpRequest",
      "typeVersion": 4.2,
      "position": [
        1152,
        160
      ]
    }
  ],
  "connections": {
    "Webhook - Memory Search": {
      "main": [
        [
          {
            "node": "Validate Input",
            "type": "main",
            "index": 0
          }
        ]
      ]
    },
    "Validate Input": {
      "main": [
        [
          {
            "node": "Semantic Search1",
            "type": "main",
            "index": 0
          }
        ]
      ]
    },
    "Search Type Router": {
      "main": [
        [
          {
            "node": "Keyword Search",
            "type": "main",
            "index": 0
          }
        ],
        [
          {
            "node": "Semantic Search",
            "type": "main",
            "index": 0
          }
        ],
        [
          {
            "node": "Hybrid Search",
            "type": "main",
            "index": 0
          }
        ]
      ]
    },
    "Keyword Search": {
      "main": [
        [
          {
            "node": "Merge Results",
            "type": "main",
            "index": 1
          }
        ]
      ]
    },
    "Semantic Search": {
      "main": [
        [
          {
            "node": "Merge Results",
            "type": "main",
            "index": 0
          }
        ]
      ]
    },
    "Hybrid Search": {
      "main": [
        [
          {
            "node": "Merge Results",
            "type": "main",
            "index": 2
          }
        ]
      ]
    },
    "Merge Results": {
      "main": [
        [
          {
            "node": "Format Response",
            "type": "main",
            "index": 0
          }
        ]
      ]
    },
    "Format Response": {
      "main": [
        [
          {
            "node": "Respond to Webhook",
            "type": "main",
            "index": 0
          }
        ]
      ]
    },
    "Respond to Webhook": {
      "main": [
        [
          {
            "node": "Send to MemoryWriteGate2",
            "type": "main",
            "index": 0
          }
        ]
      ]
    },
    "Embeddings OpenAI": {
      "ai_embedding": [
        [
          {
            "node": "Semantic Search1",
            "type": "ai_embedding",
            "index": 0
          }
        ]
      ]
    },
    "Semantic Search1": {
      "main": [
        [
          {
            "node": "Search Type Router",
            "type": "main",
            "index": 0
          }
        ]
      ]
    },
    "Send to MemoryWriteGate2": {
      "main": [
        [
          {
            "node": "CLOSECONNECTION",
            "type": "main",
            "index": 0
          }
        ]
      ]
    }
  },
  "pinData": {},
  "meta": {
    "templateCredsSetupCompleted": true,
    "instanceId": "4bb33feb86ca4f5fc513a2380388fe9bf2c23463bf38edc4be554b00c909d710"
  }
}


------