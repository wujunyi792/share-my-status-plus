#!/bin/bash

# Share My Status - Production Start Script
# This script starts the application in production mode

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="share-my-status"
ENV_FILE=".env.docker"
COMPOSE_FILE="docker-compose.yml"
LOG_FILE="./logs/start.log"

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

# Check if environment is ready
check_environment() {
    log "Checking production environment..."
    
    # Check if Docker is running
    if ! docker info &> /dev/null; then
        error "Docker is not running. Please start Docker first."
    fi
    
    # Check if environment file exists
    if [[ ! -f "$ENV_FILE" ]]; then
        error "Environment file $ENV_FILE not found. Please create it first."
    fi
    
    # Check if compose file exists
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        error "Docker compose file $COMPOSE_FILE not found."
    fi
    
    # Create logs directory
    mkdir -p logs
    
    success "Environment check passed"
}

# Pre-flight checks
preflight_checks() {
    log "Running pre-flight checks..."
    
    # Check disk space
    local available_space=$(df -h . | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ ${available_space%.*} -lt 5 ]]; then
        warning "Low disk space: ${available_space}G available. Consider cleaning up."
    fi
    
    # Check memory
    local available_memory=$(free -g | awk 'NR==2{printf "%.1f", $7}')
    if [[ ${available_memory%.*} -lt 2 ]]; then
        warning "Low memory: ${available_memory}G available. Monitor resource usage."
    fi
    
    # Check if ports are available
    local ports=(3306 6379 8080 3000 9090 16686)
    for port in "${ports[@]}"; do
        if lsof -i :$port &> /dev/null; then
            warning "Port $port is already in use"
        fi
    done
    
    success "Pre-flight checks completed"
}

# Start services
start_services() {
    log "Starting production services..."
    
    # Pull latest images
    log "Pulling latest images..."
    docker-compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" pull --quiet
    
    # Start services in detached mode
    log "Starting services..."
    docker-compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d
    
    success "Services started successfully"
}

# Wait for services to be ready
wait_for_services() {
    log "Waiting for services to be ready..."
    
    local max_attempts=60
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        local ready_count=0
        local total_services=0
        
        # Check MySQL
        if docker-compose --env-file "$ENV_FILE" exec -T mysql mysqladmin ping -h localhost --silent 2>/dev/null; then
            ((ready_count++))
        fi
        ((total_services++))
        
        # Check Redis
        if docker-compose --env-file "$ENV_FILE" exec -T redis redis-cli ping 2>/dev/null | grep -q PONG; then
            ((ready_count++))
        fi
        ((total_services++))
        
        # Check Backend
        if curl -f http://localhost:8080/health &>/dev/null; then
            ((ready_count++))
        fi
        ((total_services++))
        
        # Check if all critical services are ready
        if [[ $ready_count -eq $total_services ]]; then
            success "All services are ready"
            return 0
        fi
        
        log "Services ready: $ready_count/$total_services (attempt $((attempt+1))/$max_attempts)"
        sleep 5
        ((attempt++))
    done
    
    warning "Some services may not be fully ready yet. Check logs for details."
}

# Show service status
show_status() {
    log "Production Service Status:"
    docker-compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" ps
    
    echo ""
    log "Service Health:"
    
    # Check each service health
    local services=("mysql" "redis" "share-backend" "prometheus" "grafana")
    for service in "${services[@]}"; do
        local status=$(docker-compose --env-file "$ENV_FILE" ps -q "$service" 2>/dev/null)
        if [[ -n "$status" ]]; then
            local health=$(docker inspect --format='{{.State.Health.Status}}' "$status" 2>/dev/null || echo "unknown")
            if [[ "$health" == "healthy" ]]; then
                echo -e "  ${GREEN}✓${NC} $service: healthy"
            elif [[ "$health" == "unhealthy" ]]; then
                echo -e "  ${RED}✗${NC} $service: unhealthy"
            else
                echo -e "  ${YELLOW}?${NC} $service: $health"
            fi
        else
            echo -e "  ${RED}✗${NC} $service: not running"
        fi
    done
    
    echo ""
    log "Access URLs:"
    echo "  🌐 Backend API: http://localhost:8080"
    echo "  📊 Grafana: http://localhost:3000"
    echo "  📈 Prometheus: http://localhost:9090"

    echo ""
    log "Useful Commands:"
    echo "  📋 View logs: docker-compose --env-file $ENV_FILE logs -f [service]"
    echo "  🔄 Restart: docker-compose --env-file $ENV_FILE restart [service]"
    echo "  🛑 Stop: docker-compose --env-file $ENV_FILE down"
    echo "  📊 Stats: docker stats"
}

# Monitor services
monitor_services() {
    log "Starting service monitoring..."
    
    while true; do
        clear
        echo "=== Share My Status - Production Monitor ==="
        echo "Press Ctrl+C to exit"
        echo ""
        
        # Show container stats
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
        
        echo ""
        echo "=== Service Health ==="
        
        # Quick health check
        local services=("mysql" "redis" "share-backend")
        for service in "${services[@]}"; do
            local container_id=$(docker-compose --env-file "$ENV_FILE" ps -q "$service" 2>/dev/null)
            if [[ -n "$container_id" ]]; then
                local status=$(docker inspect --format='{{.State.Status}}' "$container_id" 2>/dev/null)
                if [[ "$status" == "running" ]]; then
                    echo -e "${GREEN}✓${NC} $service: running"
                else
                    echo -e "${RED}✗${NC} $service: $status"
                fi
            else
                echo -e "${RED}✗${NC} $service: not found"
            fi
        done
        
        sleep 10
    done
}

# Main function
main() {
    case "${1:-start}" in
        start)
            log "Starting $PROJECT_NAME in production mode..."
            check_environment
            preflight_checks
            start_services
            wait_for_services
            show_status
            success "Production startup completed!"
            ;;
        status)
            show_status
            ;;
        monitor)
            monitor_services
            ;;
        stop)
            log "Stopping production services..."
            docker-compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" down
            success "Production services stopped"
            ;;
        restart)
            log "Restarting production services..."
            docker-compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" restart
            wait_for_services
            show_status
            success "Production services restarted"
            ;;
        logs)
            local service="${2:-}"
            if [[ -n "$service" ]]; then
                docker-compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" logs -f "$service"
            else
                docker-compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" logs -f
            fi
            ;;
        update)
            log "Updating production deployment..."
            docker-compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" pull
            docker-compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d
            wait_for_services
            show_status
            success "Production deployment updated"
            ;;
        help|--help|-h)
            echo "Usage: $0 [COMMAND] [OPTIONS]"
            echo ""
            echo "Commands:"
            echo "  start     Start production services (default)"
            echo "  stop      Stop production services"
            echo "  restart   Restart production services"
            echo "  status    Show service status"
            echo "  monitor   Monitor services in real-time"
            echo "  logs      Show logs (optionally for specific service)"
            echo "  update    Update and restart services"
            echo "  help      Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 start"
            echo "  $0 status"
            echo "  $0 logs share-backend"
            echo "  $0 monitor"
            ;;
        *)
            error "Unknown command: $1. Use '$0 help' for usage information."
            ;;
    esac
}

# Handle Ctrl+C gracefully
trap 'echo -e "\n${YELLOW}Interrupted by user${NC}"; exit 0' INT

# Run main function with all arguments
main "$@"