#!/bin/bash

# Share My Status - Deployment Script
# This script handles the deployment of the Share My Status application

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="share-my-status"
DOCKER_COMPOSE_FILE="docker-compose.yml"
ENV_FILE=".env.docker"
BACKUP_DIR="./backups"
LOG_FILE="./logs/deploy.log"

# Functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if Docker is installed and running
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed. Please install Docker first."
    fi
    
    if ! docker info &> /dev/null; then
        error "Docker is not running. Please start Docker first."
    fi
    
    # Check if Docker Compose is available
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        error "Docker Compose is not available. Please install Docker Compose."
    fi
    
    # Check if environment file exists
    if [[ ! -f "$ENV_FILE" ]]; then
        warning "Environment file $ENV_FILE not found. Creating from template..."
        if [[ -f ".env.example" ]]; then
            cp .env.example "$ENV_FILE"
            warning "Please edit $ENV_FILE with your configuration before running again."
            exit 1
        else
            error "No environment template found. Please create $ENV_FILE manually."
        fi
    fi
    
    success "Prerequisites check passed"
}

# Create necessary directories
create_directories() {
    log "Creating necessary directories..."
    
    mkdir -p logs
    mkdir -p data/{mysql,redis}
    mkdir -p "$BACKUP_DIR"
    
    # Set proper permissions for data directories
    sudo chown -R 999:999 data/mysql 2>/dev/null || true
    sudo chown -R 999:999 data/redis 2>/dev/null || true

    
    success "Directories created successfully"
}

# Build application
build_application() {
    log "Building application..."
    
    if [[ -f "backend/Dockerfile" ]]; then
        docker build -t "${PROJECT_NAME}-backend:latest" ./backend/
        success "Backend built successfully"
    else
        error "Backend Dockerfile not found"
    fi
}

# Backup existing data
backup_data() {
    if [[ "$1" == "--skip-backup" ]]; then
        log "Skipping backup as requested"
        return
    fi
    
    log "Creating backup..."
    
    BACKUP_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_PATH="$BACKUP_DIR/backup_$BACKUP_TIMESTAMP"
    
    mkdir -p "$BACKUP_PATH"
    
    # Backup MySQL data if exists
    if [[ -d "data/mysql" ]] && [[ "$(ls -A data/mysql)" ]]; then
        log "Backing up MySQL data..."
        tar -czf "$BACKUP_PATH/mysql_data.tar.gz" -C data mysql/
    fi
    
    # Backup Redis data if exists
    if [[ -d "data/redis" ]] && [[ "$(ls -A data/redis)" ]]; then
        log "Backing up Redis data..."
        tar -czf "$BACKUP_PATH/redis_data.tar.gz" -C data redis/
    fi
    
    success "Backup created at $BACKUP_PATH"
}

# Deploy services
deploy_services() {
    log "Deploying services..."
    
    # Pull latest images
    log "Pulling latest images..."
    docker-compose --env-file "$ENV_FILE" -f "$DOCKER_COMPOSE_FILE" pull
    
    # Start services
    log "Starting services..."
    docker-compose --env-file "$ENV_FILE" -f "$DOCKER_COMPOSE_FILE" up -d
    
    success "Services deployed successfully"
}

# Health check
health_check() {
    log "Performing health checks..."
    
    # Wait for services to start
    sleep 30
    
    # Check MySQL
    log "Checking MySQL..."
    if docker-compose --env-file "$ENV_FILE" exec -T mysql mysqladmin ping -h localhost --silent; then
        success "MySQL is healthy"
    else
        error "MySQL health check failed"
    fi
    
    # Check Redis
    log "Checking Redis..."
    if docker-compose --env-file "$ENV_FILE" exec -T redis redis-cli ping | grep -q PONG; then
        success "Redis is healthy"
    else
        error "Redis health check failed"
    fi
    
    # Check Backend
    log "Checking Backend..."
    if curl -f http://localhost:8080/health &>/dev/null; then
        success "Backend is healthy"
    else
        warning "Backend health check failed - it may still be starting up"
    fi
}

# Show service status
show_status() {
    log "Service Status:"
    docker-compose --env-file "$ENV_FILE" -f "$DOCKER_COMPOSE_FILE" ps
    
    echo ""
    log "Access URLs:"
    echo "  Backend API: http://localhost:8080"

}

# Cleanup old backups
cleanup_backups() {
    log "Cleaning up old backups..."
    find "$BACKUP_DIR" -name "backup_*" -type d -mtime +7 -exec rm -rf {} + 2>/dev/null || true
    success "Old backups cleaned up"
}

# Main deployment function
deploy() {
    local skip_backup=false
    local skip_build=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-backup)
                skip_backup=true
                shift
                ;;
            --skip-build)
                skip_build=true
                shift
                ;;
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  --skip-backup    Skip data backup"
                echo "  --skip-build     Skip application build"
                echo "  --help          Show this help message"
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                ;;
        esac
    done
    
    log "Starting deployment of $PROJECT_NAME..."
    
    check_prerequisites
    create_directories
    
    if [[ "$skip_backup" == false ]]; then
        backup_data
    else
        backup_data --skip-backup
    fi
    
    if [[ "$skip_build" == false ]]; then
        build_application
    fi
    
    deploy_services
    health_check
    show_status
    cleanup_backups
    
    success "Deployment completed successfully!"
    log "Check the logs with: docker-compose --env-file $ENV_FILE logs -f"
}

# Run deployment
deploy "$@"