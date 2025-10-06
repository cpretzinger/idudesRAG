#!/bin/bash

# iDudes RAG Setup Script
# Automated configuration for DNS, SSL, and deployment

set -e

echo "🚀 iDudes RAG Setup"
echo "==================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if .env exists, if not create from template
setup_env() {
    if [ ! -f .env ]; then
        log_info "Creating .env file from template"
        if [ -f .env.example ]; then
            cp .env.example .env
        else
            cat > .env << EOF
# Database Configuration
CONTENT_DB_PASSWORD=secure_password_$(openssl rand -hex 8)
POSTGRES_PASSWORD=\${CONTENT_DB_PASSWORD}

# n8n Configuration  
N8N_PASSWORD=admin_password_$(openssl rand -hex 8)

# Domain Configuration
DOMAIN=yourdomain.com
API_SUBDOMAIN=api
CDN_SUBDOMAIN=cdn

# SSL Configuration
SSL_EMAIL=admin@yourdomain.com

# Cloudflare (optional)
CLOUDFLARE_API_TOKEN=
CLOUDFLARE_TUNNEL_TOKEN=

# DigitalOcean Spaces
SPACES_BUCKET=your-bucket
SPACES_REGION=nyc3
SPACES_ACCESS_KEY=
SPACES_SECRET_KEY=

# OpenAI
OPENAI_API_KEY=your_openai_key_here
EOF
        fi
        log_success ".env file created"
    else
        log_info ".env file already exists"
    fi
}

# Collect user configuration
collect_config() {
    echo
    log_info "Configuration Setup"
    echo "==================="
    
    # Domain configuration
    read -p "Enter your domain (e.g., yourdomain.com): " DOMAIN
    read -p "API subdomain [api]: " API_SUBDOMAIN
    API_SUBDOMAIN=${API_SUBDOMAIN:-api}
    read -p "CDN subdomain [cdn]: " CDN_SUBDOMAIN  
    CDN_SUBDOMAIN=${CDN_SUBDOMAIN:-cdn}
    
    # DNS Provider
    echo
    echo "DNS Provider:"
    echo "1) Cloudflare"
    echo "2) DigitalOcean"
    echo "3) Manual setup"
    read -p "Choose DNS provider [1]: " DNS_PROVIDER
    DNS_PROVIDER=${DNS_PROVIDER:-1}
    
    # SSL Configuration
    read -p "Email for SSL certificates: " SSL_EMAIL
    
    # Get server IP
    SERVER_IP=$(curl -s ifconfig.me || curl -s icanhazip.com || echo "UNKNOWN")
    log_info "Detected server IP: $SERVER_IP"
    read -p "Confirm server IP [$SERVER_IP]: " CONFIRM_IP
    SERVER_IP=${CONFIRM_IP:-$SERVER_IP}
    
    # Update .env file
    sed -i.bak \
        -e "s/DOMAIN=.*/DOMAIN=$DOMAIN/" \
        -e "s/API_SUBDOMAIN=.*/API_SUBDOMAIN=$API_SUBDOMAIN/" \
        -e "s/CDN_SUBDOMAIN=.*/CDN_SUBDOMAIN=$CDN_SUBDOMAIN/" \
        -e "s/SSL_EMAIL=.*/SSL_EMAIL=$SSL_EMAIL/" \
        .env
        
    log_success "Configuration saved to .env"
}

# Setup DNS records
setup_dns() {
    echo
    log_info "DNS Configuration"
    echo "=================="
    
    case $DNS_PROVIDER in
        1) # Cloudflare
            log_info "Cloudflare DNS Setup"
            if command -v cf &> /dev/null; then
                read -p "Cloudflare API token: " CF_TOKEN
                export CF_API_TOKEN=$CF_TOKEN
                
                log_info "Creating DNS records..."
                cf dns create $DOMAIN A $API_SUBDOMAIN $SERVER_IP --ttl 300
                cf dns create $DOMAIN CNAME $CDN_SUBDOMAIN $SPACES_BUCKET.$SPACES_REGION.digitaloceanspaces.com --ttl 300
                
                log_success "DNS records created"
            else
                log_warning "Cloudflare CLI not found. Manual setup required:"
                echo "Add these records in Cloudflare:"
                echo "  A    | $API_SUBDOMAIN | $SERVER_IP"
                echo "  CNAME| $CDN_SUBDOMAIN | $SPACES_BUCKET.$SPACES_REGION.digitaloceanspaces.com"
            fi
            ;;
        2) # DigitalOcean
            log_info "DigitalOcean DNS Setup"
            if command -v doctl &> /dev/null; then
                log_info "Creating DNS records..."
                doctl compute domain records create $DOMAIN \
                    --record-type A \
                    --record-name $API_SUBDOMAIN \
                    --record-data $SERVER_IP \
                    --record-ttl 300
                    
                doctl compute domain records create $DOMAIN \
                    --record-type CNAME \
                    --record-name $CDN_SUBDOMAIN \
                    --record-data $SPACES_BUCKET.$SPACES_REGION.digitaloceanspaces.com \
                    --record-ttl 300
                    
                log_success "DNS records created"
            else
                log_warning "DigitalOcean CLI not found. Manual setup required:"
                echo "Add these records in DigitalOcean:"
                echo "  A    | $API_SUBDOMAIN | $SERVER_IP"
                echo "  CNAME| $CDN_SUBDOMAIN | $SPACES_BUCKET.$SPACES_REGION.digitaloceanspaces.com"
            fi
            ;;
        3) # Manual
            log_warning "Manual DNS setup required:"
            echo "Add these records to your DNS provider:"
            echo "  Type | Name           | Value"
            echo "  A    | $API_SUBDOMAIN | $SERVER_IP"
            echo "  CNAME| $CDN_SUBDOMAIN | $SPACES_BUCKET.$SPACES_REGION.digitaloceanspaces.com"
            echo
            read -p "Press Enter when DNS records are added..."
            ;;
    esac
}

