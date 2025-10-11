# Share My Status - Minimal Makefile
# Only the most basic development setup, deployment and ops commands

.PHONY: help setup dev dev-start dev-stop dev-logs dev-clean prod prod-start prod-stop prod-restart prod-status prod-logs deploy clean health hz-update wire prod-rebuild-backend prod-rebuild-frontend

# Default target
help: ## Show available commands
	@echo "Share My Status - Basic Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Examples:"
	@echo "  make setup       # Prepare local env files"
	@echo "  make dev-start   # Start development services"
	@echo "  make deploy      # Deploy to production"
	@echo "  make prod-logs   # View production logs"

# Environment Setup
setup: ## Prepare local environment files (.env and backend/.env)
	@echo "🛠️ Preparing environment files..."
	@if [ ! -f ".env" ]; then \
		if [ -f ".env.example" ]; then \
			echo "📝 Creating .env from .env.example"; \
			cp .env.example .env; \
		else \
			echo "⚠️ .env.example not found, please create .env manually"; \
		fi; \
	fi
	@if [ ! -f "backend/.env" ]; then \
		if [ -f "backend/.env.example" ]; then \
			echo "📝 Creating backend/.env from backend/.env.example"; \
			cp backend/.env.example backend/.env; \
		else \
			echo "⚠️ backend/.env.example not found, please create backend/.env manually"; \
		fi; \
	fi
	@echo "✅ Environment setup complete. Review .env and backend/.env before starting."

# Development Commands
dev: dev-start ## Start development environment (alias)

COMPOSE := $(shell if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then echo docker\ compose; else echo docker-compose; fi)
ENV_FILE := .env
COMPOSE_FILE := docker-compose.yml

dev-start: ## Start development services
	@echo "🚀 Starting development environment..."
	@$(COMPOSE) --env-file $(ENV_FILE) -f $(COMPOSE_FILE) up -d
	@$(COMPOSE) --env-file $(ENV_FILE) -f $(COMPOSE_FILE) ps

dev-stop: ## Stop development services
	@echo "🛑 Stopping development environment..."
	@$(COMPOSE) --env-file $(ENV_FILE) -f $(COMPOSE_FILE) down

dev-logs: ## Show development logs
	@echo "📋 Showing development logs..."
	@$(COMPOSE) --env-file $(ENV_FILE) -f $(COMPOSE_FILE) logs -f

dev-clean: ## Clean development data
	@echo "🧹 Cleaning development data..."
	@$(COMPOSE) --env-file $(ENV_FILE) -f $(COMPOSE_FILE) down -v --remove-orphans

# Production / Ops Commands
prod: prod-start ## Start production services (alias)

prod-start: ## Start production services
	@echo "🚀 Starting production services..."
	@$(COMPOSE) --env-file $(ENV_FILE) -f $(COMPOSE_FILE) up -d
	@$(COMPOSE) --env-file $(ENV_FILE) -f $(COMPOSE_FILE) ps

prod-stop: ## Stop production services
	@echo "🛑 Stopping production services..."
	@$(COMPOSE) --env-file $(ENV_FILE) -f $(COMPOSE_FILE) down

prod-restart: ## Restart production services
	@echo "🔄 Restarting production services..."
	@$(COMPOSE) --env-file $(ENV_FILE) -f $(COMPOSE_FILE) restart || { $(COMPOSE) --env-file $(ENV_FILE) -f $(COMPOSE_FILE) down; $(COMPOSE) --env-file $(ENV_FILE) -f $(COMPOSE_FILE) up -d; }
	@$(COMPOSE) --env-file $(ENV_FILE) -f $(COMPOSE_FILE) ps

prod-status: ## Show production service status
	@echo "📊 Checking production status..."
	@$(COMPOSE) --env-file $(ENV_FILE) -f $(COMPOSE_FILE) ps

prod-logs: ## Show production logs
	@echo "📋 Showing production logs..."
	@$(COMPOSE) --env-file $(ENV_FILE) -f $(COMPOSE_FILE) logs -f

# Deployment
deploy: ## Deploy to production
	@echo "🚀 Deploying to production..."
	@$(COMPOSE) --env-file $(ENV_FILE) -f $(COMPOSE_FILE) pull || true
	@$(COMPOSE) --env-file $(ENV_FILE) -f $(COMPOSE_FILE) up -d

# Ops Utilities
clean: ## Clean up Docker resources (containers, images, volumes)
	@echo "🧹 Cleaning up Docker resources..."
	@docker system prune -f
	@docker volume prune -f

health: ## Check backend service health
	@echo "🏥 Checking service health..."
	@curl -f http://localhost:8080/healthz || echo "❌ Backend unhealthy"

hz-update: ## Update backend code from IDL files
	@echo "🔄 Updating backend code from IDL..."
	@cd backend && hz update -idl ../idl/api.thrift

wire: ## Generate dependency injection code
	@echo "🔌 Generating dependency injection code..."
	@cd backend && wire ./infra/


prod-rebuild-backend: ## Rebuild backend service (rm container/image, then compose up)
	@echo "🧱 Rebuilding backend service..."
	@docker rm -f share-my-status-backend || true
	@docker image rm -f share-my-status-share-backend:latest || docker image rm -f share-my-status_share-backend:latest || true
	@$(COMPOSE) --env-file $(ENV_FILE) -f $(COMPOSE_FILE) up -d share-backend

prod-rebuild-frontend: ## Rebuild frontend service (rm container/image, then compose up)
	@echo "🧩 Rebuilding frontend service..."
	@docker rm -f share-my-status-web || true
	@docker image rm -f share-my-status-share-web:latest || docker image rm -f share-my-status_share-web:latest || true
	@$(COMPOSE) --env-file $(ENV_FILE) -f $(COMPOSE_FILE) up -d share-web