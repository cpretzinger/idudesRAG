# HOW BRAND VOICE VARIABLES ARE INJECTED INTO PROMPTS

**Current Status**: October 16, 2025
**Workflow**: 10-social-content-automation.json
**Purpose**: Document exactly how brand voice variables flow through the workflow

---

## 📊 DATABASE SCHEMA (Source of Truth)

### Table: `core.social_content_generated`

```sql
CREATE TABLE core.social_content_generated (
  -- ... other fields ...
  persona_segment TEXT,              -- Marcus archetype: 'mid_growth_owner'
  emotion_tone TEXT,                 -- Content tone: 'empathetic', 'motivational', etc.
  day_theme VARCHAR(100) NOT NULL,   -- Daily focus: 'automation', 'retention', etc.
  topic_category VARCHAR(50),        -- Maps to TeleFunnel: 'lead_gen', 'team_building', etc.
  -- ... other fields ...
);
```

**Current Reality**:
- These fields exist in the schema ✓
- They are updated via SQL UPDATE nodes ✓
- BUT they are **NOT currently used in prompt generation** ❌

---

## 🔄 CURRENT WORKFLOW DATA FLOW

### Step 1: InjectPersonaContext Node (Line 1288)

**Location**: Early in workflow (position -1984, 144)
**Type**: Code node (JavaScript)

**What It Does**:
```javascript
// Hardcoded persona and brand objects (NOT from database)
const persona = {
  name: "Marcus",
  archetype: "Mid-Growth P&C Agency Owner",
  pain_points: [
    "burnout from endless follow-up calls",
    "high producer turnover",
    "carrier pressure and shrinking commissions",
    "clunky AMS and inefficient processes"
  ],
  goals: [
    "automate sales and service follow-up",
    "build a self-sustaining team",
    "reclaim time and freedom"
  ],
  voice: "straight-talking, practical, confident — mentor energy, not corporate fluff",
  mindset: "growth-driven but exhausted by chaos",
  objections: [
    "my team won't adopt new tools",
    "automation makes us sound robotic",
    "we tried this and it didn't stick"
  ],
  triggers: ["time freedom","chaos-to-control","producers that stick"],
  cta_preferences: ["Save/Share/Listen", "Join Agent Elite", "Comment your scenario"]
};

const brand = {
  pillars: ["clear","confident","practical"],
  tone_rules: [
    "teacher > hype",
    "plain language",
    "concrete outcomes only if present; else generalize"
  ],
  telefunnel: ["lead capture","appointment setting","follow-up automation","nurture","retention"]
};

const persona_tags = ["mid_growth_owner","burnout","automation","team","retention","time_freedom","telefunnel"];
const review_bias = { prefer_voice_authenticity_min: 8, persona: "Marcus" };

return [{
  json: {
    ...$json,
    persona,        // Adds persona object to data flow
    brand,          // Adds brand object to data flow
    persona_tags,   // Adds tags array to data flow
    review_bias     // Adds review preferences to data flow
  }
}];
```

**Key Point**: This is **hardcoded JavaScript**, not database-driven.

---

### Step 2: Prompts Reference Persona in Templates

#### A) Generator System Prompt (v2)

**Database Source**: `core.prompt_library` WHERE `prompt_key = 'generator'` AND `version = 'v2'` AND `role = 'system'`

**Excerpt**:
```
You are a formatting-strict social copy generator for The Insurance Dudes.

Audience: P&C agency owners like "Marcus" — ambitious, stressed, craving automation and control.
Tone: speak like a fellow agency owner who's been in the trenches — clear, confident, slightly rebellious.
Never sound corporate. Use everyday, punchy phrasing.
Relate to their pain (burnout, turnover, chaos) before teaching the fix.
```

**Variable Injection**: **NONE** - Text is static, references "Marcus" by name but doesn't inject persona object.

---

#### B) Generator User Prompt (v2)

**Database Source**: `core.prompt_library` WHERE `prompt_key = 'generator'` AND `version = 'v2'` AND `role = 'user'`