# Generate SSL certificates
setup_ssl() {
    echo
    log_info "SSL Certificate Setup"
    echo "===================="
    
    # Create certs directory
    mkdir -p certs
    
    if command -v certbot &> /dev/null; then
        log_info "Generating Let's Encrypt certificates..."
        
        # Generate certificates for both subdomains
        certbot certonly --standalone \
            --email $SSL_EMAIL \
            --agree-tos \
            --no-eff-email \
            -d $API_SUBDOMAIN.$DOMAIN \
            -d $CDN_SUBDOMAIN.$DOMAIN
            
        # Copy certificates to local certs directory
        cp /etc/letsencrypt/live/$API_SUBDOMAIN.$DOMAIN/fullchain.pem certs/cert.pem
        cp /etc/letsencrypt/live/$API_SUBDOMAIN.$DOMAIN/privkey.pem certs/key.pem
        
        log_success "SSL certificates generated"
    else
        log_warning "Certbot not found. Installing..."
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            sudo apt-get update && sudo apt-get install -y certbot
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            brew install certbot
        else
            log_error "Please install certbot manually"
            exit 1
        fi
        setup_ssl  # Retry after installation
    fi
}

# Setup Docker containers
setup_containers() {
    echo
    log_info "Docker Container Setup"
    echo "======================"
    
    # Check if Docker is running
    if ! docker info &> /dev/null; then
        log_error "Docker is not running. Please start Docker and try again."
        exit 1
    fi
    
    log_info "Building and starting containers..."
    docker-compose down --remove-orphans
    docker-compose up -d --build
    
    # Wait for database to be ready
    log_info "Waiting for database to be ready..."
    timeout=60
    while ! docker-compose exec -T content_postgres pg_isready -U content_admin -d content_rag &> /dev/null; do
        if [ $timeout -le 0 ]; then
            log_error "Database failed to start within 60 seconds"
            exit 1
        fi
        sleep 2
        timeout=$((timeout-2))
        echo -n "."
    done
    echo
    
    log_success "Containers started successfully"
}

# Test the setup
test_setup() {
    echo
    log_info "Testing Setup"
    echo "============="
    
    # Test API endpoint
    API_URL="https://$API_SUBDOMAIN.$DOMAIN"
    log_info "Testing API at $API_URL"
    
    if curl -s -f "$API_URL/health" &> /dev/null; then
        log_success "API is responding"
    else
        log_warning "API not responding yet (this is normal for new deployments)"
    fi
    
    # Test n8n interface
    N8N_URL="https://$API_SUBDOMAIN.$DOMAIN:5679"
    log_info "n8n interface available at: $N8N_URL"
    
    # Display credentials
    echo
    log_info "Setup Complete!"
    echo "================"
    echo "🌐 API URL: $API_URL"
    echo "🔧 n8n URL: $N8N_URL"
    echo "📁 CDN URL: https://$CDN_SUBDOMAIN.$DOMAIN"
    echo
    echo "Credentials:"
    echo "n8n Username: content_team"
    echo "n8n Password: $(grep N8N_PASSWORD .env | cut -d'=' -f2)"
    echo
    log_success "Setup completed successfully!"
}

# Main execution
main() {
    echo "Starting automated setup..."
    
    # Load environment if exists
    [ -f .env ] && source .env
    
    setup_env
    collect_config
    setup_dns
    setup_ssl
    setup_containers
    test_setup
    
    echo
    log_success "🎉 iDudes RAG is ready!"
    echo "Next steps:"
    echo "1. Import n8n workflow from idudes-n8n-workflow.json"
    echo "2. Configure your content sources"
    echo "3. Start processing your podcast episodes"
}

# Run main function
main "$@"