# Production Docker Compose for idudesRAG
services:
  ui:
    build:
      context: ./ui
      dockerfile: Dockerfile
    container_name: idudes-rag-ui
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      # Database
      - DATABASE_URL=${DATABASE_URL}
      
      # DigitalOcean Spaces
      - SPACES_ACCESS_KEY=${SPACES_ACCESS_KEY}
      - SPACES_SECRET_KEY=${SPACES_SECRET_KEY}
      - SPACES_BUCKET=${SPACES_BUCKET}
      - SPACES_REGION=${SPACES_REGION}
      - SPACES_ENDPOINT=${SPACES_ENDPOINT}
      - SPACES_CDN_URL=${SPACES_CDN_URL}
      
      # OpenAI
      - OPENAI_API_KEY=${OPENAI_API_KEY}
      
      # n8n Webhooks
      - NEXT_PUBLIC_N8N_URL=${NEXT_PUBLIC_N8N_URL}
      - N8N_WEBHOOK_URL=${N8N_WEBHOOK_URL}
      
      # Next.js
      - NODE_ENV=production
      - NEXT_TELEMETRY_DISABLED=1
    
    env_file:
      - .env
    
    networks:
      - idudes-network
    
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:3000/api/test-env"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

networks:
  idudes-network:
    driver: bridge


Stopping containers... 
docker-compose -f docker-compose.prod.yml down
WARN[0000] The "SPACES_CDN_URL" variable is not set. Defaulting to a blank string. 
WARN[0000] The "NEXT_PUBLIC_N8N_URL" variable is not set. Defaulting to a blank string. 
WARN[0000] The "N8N_WEBHOOK_URL" variable is not set. Defaulting to a blank string. 
root@pretz-drop:/mnt/volume_nyc1_01/idudesRAG# nano .env
root@pretz-drop:/mnt/volume_nyc1_01/idudesRAG# make docker-down
Stopping containers... 
docker-compose -f docker-compose.prod.yml down
failed to read /mnt/volume_nyc1_01/idudesRAG/.env: line 24: unexpected character "\\" in variable name "\\"
make: *** [Makefile:39: docker-down] Error 1
root@pretz-drop:/mnt/volume_nyc1_01/idudesRAG# docker-compose -f docker-compose.prod.yml down
failed to read /mnt/volume_nyc1_01/idudesRAG/.env: line 24: unexpected character "\\" in variable name "\\"
root@pretz-drop:/mnt/volume_nyc1_01/idudesRAG# docker-compose -f docker-compose.prod.yml down
WARN[0000] The "SPACES_ENDPOINT" variable is not set. Defaulting to a blank string. 
WARN[0000] The "SPACES_CDN_URL" variable is not set. Defaulting to a blank string. 
root@pretz-drop:/mnt/volume_nyc1_01/idudesRAG# 

FIX IT BITCH