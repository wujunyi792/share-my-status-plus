#!/bin/bash

# Share My Status - Development Environment Script
# This script sets up and manages the development environment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="share-my-status"
DEV_COMPOSE_FILE="docker-compose.dev.yml"
ENV_FILE=".env.dev"

# Functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Create development environment file
create_dev_env() {
    if [[ ! -f "$ENV_FILE" ]]; then
        log "Creating development environment file..."
        cat > "$ENV_FILE" << 'EOF'
# Share My Status - Development Environment Configuration

# Application Configuration
APP_NAME=share-my-status-dev
APP_VERSION=dev
APP_ENV=development
HTTP_PORT=8080
DEBUG=true
DEFAULT_TIMEZONE=Asia/Shanghai

# Database Configuration
DB_DSN=root:dev_password@tcp(localhost:3306)/share_my_status_dev?charset=utf8mb4&parseTime=True&loc=Local
DB_MAX_IDLE_CONNS=5
DB_MAX_OPEN_CONNS=25
DB_CONN_MAX_LIFETIME=3600

# Redis Configuration
REDIS_URL=redis://localhost:6379/1
REDIS_PASSWORD=
REDIS_DB=1

# Feishu Configuration (Development)
FEISHU_APP_ID=dev_app_id
FEISHU_APP_SECRET=dev_app_secret

# Logging Configuration
LOG_LEVEL=debug
LOG_FORMAT=text

# Security Configuration (Development - Not for production!)
JWT_SECRET=dev_jwt_secret_key_not_for_production
ENCRYPTION_KEY=dev_encryption_key_32_chars_long

# Rate Limiting (Relaxed for development)
RATE_LIMIT_ENABLED=false
RATE_LIMIT_REQUESTS_PER_MINUTE=1000

# Observability Configuration
METRICS_ENABLED=true
TRACING_ENABLED=true
JAEGER_ENDPOINT=http://localhost:14268/api/traces

# MySQL Configuration (for docker-compose)
MYSQL_ROOT_PASSWORD=dev_password
MYSQL_DATABASE=share_my_status_dev
MYSQL_USER=dev_user
MYSQL_PASSWORD=dev_password

# Redis Configuration (for docker-compose)
REDIS_AOF_ENABLED=no
REDIS_MAXMEMORY=128mb
REDIS_MAXMEMORY_POLICY=allkeys-lru

# Development specific
HOT_RELOAD=true
AUTO_MIGRATE=true
SEED_DATA=true
EOF
        success "Development environment file created"
    fi
}

# Create development docker-compose file
create_dev_compose() {
    if [[ ! -f "$DEV_COMPOSE_FILE" ]]; then
        log "Creating development docker-compose file..."
        cat > "$DEV_COMPOSE_FILE" << 'EOF'
version: '3.8'

services:
  mysql-dev:
    image: mysql:8.4.5
    container_name: share-mysql-dev
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    ports:
      - "3306:3306"
    volumes:
      - mysql_dev_data:/var/lib/mysql
    command: --default-authentication-plugin=mysql_native_password
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      timeout: 20s
      retries: 10

  redis-dev:
    image: redis:7.4-alpine
    container_name: share-redis-dev
    restart: unless-stopped
    ports:
      - "6379:6379"
    volumes:
      - redis_dev_data:/data
      - ./docker/redis/redis.conf:/usr/local/etc/redis/redis.conf:ro
    command: redis-server /usr/local/etc/redis/redis.conf
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 10s
      retries: 5

  jaeger-dev:
    image: jaegertracing/all-in-one:1.60
    container_name: share-jaeger-dev
    restart: unless-stopped
    ports:
      - "16686:16686"
      - "14268:14268"
    environment:
      COLLECTOR_OTLP_ENABLED: true

volumes:
  mysql_dev_data:
  redis_dev_data:

networks:
  default:
    name: share-dev-network
EOF
        success "Development docker-compose file created"
    fi
}

