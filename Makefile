# Share My Status - Makefile
# Simplifies common development and deployment tasks

.PHONY: help dev dev-start dev-stop dev-logs dev-clean prod prod-start prod-stop prod-status prod-logs prod-update build deploy backup restore test clean install

# Default target
help: ## Show this help message
	@echo "Share My Status - Available Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Examples:"
	@echo "  make dev-start    # Start development environment"
	@echo "  make prod-deploy  # Deploy to production"
	@echo "  make backup       # Create backup"

# Development Commands
dev: dev-start ## Start development environment (alias for dev-start)

dev-start: ## Start development services
	@echo "🚀 Starting development environment..."
	@./scripts/dev.sh start

dev-stop: ## Stop development services
	@echo "🛑 Stopping development environment..."
	@./scripts/dev.sh stop

dev-restart: ## Restart development services
	@echo "🔄 Restarting development environment..."
	@./scripts/dev.sh restart

dev-logs: ## Show development logs
	@echo "📋 Showing development logs..."
	@./scripts/dev.sh logs

dev-clean: ## Clean development data
	@echo "🧹 Cleaning development data..."
	@./scripts/dev.sh clean

dev-backend: ## Run backend locally with hot reload
	@echo "🔥 Starting backend with hot reload..."
	@./scripts/dev.sh backend

hz-update: ## Update backend code from IDL files
	@echo "🔄 Updating backend code from IDL..."
	@cd backend && hz update -idl ../idl/api.thrift

# Production Commands
prod: prod-start ## Start production services (alias for prod-start)

prod-start: ## Start production services
	@echo "🚀 Starting production services..."
	@./scripts/start.sh start

prod-stop: ## Stop production services
	@echo "🛑 Stopping production services..."
	@./scripts/start.sh stop

prod-restart: ## Restart production services
	@echo "🔄 Restarting production services..."
	@./scripts/start.sh restart

prod-status: ## Show production service status
	@echo "📊 Checking production status..."
	@./scripts/start.sh status

prod-logs: ## Show production logs
	@echo "📋 Showing production logs..."
	@./scripts/start.sh logs

prod-monitor: ## Monitor production services
	@echo "👀 Monitoring production services..."
	@./scripts/start.sh monitor

prod-update: ## Update production deployment
	@echo "⬆️ Updating production deployment..."
	@./scripts/start.sh update

# Deployment Commands
build: ## Build application images
	@echo "🔨 Building application..."
	@docker build -t share-my-status-backend:latest ./backend/

deploy: ## Deploy to production with backup
	@echo "🚀 Deploying to production..."
	@./scripts/deploy.sh

deploy-skip-backup: ## Deploy to production without backup
	@echo "🚀 Deploying to production (skipping backup)..."
	@./scripts/deploy.sh --skip-backup

deploy-skip-build: ## Deploy to production without building
	@echo "🚀 Deploying to production (skipping build)..."
	@./scripts/deploy.sh --skip-build

# Backup Commands
backup: ## Create backup
	@echo "💾 Creating backup..."
	@./scripts/backup.sh create

backup-list: ## List available backups
	@echo "📋 Listing backups..."
	@./scripts/backup.sh list

backup-clean: ## Clean old backups (7+ days)
	@echo "🧹 Cleaning old backups..."
	@./scripts/backup.sh clean

restore: ## Restore from backup (requires BACKUP_NAME)
	@if [ -z "$(BACKUP_NAME)" ]; then \
		echo "❌ Please specify BACKUP_NAME: make restore BACKUP_NAME=20240101_120000"; \
		exit 1; \
	fi
	@echo "🔄 Restoring from backup: $(BACKUP_NAME)..."
	@./scripts/backup.sh restore $(BACKUP_NAME)

# Utility Commands
install: ## Install dependencies and setup environment
	@echo "📦 Installing dependencies..."
	@if [ ! -f ".env.docker" ]; then \
		echo "📝 Creating environment file..."; \
		cp .env.docker.example .env.docker 2>/dev/null || echo "Please create .env.docker manually"; \
	fi
	@echo "✅ Setup complete. Please edit .env.docker with your configuration."

test: ## Run tests
	@echo "🧪 Running tests..."
	@cd backend && go test ./...

lint: ## Run linting
	@echo "🔍 Running linting..."
	@cd backend && go vet ./...
	@cd backend && golangci-lint run || echo "golangci-lint not installed, skipping"

format: ## Format code
	@echo "✨ Formatting code..."
	@cd backend && go fmt ./...

clean: ## Clean up containers, images, and volumes
	@echo "🧹 Cleaning up Docker resources..."
	@docker system prune -f
	@docker volume prune -f

clean-all: ## Clean up everything including data
	@echo "⚠️  This will remove all data! Press Ctrl+C to cancel..."
	@sleep 5
	@docker-compose --env-file .env.docker down -v --remove-orphans
	@docker system prune -af
	@docker volume prune -f
	@rm -rf data/
	@echo "🧹 Complete cleanup finished"

# Health Checks
health: ## Check service health
	@echo "🏥 Checking service health..."
	@curl -f http://localhost:8080/health || echo "❌ Backend unhealthy"
	@curl -f http://localhost:9090/-/healthy || echo "❌ Prometheus unhealthy"
	@curl -f http://localhost:3000/api/health || echo "❌ Grafana unhealthy"

# Quick Commands
quick-start: install dev-start ## Quick start for new developers

quick-deploy: backup build deploy ## Quick production deployment with backup

# Environment Setup
setup-dev: ## Setup development environment
	@echo "🛠️ Setting up development environment..."
	@./scripts/dev.sh start
	@echo "✅ Development environment ready!"
	@echo "🌐 Backend: http://localhost:8080"


setup-prod: ## Setup production environment
	@echo "🛠️ Setting up production environment..."
	@./scripts/deploy.sh
	@echo "✅ Production environment ready!"
	@echo "🌐 Backend: http://localhost:8080"
	@echo "📊 Grafana: http://localhost:3000"
	@echo "📈 Prometheus: http://localhost:9090"


# Documentation
docs: ## Generate documentation
	@echo "📚 Generating documentation..."
	@cd backend && go doc -all > ../docs/api.md || echo "Documentation generation requires go doc"

# Version Management
version: ## Show version information
	@echo "📋 Version Information:"
	@echo "Project: Share My Status"
	@echo "Docker: $(shell docker --version)"
	@echo "Docker Compose: $(shell docker-compose --version)"
	@echo "Go: $(shell cd backend && go version)"

# Troubleshooting
debug: ## Show debug information
	@echo "🐛 Debug Information:"
	@echo "=== Docker Info ==="
	@docker info
	@echo ""
	@echo "=== Container Status ==="
	@docker ps -a
	@echo ""
	@echo "=== Network Status ==="
	@docker network ls
	@echo ""
	@echo "=== Volume Status ==="
	@docker volume ls
	@echo ""
	@echo "=== Disk Usage ==="
	@df -h
	@echo ""
	@echo "=== Memory Usage ==="
	@free -h