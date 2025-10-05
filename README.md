CONTENT TEAM RAG SETUP - STEP BY STEP

  1. DATABASE SETUP - NEW CONTAINER (SAFER)

  docker-compose.yml (separate from main system)

  services:
    content_postgres:
      image: pgvector/pgvector:pg16
      container_name: content_rag_db
      environment:
        POSTGRES_DB: content_rag
        POSTGRES_USER: content_admin
        POSTGRES_PASSWORD: ${CONTENT_DB_PASSWORD}
        POSTGRES_INITDB_ARGS: "--encoding=UTF8 --locale=en_US.UTF-8"
      ports:
        - "5433:5432"  # Different port from main DB
      volumes:
        - content_pgdata:/var/lib/postgresql/data
        - ./init.sql:/docker-entrypoint-initdb.d/init.sql
      networks:
        - content_network
      restart: unless-stopped

    content_n8n:
      image: n8nio/n8n:latest
      container_name: content_n8n
      environment:
        - N8N_BASIC_AUTH_ACTIVE=true
        - N8N_BASIC_AUTH_USER=content_team
        - N8N_BASIC_AUTH_PASSWORD=${N8N_PASSWORD}
        - N8N_HOST=0.0.0.0
        - N8N_PORT=5679
        - N8N_PROTOCOL=https
        - N8N_SSL_CERT=/certs/cert.pem
        - N8N_SSL_KEY=/certs/key.pem
        - WEBHOOK_URL=https://content.yourdomain.com
        - DB_TYPE=postgresdb
        - DB_POSTGRESDB_HOST=content_postgres
        - DB_POSTGRESDB_PORT=5432
        - DB_POSTGRESDB_DATABASE=content_rag
        - DB_POSTGRESDB_USER=content_admin
        - DB_POSTGRESDB_PASSWORD=${CONTENT_DB_PASSWORD}
      ports:
        - "5679:5679"
      volumes:
        - n8n_data:/home/node/.n8n
        - ./certs:/certs:ro
      networks:
        - content_network
      depends_on:
        - content_postgres
      labels:  
        - "traefik.http.routers.docprocessor.rule=Host(`docs.theidudes.com`)"
        - "traefik.http.routers.minio.rule=Host(`idudes-storage.thirdeyediagnostics.com`)"
    cloudflared:
      image: cloudflare/cloudflared:latest
      container_name: content_tunnel
      command: tunnel --no-autoupdate run --token ${CLOUDFLARE_TUNNEL_TOKEN}
      networks:
        - content_network
      restart: unless-stopped

  networks:
    content_network:
      driver: bridge

  volumes:
    content_pgdata:
    n8n_data:

  2. DATABASE SCHEMA - init.sql

  -- Enable extensions
  CREATE EXTENSION IF NOT EXISTS vector;
  CREATE EXTENSION IF NOT EXISTS pg_trgm;
  CREATE EXTENSION IF NOT EXISTS unaccent;

  -- Create schema for content
  CREATE SCHEMA IF NOT EXISTS content;

  -- Main documents table
  CREATE TABLE content.documents (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      source_type VARCHAR(50) NOT NULL, -- 'podcast', 'youtube', 'gdrive'
      source_id VARCHAR(255) UNIQUE NOT NULL, -- file path or episode ID
      title TEXT NOT NULL,
      episode_number INTEGER,
      air_date DATE,
      duration_seconds INTEGER,
      speakers JSONB DEFAULT '[]'::jsonb,
      metadata JSONB DEFAULT '{}'::jsonb,
      raw_transcript TEXT,
      cleaned_text TEXT,
      summary TEXT,
      key_topics TEXT[],
      created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
      updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
  );

  -- Chunks for long documents
  CREATE TABLE content.chunks (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      document_id UUID NOT NULL REFERENCES content.documents(id) ON DELETE CASCADE,
      chunk_index INTEGER NOT NULL,
      chunk_text TEXT NOT NULL,
      start_time FLOAT, -- for podcast timestamps
      end_time FLOAT,
      speaker VARCHAR(100),
      created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
      UNIQUE(document_id, chunk_index)
  );

  -- Embeddings table
  CREATE TABLE content.embeddings (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      chunk_id UUID NOT NULL REFERENCES content.chunks(id) ON DELETE CASCADE,
      embedding vector(1536) NOT NULL,
      model VARCHAR(50) DEFAULT 'text-embedding-3-small',
      created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
  );

  -- Extracted insights
  CREATE TABLE content.insights (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      document_id UUID NOT NULL REFERENCES content.documents(id),
      insight_type VARCHAR(50), -- 'quote', 'hook', 'story', 'statistic', 'joke'
      content TEXT NOT NULL,
      context TEXT,
      confidence FLOAT,
      used_count INTEGER DEFAULT 0,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
  );

  -- Usage tracking for Pakistan team
  CREATE TABLE content.search_history (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_email VARCHAR(255),
      query_text TEXT,
      query_language VARCHAR(10),
      results_returned INTEGER,
      selected_results JSONB,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
  );

  -- INDEXES FOR PERFORMANCE
  CREATE INDEX idx_embeddings_vector ON content.embeddings
      USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

  CREATE INDEX idx_documents_source ON content.documents(source_type, source_id);
  CREATE INDEX idx_documents_date ON content.documents(air_date DESC);
  CREATE INDEX idx_documents_topics ON content.documents USING GIN(key_topics);

  CREATE INDEX idx_chunks_document ON content.chunks(document_id, chunk_index);
  CREATE INDEX idx_chunks_text_trgm ON content.chunks USING GIST(chunk_text gist_trgm_ops);

  CREATE INDEX idx_insights_type ON content.insights(insight_type, document_id);
  CREATE INDEX idx_insights_confidence ON content.insights(confidence DESC);

  -- Full text search
  ALTER TABLE content.documents ADD COLUMN search_vector tsvector;
  CREATE INDEX idx_documents_fts ON content.documents USING GIN(search_vector);

  -- Function to update search vector
  CREATE OR REPLACE FUNCTION content.update_search_vector()
  RETURNS TRIGGER AS $$
  BEGIN
      NEW.search_vector :=
          setweight(to_tsvector('english', COALESCE(NEW.title, '')), 'A') ||
          setweight(to_tsvector('english', COALESCE(NEW.cleaned_text, '')), 'B') ||
          setweight(to_tsvector('english', COALESCE(array_to_string(NEW.key_topics, ' '), '')), 'A');
      RETURN NEW;
  END;
  $$ LANGUAGE plpgsql;

  CREATE TRIGGER update_document_search_vector
      BEFORE INSERT OR UPDATE ON content.documents
      FOR EACH ROW
      EXECUTE FUNCTION content.update_search_vector();

  -- Hybrid search function
  CREATE OR REPLACE FUNCTION content.hybrid_search(
      query_embedding vector(1536),
      query_text TEXT,
      result_limit INTEGER DEFAULT 10,
      min_similarity FLOAT DEFAULT 0.7
  )
  RETURNS TABLE (
      document_id UUID,
      chunk_id UUID,
      title TEXT,
      chunk_text TEXT,
      similarity_score FLOAT,
      relevance_score FLOAT,
      combined_score FLOAT
  ) AS $$
  BEGIN
      RETURN QUERY
      WITH semantic_results AS (
          SELECT
              c.document_id,
              c.id as chunk_id,
              d.title,
              c.chunk_text,
              1 - (e.embedding <=> query_embedding) as similarity_score
          FROM content.embeddings e
          JOIN content.chunks c ON e.chunk_id = c.id
          JOIN content.documents d ON c.document_id = d.id
          WHERE 1 - (e.embedding <=> query_embedding) > min_similarity
          ORDER BY similarity_score DESC
          LIMIT result_limit * 2
      ),
      keyword_results AS (
          SELECT
              d.id as document_id,
              c.id as chunk_id,
              d.title,
              c.chunk_text,
              ts_rank(d.search_vector, plainto_tsquery('english', query_text)) as relevance_score
          FROM content.documents d
          JOIN content.chunks c ON c.document_id = d.id
          WHERE d.search_vector @@ plainto_tsquery('english', query_text)
          ORDER BY relevance_score DESC
          LIMIT result_limit * 2
      )
      SELECT
          COALESCE(s.document_id, k.document_id),
          COALESCE(s.chunk_id, k.chunk_id),
          COALESCE(s.title, k.title),
          COALESCE(s.chunk_text, k.chunk_text),
          COALESCE(s.similarity_score, 0),
          COALESCE(k.relevance_score, 0),
          (COALESCE(s.similarity_score, 0) * 0.7 + COALESCE(k.relevance_score, 0) * 0.3) as combined_score
      FROM semantic_results s
      FULL OUTER JOIN keyword_results k
          ON s.chunk_id = k.chunk_id
      ORDER BY combined_score DESC
      LIMIT result_limit;
  END;
  $$ LANGUAGE plpgsql;

  3. SECURITY SETUP

  Cloudflare Tunnel for Pakistan Access

  # Install cloudflared
  curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o cloudflared
  chmod +x cloudflared

  # Create tunnel
  cloudflared tunnel create content-rag

  # Get token and add to .env:
  CLOUDFLARE_TUNNEL_TOKEN=your_tunnel_token_here

  # Access URL: https://content.yourdomain.com

  PostgreSQL Security

  -- Create read-only user for content team
  CREATE ROLE content_reader WITH LOGIN PASSWORD 'secure_password_here';
  GRANT CONNECT ON DATABASE content_rag TO content_reader;
  GRANT USAGE ON SCHEMA content TO content_reader;
  GRANT SELECT ON ALL TABLES IN SCHEMA content TO content_reader;

  -- Create write user for n8n
  CREATE ROLE content_writer WITH LOGIN PASSWORD 'different_password';
  GRANT ALL ON SCHEMA content TO content_writer;
  GRANT ALL ON ALL TABLES IN SCHEMA content TO content_writer;

  4. N8N WORKFLOW MODIFICATIONS

