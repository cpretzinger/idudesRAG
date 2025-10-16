{
  "nodes": [
    {
      "parameters": {
        "jsCode": "\n  // Parse Generated Content (Clean + Fixed)\n  const readFromInputs = () => {\n    const all = $input.all();\n    for (const it of all) {\n      const j = it.json || {};\n      let candidate = j.output || j.text || j.generated_content || j.response_data;\n\n      if (typeof candidate === 'string' && candidate.trim()) {\n        return candidate.trim();\n      }\n    }\n    return '';\n  };\n\n  const content = readFromInputs();\n\n  if (!content) {\n    throw new Error('No generated content found in inputs');\n  }\n\n  // Extract sections\n  const ig = (content.match(/###\\s*INSTAGRAM REEL\\s*\\n([\\s\\S]*?)(?=###|$)/i) || [])[1] || '';\n  const fb = (content.match(/###\\s*FACEBOOK POST\\s*\\n([\\s\\S]*?)(?=###|$)/i) || [])[1] || '';\n  const li = (content.match(/###\\s*LINKEDIN POST\\s*\\n([\\s\\S]*?)(?=###|$)/i) || [])[1] || '';\n\n  return [{\n    json: {\n      ...$json,\n      instagram_content: ig.trim(),\n      facebook_content: fb.trim(),\n      linkedin_content: li.trim(),\n      generated_content: content\n    }\n  }];"
      },
      "id": "f1c95729-a11c-45e6-8a9f-739062bf6ea8",
      "name": "Parse Generated Content",
      "type": "n8n-nodes-base.code",
      "typeVersion": 2,
      "position": [
        2896,
        592
      ]
    },
    {
      "parameters": {
        "model": "gpt-5-nano",
        "options": {
          "reasoningEffort": "low"
        }
      },
      "id": "22011bb4-a049-45ce-a7e7-a6ace1d51861",
      "name": "Expert Review (GPT-5-Nano)",
      "type": "@n8n/n8n-nodes-langchain.lmChatOpenAi",
      "typeVersion": 1,
      "position": [
        3504,
        912
      ],
      "credentials": {
        "openAiApi": {
          "id": "EQYdxPEgshiwvESa",
          "name": "ZARAapiKey"
        }
      }
    },
    {
      "parameters": {
        "promptType": "define",
        "text": "={{ $json.user_prompt }}\n\n{{ $json.instagram_content }}\n\n{{ $json.facebook_content }}\n\n{{ $json.linkedin_content }}",
        "options": {
          "systemMessage": "={{ $json.system_prompt }}"
        }
      },
      "type": "@n8n/n8n-nodes-langchain.agent",
      "typeVersion": 2.2,
      "position": [
        3504,
        736
      ],
      "id": "6766f2c0-0439-4a18-93d2-9d87a3661222",
      "name": "Expert Review"
    },
    {
      "parameters": {
        "operation": "executeQuery",
        "query": "SELECT role, content\nFROM core.prompt_library\nWHERE prompt_key = $1\n  AND version    = COALESCE($2, 'v3')\nORDER BY role;\n",
        "options": {
          "queryReplacement": "={{ [$json.prompt_key, $json.prompt_version] }}"
        }
      },
      "type": "n8n-nodes-base.postgres",
      "typeVersion": 2.6,
      "position": [
        3024,
        736
      ],
      "id": "f078cbc2-8584-4ed5-a03c-b656134d6910",
      "name": "SelectReviewerPrompt",
      "credentials": {
        "postgres": {
          "id": "jd4YBgZXwugV4pZz",
          "name": "RailwayPG-idudes"
        }
      }
    },
    {
      "parameters": {
        "jsCode": "// setPromptVersion — v3 default; v2 only when NOT approved\nconst force = String($json.force_version || '').toLowerCase();\nlet v = null;\n\nif (force === 'v2' || force === 'v3') {\n  v = force;\n} else {\n  const status = String($json.review_status || '').toUpperCase();\n  const needsStrict = (status === 'REJECT' || status === 'APPROVE_WITH_EDITS' || status === 'CHANGES_REQUESTED');\n  v = needsStrict ? 'v2' : 'v3'; // first-time (no status) falls here → 'v3'\n}\n\nreturn [{ json: { ...$json, prompt_key: 'expert_review', prompt_version: v } }];\n"
      },
      "type": "n8n-nodes-base.code",
      "typeVersion": 2,
      "position": [
        2896,
        736
      ],
      "id": "a99a60d0-d3d5-4e49-8810-8a1e213fd1cf",
      "name": "setPromptVersionLLMS"
    },
    {
      "parameters": {
        "jsCode": "// Get prompts from SelectReviewerPrompt\nconst prompts = $items('SelectReviewerPrompt', 0, 0).map(i => i.json);\n\n// Get ALL upstream data from setPromptVersionLLMS (which has Parse Generated Content data)\nconst upstream = $('setPromptVersionLLMS').first().json || {};\n\nreturn [{\n  json: {\n    prompt_key: $json.prompt_key || upstream.prompt_key,\n    version: $json.prompt_version || upstream.prompt_version,\n    persona: upstream.persona || {},\n    brand: upstream.brand || {},\n    enriched: upstream.enriched || {},\n    payload: {\n      instagram: upstream.instagram_content || '',\n      facebook: upstream.facebook_content || '',\n      linkedin: upstream.linkedin_content || ''\n    },\n    // CRITICAL: Preserve ALL enriched fields for DB insert\n    episode_title: upstream.episode_title,\n    day_number: upstream.day_number,\n    day_theme: upstream.day_theme,\n    topic_title: upstream.topic_title,\n    topic_category: upstream.topic_category,\n    file_id: upstream.file_id,\n    work_id: upstream.work_id,\n    instagram_content: upstream.instagram_content,\n    facebook_content: upstream.facebook_content,\n    linkedin_content: upstream.linkedin_content,\n    prompts\n  }\n}];"
      },
      "type": "n8n-nodes-base.code",
      "typeVersion": 2,
      "position": [
        3168,
        736
      ],
      "id": "b2480da3-5613-4949-a94a-31ede9d04320",
      "name": "packInputs4"
    },
    {
      "parameters": {
        "workflowId": {
          "__rl": true,
          "value": "MEey0mO1avbFaAIJ",
          "mode": "list",
          "cachedResultUrl": "/workflow/MEey0mO1avbFaAIJ",
          "cachedResultName": "Prompt Mapper"
        },
        "workflowInputs": {
          "mappingMode": "defineBelow",
          "value": {},
          "matchingColumns": [],
          "schema": [],
          "attemptToConvertTypes": false,
          "convertFieldsToString": true
        },
        "options": {
          "waitForSubWorkflow": true
        }
      },
      "type": "n8n-nodes-base.executeWorkflow",
      "typeVersion": 1.3,
      "position": [
        3312,
        736
      ],
      "id": "c67bd1bd-1353-44a0-9584-a02b2bdcb70d",
      "name": "Call 'PromptMapper'1"
    },
    {
      "parameters": {
        "mode": "combine",
        "combineBy": "combineByPosition",
        "options": {
          "includeUnpaired": true
        }
      },
      "type": "n8n-nodes-base.merge",
      "typeVersion": 3.2,
      "position": [
        3360,
        896
      ],
      "id": "cf396584-aa73-4196-9529-f53bbfeee66e",
      "name": "Merge3"
    }
  ],
  "connections": {
    "Parse Generated Content": {
      "main": [
        [
          {
            "node": "setPromptVersionLLMS",
            "type": "main",
            "index": 0
          }
        ]
      ]
    },
    "Expert Review (GPT-5-Nano)": {
      "ai_languageModel": [
        [
          {
            "node": "Expert Review",
            "type": "ai_languageModel",
            "index": 0
          }
        ]
      ]
    },
    "Expert Review": {
      "main": [
        []
      ]
    },
    "SelectReviewerPrompt": {
      "main": [
        [
          {
            "node": "packInputs4",
            "type": "main",
            "index": 0
          }
        ]
      ]
    },
    "setPromptVersionLLMS": {
      "main": [
        [
          {
            "node": "SelectReviewerPrompt",
            "type": "main",
            "index": 0
          }
        ]
      ]
    },
    "packInputs4": {
      "main": [
        [
          {
            "node": "Call 'PromptMapper'1",
            "type": "main",
            "index": 0
          },
          {
            "node": "Merge3",
            "type": "main",
            "index": 0
          }
        ]
      ]
    },
    "Call 'PromptMapper'1": {
      "main": [
        [
          {
            "node": "Merge3",
            "type": "main",
            "index": 1
          }
        ]
      ]
    },
    "Merge3": {
      "main": [
        [
          {
            "node": "Expert Review",
            "type": "main",
            "index": 0
          }
        ]
      ]
    }
  },
  "pinData": {},
  "meta": {
    "instanceId": "4bb33feb86ca4f5fc513a2380388fe9bf2c23463bf38edc4be554b00c909d710"
  }
}