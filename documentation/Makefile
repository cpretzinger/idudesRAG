# idudesRAG Makefile - Quick Commands

.PHONY: help install build dev start stop restart logs clean deploy

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m # No Color

help: ## Show this help message
	@echo "$(BLUE)idudesRAG - Available Commands$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(GREEN)%-20s$(NC) %s\n", $$1, $$2}'

install: ## Install dependencies
	@echo "$(BLUE)Installing dependencies...$(NC)"
	cd ui && npm install

build: ## Build the Next.js application
	@echo "$(BLUE)Building application...$(NC)"
	cd ui && npm run build

dev: ## Start development server
	@echo "$(BLUE)Starting development server...$(NC)"
	cd ui && npm run dev

# Production Commands
docker-build: ## Build Docker image
	@echo "$(BLUE)Building Docker image...$(NC)"
	docker-compose -f docker-compose.prod.yml build

docker-up: ## Start Docker containers
	@echo "$(GREEN)Starting containers...$(NC)"
	docker-compose -f docker-compose.prod.yml up -d

docker-down: ## Stop Docker containers
	@echo "$(YELLOW)Stopping containers...$(NC)"
	docker-compose -f docker-compose.prod.yml down

docker-restart: docker-down docker-up ## Restart Docker containers

docker-logs: ## View Docker logs
	docker-compose -f docker-compose.prod.yml logs -f

docker-ps: ## Show running containers
	docker-compose -f docker-compose.prod.yml ps

# PM2 Commands
pm2-start: build ## Start with PM2
	@echo "$(GREEN)Starting with PM2...$(NC)"
	cd ui && pm2 start npm --name "idudes-ui" -- start
	pm2 save

pm2-stop: ## Stop PM2 process
	pm2 stop idudes-ui

pm2-restart: ## Restart PM2 process
	pm2 restart idudes-ui

pm2-logs: ## View PM2 logs
	pm2 logs idudes-ui

pm2-status: ## Show PM2 status
	pm2 status

# Testing & Verification
test-env: ## Test environment variables
	@echo "$(BLUE)Testing environment...$(NC)"
	curl http://localhost:3000/api/test-env | jq

test-db: ## Test database connection
	@echo "$(BLUE)Testing database...$(NC)"
	curl http://localhost:3000/api/test-db | jq

test-spaces: ## Test DigitalOcean Spaces
	@echo "$(BLUE)Testing Spaces...$(NC)"
	curl http://localhost:3000/api/test-spaces | jq

test-all: test-env test-db test-spaces ## Run all tests

# Deployment
deploy: ## Full deployment (Docker)
	@echo "$(GREEN)Deploying application...$(NC)"
	git pull origin main
	docker-compose -f docker-compose.prod.yml down
	docker-compose -f docker-compose.prod.yml up -d --build
	@echo "$(GREEN)Deployment complete!$(NC)"
	@make docker-logs

deploy-pm2: ## Full deployment (PM2)
	@echo "$(GREEN)Deploying application...$(NC)"
	git pull origin main
	cd ui && npm install && npm run build
	pm2 restart idudes-ui
	@echo "$(GREEN)Deployment complete!$(NC)"

# Cleanup
clean: ## Clean build artifacts
	@echo "$(YELLOW)Cleaning...$(NC)"
	cd ui && rm -rf .next
	cd ui && rm -rf node_modules
	docker-compose -f docker-compose.prod.yml down --rmi all -v

# Health Check
health: ## Check application health
	@echo "$(BLUE)Checking health...$(NC)"
	@curl -s http://localhost:3000/api/test-env > /dev/null && echo "$(GREEN)✓ Application is healthy$(NC)" || echo "$(YELLOW)✗ Application is not responding$(NC)"

# Backup
backup-env: ## Backup environment file
	@echo "$(BLUE)Backing up .env...$(NC)"
	cp .env .env.backup-$(shell date +%Y%m%d-%H%M%S)
	@echo "$(GREEN)Backup created!$(NC)"