# Start development services
start_services() {
    log "Starting development services..."
    
    create_dev_env
    create_dev_compose
    
    # Start infrastructure services
    docker-compose --env-file "$ENV_FILE" -f "$DEV_COMPOSE_FILE" up -d
    
    # Wait for services to be ready
    log "Waiting for services to be ready..."
    sleep 10
    
    # Check if services are healthy
    if docker-compose --env-file "$ENV_FILE" -f "$DEV_COMPOSE_FILE" ps | grep -q "Up (healthy)"; then
        success "Development services started successfully"
    else
        warning "Some services may still be starting up"
    fi
    
    show_dev_status
}

# Stop development services
stop_services() {
    log "Stopping development services..."
    docker-compose --env-file "$ENV_FILE" -f "$DEV_COMPOSE_FILE" down
    success "Development services stopped"
}

# Show development status
show_dev_status() {
    log "Development Environment Status:"
    docker-compose --env-file "$ENV_FILE" -f "$DEV_COMPOSE_FILE" ps
    
    echo ""
    log "Development URLs:"
    echo "  MySQL: localhost:3306 (dev_user/dev_password)"
    echo "  Redis: localhost:6379"
    echo "  Jaeger: http://localhost:16686"
    echo ""
    log "To run the backend locally:"
    echo "  cd backend && go run main.go"
}

# Clean development data
clean_data() {
    log "Cleaning development data..."
    docker-compose --env-file "$ENV_FILE" -f "$DEV_COMPOSE_FILE" down -v
    success "Development data cleaned"
}

# Show logs
show_logs() {
    local service=${1:-""}
    if [[ -n "$service" ]]; then
        docker-compose --env-file "$ENV_FILE" -f "$DEV_COMPOSE_FILE" logs -f "$service"
    else
        docker-compose --env-file "$ENV_FILE" -f "$DEV_COMPOSE_FILE" logs -f
    fi
}

# Run backend locally
run_backend() {
    log "Setting up backend for local development..."
    
    # Check if backend directory exists
    if [[ ! -d "backend" ]]; then
        error "Backend directory not found"
    fi
    
    # Create local .env file for backend
    if [[ ! -f "backend/.env" ]]; then
        log "Creating backend .env file..."
        cp "$ENV_FILE" backend/.env
    fi
    
    # Start infrastructure services if not running
    if ! docker-compose --env-file "$ENV_FILE" -f "$DEV_COMPOSE_FILE" ps | grep -q "Up"; then
        log "Starting infrastructure services..."
        start_services
        sleep 5
    fi
    
    log "Starting backend in development mode..."
    cd backend
    
    # Install dependencies if needed
    if [[ ! -f "go.sum" ]]; then
        log "Installing Go dependencies..."
        go mod tidy
    fi
    
    # Run the backend
    log "Running backend server..."
    echo "Backend will be available at: http://localhost:8080"
    echo "Press Ctrl+C to stop"
    go run main.go
}

# Main function
main() {
    case "${1:-start}" in
        start)
            start_services
            ;;
        stop)
            stop_services
            ;;
        restart)
            stop_services
            sleep 2
            start_services
            ;;
        status)
            show_dev_status
            ;;
        logs)
            show_logs "${2:-}"
            ;;
        clean)
            clean_data
            ;;
        backend)
            run_backend
            ;;
        help|--help|-h)
            echo "Usage: $0 [COMMAND] [OPTIONS]"
            echo ""
            echo "Commands:"
            echo "  start     Start development services (default)"
            echo "  stop      Stop development services"
            echo "  restart   Restart development services"
            echo "  status    Show service status"
            echo "  logs      Show logs (optionally for specific service)"
            echo "  clean     Clean all development data"
            echo "  backend   Run backend locally with hot reload"
            echo "  help      Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 start"
            echo "  $0 logs mysql-dev"
            echo "  $0 backend"
            ;;
        *)
            error "Unknown command: $1. Use '$0 help' for usage information."
            ;;
    esac
}

# Run main function with all arguments
main "$@"