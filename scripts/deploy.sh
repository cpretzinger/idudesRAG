#!/bin/bash

# 🚀 ONE-CLICK RAG DEPLOYMENT SCRIPT
# Usage: ./deploy.sh <tenant-name> <domain>

set -e

TENANT_NAME=$1
DOMAIN=$2
TENANT_SLUG=$(echo "$TENANT_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

echo "🎯 Deploying RAG for: $TENANT_NAME"
echo "📌 Slug: $TENANT_SLUG"
echo "🌐 Domain: $DOMAIN"

# 1. Create tenant config from template
echo "📝 Creating configuration..."
cp config.template.json "configs/$TENANT_SLUG.json"
sed -i "" "s/\${TENANT_SLUG}/$TENANT_SLUG/g" "configs/$TENANT_SLUG.json"
sed -i "" "s/\${TENANT_DOMAIN}/$DOMAIN/g" "configs/$TENANT_SLUG.json"

# 2. Generate environment file
echo "🔐 Generating environment..."
cat > ".env.$TENANT_SLUG" <<EOF
TENANT_SLUG=$TENANT_SLUG
TENANT_NAME="$TENANT_NAME"
DOMAIN=$DOMAIN
DATABASE_URL=$DATABASE_URL
REDIS_URL=$REDIS_URL
OPENAI_API_KEY=$OPENAI_API_KEY
N8N_WEBHOOK_BASE=https://n8n.thirdeyediagnostics.com/webhook
STORAGE_URL=https://storage.thirdeyediagnostics.com
EOF

# 3. Initialize database schema
echo "🗄️ Setting up database..."
psql "$DATABASE_URL" <<SQL
-- Create tenant-specific schema
CREATE SCHEMA IF NOT EXISTS tenant_$TENANT_SLUG;

-- Create tables in tenant schema
CREATE TABLE IF NOT EXISTS tenant_$TENANT_SLUG.documents (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    filename TEXT NOT NULL,
    content TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS tenant_$TENANT_SLUG.document_embeddings (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    document_id UUID REFERENCES tenant_$TENANT_SLUG.documents(id) ON DELETE CASCADE,
    chunk_text TEXT,
    embedding vector(1536),
    chunk_index INTEGER,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Create index for vector search
CREATE INDEX IF NOT EXISTS idx_${TENANT_SLUG}_embeddings 
ON tenant_$TENANT_SLUG.document_embeddings 
USING ivfflat (embedding vector_cosine_ops);
SQL

# 4. Create MinIO bucket
echo "📦 Setting up storage..."
docker exec idudes-minio mc alias set local http://localhost:9000 minioadmin $MINIO_PASSWORD
docker exec idudes-minio mc mb "local/$TENANT_SLUG-documents" --ignore-existing
docker exec idudes-minio mc policy set public "local/$TENANT_SLUG-documents"

# 5. Deploy to Vercel
echo "🚀 Deploying UI to Vercel..."
cd ui
vercel --prod --env-file "../.env.$TENANT_SLUG" --name "$TENANT_SLUG-rag"

# 6. Create n8n webhook workflow
echo "🔗 Setting up n8n webhook..."
curl -X POST "https://n8n.thirdeyediagnostics.com/api/v1/workflows" \
  -H "X-N8N-API-KEY: $N8N_API_KEY" \
  -H "Content-Type: application/json" \
  -d @- <<JSON
{
  "name": "RAG-$TENANT_NAME",
  "nodes": [
    {
      "name": "Webhook",
      "type": "n8n-nodes-base.webhook",
      "parameters": {
        "path": "$TENANT_SLUG/ingest",
        "responseMode": "onReceived"
      }
    },
    {
      "name": "Process Document",
      "type": "n8n-nodes-base.function",
      "parameters": {
        "functionCode": "return items.map(item => ({...item, tenant: '$TENANT_SLUG'}));"
      }
    }
  ]
}
JSON

# 7. Update Traefik routing
echo "🔀 Configuring routing..."
cat >> docker-compose.yml <<YAML

  # Auto-generated for $TENANT_NAME
  $TENANT_SLUG-proxy:
    container_name: $TENANT_SLUG-proxy
    image: nginx:alpine
    networks:
      - 3e-network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.$TENANT_SLUG.rule=Host(\`$DOMAIN\`)"
      - "traefik.http.routers.$TENANT_SLUG.tls=true"
      - "traefik.http.routers.$TENANT_SLUG.tls.certresolver=letsencrypt"
YAML

# 8. Start services
echo "🔄 Starting services..."
docker-compose up -d

echo "✅ Deployment complete!"
echo ""
echo "📋 Next steps:"
echo "1. Visit: https://$DOMAIN"
echo "2. Upload test document"
echo "3. Share webhook: https://n8n.thirdeyediagnostics.com/webhook/$TENANT_SLUG/ingest"
echo ""
echo "🎉 $TENANT_NAME RAG is live!"