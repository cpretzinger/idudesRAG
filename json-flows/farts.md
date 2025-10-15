1. BuildBody Issue (only day 1 shows):
  - What node comes BEFORE buildBody? 
a These 2: {
  "nodes": [
    {
      "parameters": {
        "jsCode": "// Build robust enrichment queries without \"default\" leaks or empty strings\nconst cRaw = ($json.concept ?? '').trim();\nconst epRaw = ($json.episode_title ?? '').trim();\nconst catRaw = ($json.category ?? '').toLowerCase().trim();\n\n// Fallbacks that still read well if fields are missing\nconst topic = cRaw || epRaw || 'insurance agency growth';\nconst catWhitelist = ['sales_strategy','lead_gen','objection_handling','mindset','case_study'];\nconst category = catWhitelist.includes(catRaw) ? catRaw : (catRaw ? catRaw : 'mixed');\n\n// Helper to clamp strings safely\nconst clamp = (s, n) => String(s || '').slice(0, n);\n\n// Human-readable label for category intent inside strings\nconst catLabel = category === 'mixed'\n  ? 'agency growth'\n  : category.replace(/_/g, ' ');\n\n// Core themed banks\nconst BANK = {\n  sales_strategy: [\n    `proven sales techniques for ${clamp(topic, 60)}`,\n    `successful agent strategies in ${catLabel}`,\n    `step-by-step sales framework for ${clamp(topic, 60)}`,\n    `high-conversion discovery calls for ${clamp(topic, 60)}`,\n    `pipeline hygiene and follow-up cadences for ${clamp(topic, 60)}`\n  ],\n  lead_gen: [\n    `lead flow mechanics for ${clamp(topic, 60)}`,\n    `Internet Lead Secrets prospecting tactics`,\n    `Million Dollar Agency lead generation systems`,\n    `inbound vs outbound mix for ${clamp(topic, 60)}`,\n    `retention-driven referral loops for ${clamp(topic, 60)}`\n  ],\n  objection_handling: [\n    `overcoming objections in ${clamp(topic, 60)}`,\n    `objection handling scripts that convert`,\n    `client resistance and closing techniques`,\n    `price vs value reframes for ${clamp(topic, 60)}`,\n    `risk transfer explanations clients understand`\n  ],\n  mindset: [\n    `agent mindset for ${clamp(topic, 60)}`,\n    `mental toughness for insurance pros`,\n    `motivation and consistency systems`,\n    `Chaos vs Order narrative to frame risk`,\n    `habit stacks for daily production`\n  ],\n  case_study: [\n    `agent success stories related to ${clamp(topic, 60)}`,\n    `real results case studies (before/after)`,\n    `proven strategies and measurable outcomes`,\n    `field-tested playbooks for ${clamp(topic, 60)}`,\n    `risk mitigation narratives clients share`\n  ]\n};\n\n// If category is \"mixed\" or unknown, include **all themes**.\n// Otherwise: include all themes + a few extras biased to the chosen category.\nlet queries = [];\nif (category === 'mixed') {\n  queries = [\n    ...BANK.sales_strategy,\n    ...BANK.lead_gen,\n    ...BANK.objection_handling,\n    ...BANK.mindset,\n    ...BANK.case_study\n  ];\n} else {\n  const extra = [\n    `deep dive on ${catLabel} for ${clamp(topic, 60)}`,\n    `playbooks: ${catLabel} → ${clamp(topic, 60)}`,\n    `quick wins in ${catLabel} for busy agents`\n  ];\n  queries = [\n    ...BANK.sales_strategy,\n    ...BANK.lead_gen,\n    ...BANK.objection_handling,\n    ...BANK.mindset,\n    ...BANK.case_study,\n    ...extra\n  ];\n}\n\n// Clean up: dedupe, strip empties, trim, clamp length for embedding safety\nconst seen = new Set();\nconst enrichment_queries = queries\n  .map(q => (q || '').toString().trim())\n  .filter(q => q.length > 0)\n  .map(q => clamp(q, 200)) // keep each under ~200 chars for embeddings\n  .filter(q => {\n    const k = q.toLowerCase();\n    if (seen.has(k)) return false;\n    seen.add(k);\n    return true;\n  });\n\n// Absolute fallback to avoid empty array in edge cases\nif (enrichment_queries.length === 0) {\n  enrichment_queries.push(\n    `foundational strategies for ${clamp(topic, 60)}`\n  );\n}\n\nreturn {\n  ...$json,\n  enrichment_queries\n};\n"
      },
      "id": "2c38fef9-4fa4-42c0-917e-2002782e507c",
      "name": "Generate Enrichment Queries",
      "type": "n8n-nodes-base.code",
      "typeVersion": 2,
      "position": [
        -2176,
        416
      ]
    },
    {
      "parameters": {
        "jsCode": "// Persona (Marcus) + Brand memory consolidated\nconst persona = {\n  name: \"Marcus\",\n  archetype: \"Mid-Growth P&C Agency Owner\",\n  pain_points: [\n    \"burnout from endless follow-up calls\",\n    \"high producer turnover\",\n    \"carrier pressure and shrinking commissions\",\n    \"clunky AMS and inefficient processes\"\n  ],\n  goals: [\n    \"automate sales and service follow-up\",\n    \"build a self-sustaining team\",\n    \"reclaim time and freedom\"\n  ],\n  voice: \"straight-talking, practical, confident — mentor energy, not corporate fluff\",\n  mindset: \"growth-driven but exhausted by chaos\",\n  objections: [\n    \"my team won’t adopt new tools\",\n    \"automation makes us sound robotic\",\n    \"we tried this and it didn’t stick\"\n  ],\n  triggers: [\"time freedom\",\"chaos-to-control\",\"producers that stick\"],\n  cta_preferences: [\"Save/Share/Listen\", \"Join Agent Elite\", \"Comment your scenario\"]\n};\n\nconst brand = {\n  pillars: [\"clear\",\"confident\",\"practical\"],\n  tone_rules: [\n    \"teacher > hype\",\n    \"plain language\",\n    \"concrete outcomes only if present; else generalize\"\n  ],\n  telefunnel: [\"lead capture\",\"appointment setting\",\"follow-up automation\",\"nurture\",\"retention\"]\n};\n\nconst persona_tags = [\"mid_growth_owner\",\"burnout\",\"automation\",\"team\",\"retention\",\"time_freedom\",\"telefunnel\"];\nconst review_bias = { prefer_voice_authenticity_min: 8, persona: \"Marcus\" };\n\nreturn [{\n  json: {\n    ...$json,\n    persona, brand, persona_tags, review_bias\n  }\n}];\n"
      },
      "type": "n8n-nodes-base.code",
      "typeVersion": 2,
      "position": [
        -1968,
        416
      ],
      "id": "dcc929c6-bca3-4434-92db-87278d9d5188",
      "name": "InjectPersonaContext"
    }
  ],
  "connections": {
    "Generate Enrichment Queries": {
      "main": [
        [
          {
            "node": "InjectPersonaContext",
            "type": "main",
            "index": 0
          }
        ]
      ]
    },
    "InjectPersonaContext": {
      "main": [
        []
      ]
    }
  },
  "pinData": {},
  "meta": {
    "templateCredsSetupCompleted": true,
    "instanceId": "4bb33feb86ca4f5fc513a2380388fe9bf2c23463bf38edc4be554b00c909d710"
  }
}
  b. /mnt/volume_nyc1_01/idudesRAG/json-flows/10-social-content-automation.json

  - Does it show "1 item" or "371 items" in the output?
    Shows 1 becuase in Get Episode Chunks there were 371 but then combine episode content merges them all (i dont see the full 200 page book so unsure if it all ius there)
     
  2. BuildCacheKey Issue (empty user_prompt):
  - What's the field name that contains the actual prompt text? 
  SELECT role, content