**Template Structure**:
```
You are a world-class social copy generator for The Insurance Dudes.

AUDIENCE PERSONA
Name: Marcus
Archetype: Mid-Growth P&C Agency Owner
Pain Points: <PLACEHOLDER - appears empty in DB>
Goals: <PLACEHOLDER - appears empty in DB>
Voice: straight-talking, practical, confident
Mindset: growth-driven but exhausted by chaos

CONTEXT
DAY: <PLACEHOLDER>
Category: <PLACEHOLDER>
EPISODE: <PLACEHOLDER>
TOPIC/TAGS: <PLACEHOLDER>
Score: <PLACEHOLDER>/10

PRIMARY SOURCE (truncated):
<PLACEHOLDER>

ENRICHMENT:
<PLACEHOLDER>

BRAND/TONE RULES
- TeleFunnel mapping where natural (lead → call → booked → bind → retention).
- Acknowledge Marcus's pain (burnout, turnover, chaos) before the fix.
...
```

**Variable Injection Method**: **String replacement in MapperFunctionGen node** (NOT documented in current workflow, but presumably exists)

---

### Step 3: MapperFunctionGen (Not Shown in Excerpts)

**Expected Pattern** (based on MapperFunctionReviewer pattern):
```javascript
const rows = $input.all().map(it => it.json);
const sys = rows.find(r => r.role === 'system')?.content || '';
const usr = rows.find(r => r.role === 'user')?.content || '';

// Get persona and brand from InjectPersonaContext node
const enriched = $('InjectPersonaContext').first().json;

// Replace placeholders with actual values
const userPromptFilled = usr
  .replace('Pain Points: <PLACEHOLDER>', `Pain Points: ${JSON.stringify(enriched.persona.pain_points)}`)
  .replace('Goals: <PLACEHOLDER>', `Goals: ${JSON.stringify(enriched.persona.goals)}`)
  .replace('DAY: <PLACEHOLDER>', `DAY: ${enriched.day_number}`)
  .replace('EPISODE: <PLACEHOLDER>', `EPISODE: ${enriched.episode_title}`)
  // ... more replacements ...

return [{
  json: {
    ...enriched,
    system_prompt: sys,
    user_prompt: userPromptFilled
  }
}];
```

**Key Point**: Persona/brand values are **hardcoded in InjectPersonaContext**, then **injected into prompt templates** via string replacement.

---

### Step 4: Database UPDATE (Line 1387)

**Node Name**: (Not visible in excerpt, but appears in grep results)
**Type**: PostgreSQL node
**Operation**: UPDATE query

```sql
UPDATE core.social_content_generated
SET persona_segment = COALESCE($2, persona_segment),
    emotion_tone    = COALESCE($3, emotion_tone),
    updated_at      = now()
WHERE work_id = $1;
```

**Parameter Values**:
```javascript
[
  $json.work_id,
  'mid_growth_owner',      // HARDCODED
  'burnout_to_control'     // HARDCODED
]
```

**Key Point**: These values are **written TO the database** but **NOT read FROM the database** for prompt generation.

---

## 🔍 THE DISCONNECT

### What SHOULD Happen (Database-Driven Design)

```
1. Query persona_segment, emotion_tone, day_theme, topic_category FROM database
   ↓
2. Use those values to customize prompt templates dynamically
   ↓
3. LLM generates content tailored to those variables
   ↓
4. Store generated content back to database
```

### What ACTUALLY Happens (Hardcoded Design)

```
1. InjectPersonaContext creates hardcoded persona/brand objects in JavaScript
   ↓
2. MapperFunctionGen injects those hardcoded values into prompt templates
   ↓
3. LLM generates content (always with same persona/brand values)
   ↓
4. Hardcoded persona_segment/emotion_tone values written to database (unused)
```

---

## 📍 WHERE VARIABLES ARE ACTUALLY USED

### Currently Active Variable Injection Points

#### 1. **InjectPersonaContext Node** (Line 1288)
- **Type**: Code node (JavaScript)
- **Purpose**: Creates `persona`, `brand`, `persona_tags`, `review_bias` objects
- **Source**: Hardcoded in JavaScript
- **Data Flow**: Adds objects to `$json` for downstream nodes

#### 2. **MapperFunctionGen** (Presumed to exist, not shown in excerpts)
- **Type**: Code node (JavaScript)
- **Purpose**: Fills prompt template placeholders with persona/brand values
- **Source**: References `InjectPersonaContext` output
- **Data Flow**: Creates `system_prompt` and `user_prompt` strings for LLM call