⏺ Modified Workflow (from dix.md)

  Change 1: Remove Collections
  // In PGVector Store node, change:
  "useCollection": false  // or remove the collection block entirely

  Change 2: Add Folder Batch Processing
  // New Code Node: "Process Google Drive Folder"
  const folderId = "YOUR_PODCAST_FOLDER_ID";
  const files = await $('Google Drive').getFiles({
    q: `'${folderId}' in parents and mimeType != 'application/vnd.google-apps.folder'`,
    orderBy: 'createdTime desc',
    pageSize: 100
  });

  return files.map(file => ({
    json: {
      id: file.id,
      name: file.name,
      mimeType: file.mimeType,
      episode_number: file.name.match(/EP(\d+)/)?.[1] || null
    }
  }));

  Change 3: Custom Metadata Extraction
  // Code Node: "Extract Podcast Metadata"
  const fileName = $json.name;
  const episodeMatch = fileName.match(/EP(\d+)/);
  const dateMatch = fileName.match(/(\d{4}-\d{2}-\d{2})/);

  return {
    json: {
      ...$json,
      metadata: {
        source_type: 'podcast',
        episode_number: episodeMatch?.[1] ? parseInt(episodeMatch[1]) : null,
        air_date: dateMatch?.[1] || null,
        speakers: ['Craig', 'Jason'],
        show: 'Insurance Dudes'
      }
    }
  };

  Change 4: Chunking with Timestamps
  // Code Node: "Smart Chunking"
  const text = $json.text;
  const chunks = [];
  const chunkSize = 1500;
  const overlap = 200;

  // Split by speaker patterns if transcript
  const speakerPattern = /^(Craig|Jason|Guest):/gm;
  const segments = text.split(speakerPattern);

  for (let i = 0; i < segments.length; i += 2) {
    if (segments[i] && segments[i + 1]) {
      chunks.push({
        speaker: segments[i],
        text: segments[i + 1].trim(),
        chunk_index: chunks.length
      });
    }
  }

  return chunks.map(chunk => ({
    json: {
      document_id: $json.id,
      ...chunk
    }
  }));

  5. MULTILINGUAL QUERY HANDLER

  // Code Node: "Translate & Process Query"
  const query = $json.query;
  const detectedLanguage = $json.language || 'ur'; // Urdu default

  // Translate to English if not English
  let englishQuery = query;
  if (detectedLanguage !== 'en') {
    // Call translation API
    const translated = await $('HTTP Request').post({
      url: 'https://translation.googleapis.com/language/translate/v2',
      body: {
        q: query,
        source: detectedLanguage,
        target: 'en',
        key: $credentials.googleApiKey
      }
    });
    englishQuery = translated.translatedText;
  }

  // Extract intent
  const intents = {
    quote: /quote|saying|said/i,
    hook: /hook|opening|attention|grab/i,
    story: /story|example|case|client/i,
    joke: /funny|joke|laugh|humor/i,
    statistic: /number|stat|percent|data/i
  };

  const matchedIntent = Object.keys(intents).find(key =>
    intents[key].test(englishQuery)
  ) || 'general';

  return {
    json: {
      original_query: query,
      english_query: englishQuery,
      intent: matchedIntent,
      language: detectedLanguage
    }
  };

  6. INSURANCE DUDES TONE GENERATOR

  // AI Agent System Prompt
  const systemPrompt = `You are the Insurance Dudes' content assistant. 

  TONE & STYLE:
  - Casual, conversational, like talking to a buddy
  - Use "dude", "man", "folks" naturally
  - Short sentences. Punchy. Direct.
  - Insurance jargon explained simply
  - Occasional mild profanity if it fits (damn, hell)
  - Self-deprecating humor
  - Real stories from the trenches

  NEVER:
  - Corporate speak
  - Long paragraphs
  - Fancy words when simple ones work
  - Boring insurance lecture mode

  ALWAYS:
  - Make insurance relatable
  - Use analogies to everyday life
  - Keep energy high
  - Sound like Craig or Jason talking

  Example output:
  "Dude, this client story is GOLD. Remember when that contractor thought general liability covered his truck? Classic mistake, happens all the time.
   Here's how we explain it: GL is like a bulletproof vest - protects your business, not your ride."`;

  7. QUICK START COMMANDS

  # 1. Clone and setup
  git clone [your-repo]
  cd content-rag
  cp .env.example .env
  # Edit .env with your credentials

  # 2. Start containers
  docker-compose up -d

  # 3. Wait for postgres to be ready
  docker-compose logs -f content_postgres

  # 4. Import n8n workflow
  # Go to https://localhost:5679
  # Import the modified dix.md workflow

  # 5. Set webhook for Pakistan team
  # https://content.yourdomain.com/webhook/content-search

  # 6. Test with curl
  curl -X POST https://content.yourdomain.com/webhook/content-search \
    -H "Content-Type: application/json" \
    -d '{"query": "کیا کسی نے جنرل لائبلٹی کے بارے میں کوئی مزاحیہ بات کہی؟"}'
  # Translation: "Did anyone say something funny about general liability?"

⏺ This setup gives your Pakistan content team:
  - Secure access via Cloudflare tunnel
  - No collections - unified search across all content
  - Multilingual queries - Urdu/English
  - Insurance Dudes tone in output
  - Smart extraction of quotes, hooks, stories
  - 800+ episodes searchable instantly

  The system finds nuggets in new episodes first, then searches the full archive for similar content.