FROM core.prompt_library
WHERE prompt_key = $1
  AND version    = COALESCE($2, 'v2');
{{ $json.user_prompt }}
{{ $json.system_prompt }}
  - Is it prompt, user_input, request, or something else?

  3. gen_prompt_version (v3 vs v2):
  - Where do you SET this value? see above 
  - What should trigger v2 vs v3? I DONT KNOW -- I THINK V2 IS the strinct ewhich is only for when rejected and or approve with edits

  4. Cache Hit (shows 0 instead of 1):
  - What node checks the cache? {
  "nodes": [
    {
      "parameters": {
        "conditions": {
          "options": {
            "caseSensitive": true,
            "leftValue": "",
            "typeValidation": "strict",
            "version": 2
          },
          "conditions": [
            {
              "id": "ffab43f8-61ad-45ff-99ec-b768829635a7",
              "leftValue": "={{ $json.response_data }}",
              "rightValue": "",
              "operator": {
                "type": "string",
                "operation": "notEmpty",
                "singleValue": true
              }
            },
            {
              "id": "98a652e8-ab03-4b17-be5c-c900d44c739b",
              "leftValue": "={{ $json.key_hash }}",
              "rightValue": "",
              "operator": {
                "type": "string",
                "operation": "notEmpty",
                "singleValue": true
              }
            }
          ],
          "combinator": "or"
        },
        "options": {}
      },
      "type": "n8n-nodes-base.if",
      "typeVersion": 2.2,
      "position": [
        976,
        288
      ],
      "id": "b7bb69c0-246f-4170-8211-a4bd5e11a5b2",
      "name": "Cache Hit?"
    }
  ],
  "connections": {
    "Cache Hit?": {
      "main": [
        [],
        []
      ]
    }
  },
  "pinData": {},
  "meta": {
    "templateCredsSetupCompleted": true,
    "instanceId": "4bb33feb86ca4f5fc513a2380388fe9bf2c23463bf38edc4be554b00c909d710"
  }
}
  - What node writes to cache?
{
  "nodes": [
    {
      "parameters": {
        "operation": "executeQuery",
        "query": "INSERT INTO core.api_cache (\n  key_hash,\n  cache_type,\n  model,\n  model_version,\n  request_payload,\n  response_data,\n  cost_usd,\n  hit_count\n) VALUES (\n  $1,\n  'generation',\n  $2,\n  $3,\n  $4::jsonb,\n  $5::jsonb,\n  $6,\n  0\n)\nON CONFLICT (key_hash)\nDO UPDATE SET\n  hit_count = core.api_cache.hit_count + 1,\n  response_data = EXCLUDED.response_data;",
        "options": {
          "queryReplacement": "={{ [ $('Build Gen Cache Key').first().json.gen_cache_key, $('Build Gen Cache Key').first().json.gen_model, $('Build Gen Cache Key').first().json.gen_prompt_version, JSON.stringify($('Combine Enrichment Data').first().json), JSON.stringify($json.generated_content),0.001 ] }}",
          "replaceEmptyStrings": false
        }
      },
      "type": "n8n-nodes-base.postgres",
      "typeVersion": 2.6,
      "position": [
        2416,
        144
      ],
      "id": "5cd4cf6d-22da-4a48-89d2-cd0ed09e70e3",
      "name": "Store Gen Cache",
      "credentials": {
        "postgres": {
          "id": "jd4YBgZXwugV4pZz",
          "name": "RailwayPG-idudes"
        }
      }
    }
  ],
  "connections": {
    "Store Gen Cache": {
      "main": [
        []
      ]
    }
  },
  "pinData": {},
  "meta": {
    "templateCredsSetupCompleted": true,
    "instanceId": "4bb33feb86ca4f5fc513a2380388fe9bf2c23463bf38edc4be554b00c909d710"
  }
}
  5. Parse Generated Content (returns null):
  - What does the LLM response look like? 