#### 3. **Database UPDATE** (Line 1387)
- **Type**: PostgreSQL node
- **Purpose**: Stores persona_segment/emotion_tone to database
- **Source**: Hardcoded values in query parameters
- **Data Flow**: One-way write to database (values NOT used in this workflow)

---

## 🎯 COMPARISON: CURRENT vs. IDEAL DESIGN

### Current Design (Hardcoded)

**Pros**:
- Simple, predictable
- No database queries needed for persona data
- Persona logic centralized in one JavaScript node

**Cons**:
- Cannot dynamically adjust persona/tone per piece of content
- Database fields (persona_segment, emotion_tone, day_theme, topic_category) are unused
- Changes to persona require editing JavaScript code
- No A/B testing of different persona variants

### Ideal Design (Database-Driven)

**Pros**:
- Dynamic persona/tone selection per content piece
- Database becomes single source of truth
- Easy to A/B test different personas/tones
- Can analyze which persona_segment/emotion_tone combinations perform best

**Cons**:
- More complex (requires database query before prompt generation)
- Additional node(s) to query persona data
- Need to manage persona definitions in database table

---

## 🛠️ HOW TO MAKE IT DATABASE-DRIVEN (Future Enhancement)

### Step 1: Create Persona Library Table

```sql
CREATE TABLE core.persona_library (
  persona_key TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  archetype TEXT,
  pain_points JSONB,
  goals JSONB,
  voice TEXT,
  mindset TEXT,
  objections JSONB,
  triggers JSONB,
  cta_preferences JSONB,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Insert Marcus as default persona
INSERT INTO core.persona_library (persona_key, name, archetype, pain_points, goals, voice, mindset, objections, triggers, cta_preferences)
VALUES (
  'marcus_mid_growth',
  'Marcus',
  'Mid-Growth P&C Agency Owner',
  '["burnout from endless follow-up calls", "high producer turnover", "carrier pressure and shrinking commissions", "clunky AMS and inefficient processes"]'::jsonb,
  '["automate sales and service follow-up", "build a self-sustaining team", "reclaim time and freedom"]'::jsonb,
  'straight-talking, practical, confident — mentor energy, not corporate fluff',
  'growth-driven but exhausted by chaos',
  '["my team won''t adopt new tools", "automation makes us sound robotic", "we tried this and it didn''t stick"]'::jsonb,
  '["time freedom", "chaos-to-control", "producers that stick"]'::jsonb,
  '["Save/Share/Listen", "Join Agent Elite", "Comment your scenario"]'::jsonb
);
```

### Step 2: Create Tone Library Table

```sql
CREATE TABLE core.tone_library (
  tone_key TEXT PRIMARY KEY,
  display_name TEXT NOT NULL,
  description TEXT,
  language_patterns JSONB,
  emphasis TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Insert tone variants
INSERT INTO core.tone_library (tone_key, display_name, description, language_patterns, emphasis)
VALUES
  ('empathetic', 'Empathetic', 'Validates pain before offering solutions', '["I get it...", "You''re not alone...", "Here''s the truth..."]'::jsonb, 'emotional connection'),
  ('educational', 'Educational', 'Clear frameworks and systems', '["Here''s how it works...", "The 3-step process...", "Framework:"]'::jsonb, 'actionable knowledge'),
  ('motivational', 'Motivational', 'Energetic and inspiring', '["You can do this...", "It''s time to...", "Stop waiting and..."]'::jsonb, 'momentum and action'),
  ('urgent', 'Urgent', 'Time-sensitive and direct', '["Right now...", "Stop ignoring...", "The cost of waiting..."]'::jsonb, 'immediate action'),
  ('celebratory', 'Celebratory', 'Wins and community', '["Huge win...", "Shoutout to...", "Let''s celebrate..."]'::jsonb, 'community and success');
```

### Step 3: Replace InjectPersonaContext with QueryPersonaContext

**New Node**: QueryPersonaContext (PostgreSQL node)

```sql
SELECT
  p.name,
  p.archetype,
  p.pain_points,
  p.goals,
  p.voice,
  p.mindset,
  p.objections,
  p.triggers,
  p.cta_preferences,
  t.display_name as tone_name,
  t.language_patterns as tone_patterns,
  t.emphasis as tone_emphasis
FROM core.persona_library p
CROSS JOIN core.tone_library t
WHERE p.persona_key = $1
  AND t.tone_key = $2;
```

**Parameters**:
```javascript
[
  $json.persona_segment || 'marcus_mid_growth',
  $json.emotion_tone || 'empathetic'
]
```

### Step 4: Update MapperFunctionGen to Use Query Results

```javascript
const rows = $input.all().map(it => it.json);
const sys = rows.find(r => r.role === 'system')?.content || '';
const usr = rows.find(r => r.role === 'user')?.content || '';

// Get persona from database query instead of hardcoded object
const personaData = $('QueryPersonaContext').first().json;

// Parse JSONB fields
const persona = {
  name: personaData.name,
  archetype: personaData.archetype,
  pain_points: personaData.pain_points,
  goals: personaData.goals,
  voice: personaData.voice,
  mindset: personaData.mindset,
  objections: personaData.objections,
  triggers: personaData.triggers,
  cta_preferences: personaData.cta_preferences
};

const tone = {
  name: personaData.tone_name,
  patterns: personaData.tone_patterns,
  emphasis: personaData.tone_emphasis
};

// Inject into prompt template
const userPromptFilled = usr
  .replace('Pain Points: <PLACEHOLDER>', `Pain Points: ${persona.pain_points.join(', ')}`)
  .replace('Goals: <PLACEHOLDER>', `Goals: ${persona.goals.join(', ')}`)
  .replace('Tone: <PLACEHOLDER>', `Tone: ${tone.name} (${tone.emphasis})`)
  // ... more replacements ...

return [{
  json: {
    ...$json,
    system_prompt: sys,
    user_prompt: userPromptFilled,
    persona_used: persona,
    tone_used: tone
  }
}];
```

---

## 📋 SUMMARY: CURRENT STATE

### How Variables Flow Today

```
┌─────────────────────────────────────┐
│  InjectPersonaContext (JS Node)     │
│  - Hardcoded persona object         │
│  - Hardcoded brand object           │
│  - Hardcoded persona_tags array     │
└───────────┬─────────────────────────┘
            │ Adds to $json
            ↓
┌─────────────────────────────────────┐
│  SelectGeneratorPrompt (SQL Node)   │
│  - Queries system & user prompts    │
│    from core.prompt_library         │
└───────────┬─────────────────────────┘
            │ Returns prompt templates
            ↓
┌─────────────────────────────────────┐
│  MapperFunctionGen (JS Node)        │
│  - Combines prompts + persona data  │
│  - Replaces placeholders in user    │
│    prompt with hardcoded values     │
└───────────┬─────────────────────────┘
            │ Creates filled prompts
            ↓
┌─────────────────────────────────────┐
│  LLM Node (OpenAI/Gemini)           │
│  - Receives system + user prompts   │
│  - Generates content                │
└───────────┬─────────────────────────┘
            │ Returns generated content
            ↓
┌─────────────────────────────────────┐
│  UpdatePersonaFields (SQL Node)     │
│  - Writes persona_segment =         │
│    'mid_growth_owner' (hardcoded)   │
│  - Writes emotion_tone =            │
│    'burnout_to_control' (hardcoded) │
└─────────────────────────────────────┘
```

### Key Takeaways

1. **Brand voice variables are HARDCODED** in InjectPersonaContext JavaScript node (line 1288)

2. **Database fields exist but are UNUSED** for prompt generation:
   - `persona_segment` → Written but not read
   - `emotion_tone` → Written but not read
   - `day_theme` → Not written or read currently
   - `topic_category` → Not written or read currently

3. **Prompt templates have PLACEHOLDERS** but they're filled with hardcoded values, not database-driven values

4. **To make it dynamic**, you would need to:
   - Create persona/tone library tables
   - Replace InjectPersonaContext with QueryPersonaContext (SQL query)
   - Update MapperFunctionGen to use query results
   - Set persona_segment/emotion_tone BEFORE prompt generation (not after)

---

**END OF EXPLANATION**

*See ALL_BRAND_CLEAN.md for comprehensive brand voice guide and ALL_PROMPTS_CLEAN.md for exact prompt templates.*