This was a cache hit but the cache was: [
  {
    "key_hash": "f86d5cfeefe72111e167e9cad072c96a2fe80b830bf908e842499369cb0a9fa0",
    "response_data": "### INSTAGRAM REEL\nBurnout is real. Chaos runs the shop until you automate the boring stuff. Build a clean playbook, cut the chaos, and reclaim your weekends. The Insurance Dudes help you map policy flows, automate reminders, and roll out SOPs that actually get followed. Ready to take control back? DM us and we’ll share a 5-step automation play that works in real shops. #InsuranceDudes #AgencyAutomation #P&C #Burnout\n\n### FACEBOOK POST\nYou’re in the trenches: staffing churn, shattered timelines, and a desk full of chaos. It doesn’t have to stay that way. The fix isn’t more hours, it’s fewer clicks. Map your end-to-end policy journey, build a living SOP library, and stack automation so the boring stuff does itself. Start with five core pipelines: new business intake, policy servicing, renewals, claims, and commissions. Get a single source of truth so every team member knows the drill. Track the real numbers, not vibes, and hold the system accountable. If you want a practical template that actually works in a real shop, The Insurance Dudes can tailor one to you. Comment “FIX” or DM us to get the playbook.\n\n### LINKEDIN POST\nAgency owners: burnout is real. Turnover is costly. Chaos is loud. The cure isn’t hustle; it’s systematization and automation. Here’s a practical framework you can actually implement:\n\n- Map end-to-end workflows for core cycles: new business, policy servicing, renewals, claims, commissions.\n- Build a living SOP library so every handoff is clear and repeatable.\n- Deploy a lightweight automation stack to handle repetitive tasks: data entry, reminders, document routing.\n- Create dashboards that show what matters: cycle time, renewal rate, customer touchpoints.\n- Consider a dedicated ops owner (even fractional) to drive accountability and continuous improvement.\n\nIf you want a plug-and-play template tailored to your shop, The Insurance Dudes can help you deploy it. DM us to get started.",
    "hit_count": 0,
    "created_at": "2025-10-15T06:03:04.733Z",
    "generated_content": "### INSTAGRAM REEL\nBurnout is real. Chaos runs the shop until you automate the boring stuff. Build a clean playbook, cut the chaos, and reclaim your weekends. The Insurance Dudes help you map policy flows, automate reminders, and roll out SOPs that actually get followed. Ready to take control back? DM us and we’ll share a 5-step automation play that works in real shops. #InsuranceDudes #AgencyAutomation #P&C #Burnout\n\n### FACEBOOK POST\nYou’re in the trenches: staffing churn, shattered timelines, and a desk full of chaos. It doesn’t have to stay that way. The fix isn’t more hours, it’s fewer clicks. Map your end-to-end policy journey, build a living SOP library, and stack automation so the boring stuff does itself. Start with five core pipelines: new business intake, policy servicing, renewals, claims, and commissions. Get a single source of truth so every team member knows the drill. Track the real numbers, not vibes, and hold the system accountable. If you want a practical template that actually works in a real shop, The Insurance Dudes can tailor one to you. Comment “FIX” or DM us to get the playbook.\n\n### LINKEDIN POST\nAgency owners: burnout is real. Turnover is costly. Chaos is loud. The cure isn’t hustle; it’s systematization and automation. Here’s a practical framework you can actually implement:\n\n- Map end-to-end workflows for core cycles: new business, policy servicing, renewals, claims, commissions.\n- Build a living SOP library so every handoff is clear and repeatable.\n- Deploy a lightweight automation stack to handle repetitive tasks: data entry, reminders, document routing.\n- Create dashboards that show what matters: cycle time, renewal rate, customer touchpoints.\n- Consider a dedicated ops owner (even fractional) to drive accountability and continuous improvement.\n\nIf you want a plug-and-play template tailored to your shop, The Insurance Dudes can help you deploy it. DM us to get started.",
    "from_cache": true,
    "cache_hit_count": 0
  }
]

  - What field has the actual generated post content?


"response_data":


  6. Book snippets:
  - Do your items have a source_type or file_type field?
I DONt kNOW CHECK thE JSON!!!

  - What value indicates "this is from a book, not an episode"?
HTFSIK?????