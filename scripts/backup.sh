#!/bin/bash

# Share My Status - Backup Script
# This script handles backup and restore operations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="share-my-status"
BACKUP_DIR="./backups"
ENV_FILE=".env.docker"
COMPOSE_FILE="docker-compose.yml"

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

# Create backup
create_backup() {
    local backup_name="${1:-$(date +%Y%m%d_%H%M%S)}"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    log "Creating backup: $backup_name"
    
    # Create backup directory
    mkdir -p "$backup_path"
    
    # Backup MySQL data
    if docker-compose --env-file "$ENV_FILE" ps mysql | grep -q "Up"; then
        log "Backing up MySQL database..."
        docker-compose --env-file "$ENV_FILE" exec -T mysql mysqldump \
            --single-transaction \
            --routines \
            --triggers \
            --all-databases \
            -u root -p"${MYSQL_ROOT_PASSWORD:-root_password_change_me}" \
            > "$backup_path/mysql_dump.sql"
        
        # Also backup data directory
        if [[ -d "data/mysql" ]]; then
            tar -czf "$backup_path/mysql_data.tar.gz" -C data mysql/
        fi
        
        success "MySQL backup completed"
    else
        warning "MySQL container is not running, skipping database backup"
    fi
    
    # Backup Redis data
    if docker-compose --env-file "$ENV_FILE" ps redis | grep -q "Up"; then
        log "Backing up Redis data..."
        docker-compose --env-file "$ENV_FILE" exec -T redis redis-cli BGSAVE
        sleep 5  # Wait for background save to complete
        
        if [[ -d "data/redis" ]]; then
            tar -czf "$backup_path/redis_data.tar.gz" -C data redis/
        fi
        
        success "Redis backup completed"
    else
        warning "Redis container is not running, skipping Redis backup"
    fi
    
    # Backup Grafana data
    if [[ -d "data/grafana" ]]; then
        log "Backing up Grafana data..."
        tar -czf "$backup_path/grafana_data.tar.gz" -C data grafana/
        success "Grafana backup completed"
    fi
    
    # Backup Prometheus data
    if [[ -d "data/prometheus" ]]; then
        log "Backing up Prometheus data..."
        tar -czf "$backup_path/prometheus_data.tar.gz" -C data prometheus/
        success "Prometheus backup completed"
    fi
    
    # Backup Loki data
    if [[ -d "data/loki" ]]; then
        log "Backing up Loki data..."
        tar -czf "$backup_path/loki_data.tar.gz" -C data loki/
        success "Loki backup completed"
    fi
    
    # Backup configuration files
    log "Backing up configuration files..."
    mkdir -p "$backup_path/config"
    cp -r docker/ "$backup_path/config/" 2>/dev/null || true
    cp "$ENV_FILE" "$backup_path/config/" 2>/dev/null || true
    cp "$COMPOSE_FILE" "$backup_path/config/" 2>/dev/null || true
    
    # Create backup metadata
    cat > "$backup_path/backup_info.txt" << EOF
Backup Information
==================
Backup Name: $backup_name
Created: $(date)
Project: $PROJECT_NAME
Backup Type: Full
Services Backed Up:
$(docker-compose --env-file "$ENV_FILE" ps --services 2>/dev/null || echo "No services running")

Files Included:
$(ls -la "$backup_path")
EOF
    
    success "Backup created successfully at: $backup_path"
    
    # Calculate backup size
    local backup_size=$(du -sh "$backup_path" | cut -f1)
    log "Backup size: $backup_size"
}

# Restore backup
restore_backup() {
    local backup_name="$1"
    
    if [[ -z "$backup_name" ]]; then
        error "Please specify a backup name to restore"
    fi
    
    local backup_path="$BACKUP_DIR/$backup_name"
    
    if [[ ! -d "$backup_path" ]]; then
        error "Backup not found: $backup_path"
    fi
    
    log "Restoring backup: $backup_name"
    
    # Confirm restoration
    echo -e "${YELLOW}WARNING: This will overwrite current data!${NC}"
    read -p "Are you sure you want to restore? (yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then
        log "Restore cancelled"
        exit 0
    fi
    
    # Stop services
    log "Stopping services..."
    docker-compose --env-file "$ENV_FILE" down
    
    # Restore MySQL data
    if [[ -f "$backup_path/mysql_dump.sql" ]]; then
        log "Restoring MySQL database..."
        
        # Start only MySQL for restoration
        docker-compose --env-file "$ENV_FILE" up -d mysql
        sleep 30  # Wait for MySQL to be ready
        
        # Restore database
        docker-compose --env-file "$ENV_FILE" exec -T mysql mysql \
            -u root -p"${MYSQL_ROOT_PASSWORD:-root_password_change_me}" \
            < "$backup_path/mysql_dump.sql"
        
        success "MySQL database restored"
    fi
    
    # Restore data directories
    if [[ -f "$backup_path/mysql_data.tar.gz" ]]; then
        log "Restoring MySQL data directory..."
        rm -rf data/mysql
        tar -xzf "$backup_path/mysql_data.tar.gz" -C data/
    fi
    
    if [[ -f "$backup_path/redis_data.tar.gz" ]]; then
        log "Restoring Redis data..."
        rm -rf data/redis
        tar -xzf "$backup_path/redis_data.tar.gz" -C data/
    fi
    
    if [[ -f "$backup_path/grafana_data.tar.gz" ]]; then
        log "Restoring Grafana data..."
        rm -rf data/grafana
        tar -xzf "$backup_path/grafana_data.tar.gz" -C data/
    fi
    
    if [[ -f "$backup_path/prometheus_data.tar.gz" ]]; then
        log "Restoring Prometheus data..."
        rm -rf data/prometheus
        tar -xzf "$backup_path/prometheus_data.tar.gz" -C data/
    fi
    
    if [[ -f "$backup_path/loki_data.tar.gz" ]]; then
        log "Restoring Loki data..."
        rm -rf data/loki
        tar -xzf "$backup_path/loki_data.tar.gz" -C data/
    fi
    
    # Restore configuration files
    if [[ -d "$backup_path/config" ]]; then
        log "Restoring configuration files..."
        cp -r "$backup_path/config/docker" ./ 2>/dev/null || true
        cp "$backup_path/config/$ENV_FILE" ./ 2>/dev/null || true
        cp "$backup_path/config/$COMPOSE_FILE" ./ 2>/dev/null || true
    fi
    
    # Set proper permissions
    sudo chown -R 999:999 data/mysql 2>/dev/null || true
    sudo chown -R 999:999 data/redis 2>/dev/null || true
    sudo chown -R 472:472 data/grafana 2>/dev/null || true
    sudo chown -R 10001:10001 data/loki 2>/dev/null || true
    
    success "Backup restored successfully"
    
    log "Starting services..."
    docker-compose --env-file "$ENV_FILE" up -d
}

# List backups
list_backups() {
    log "Available backups:"
    
    if [[ ! -d "$BACKUP_DIR" ]] || [[ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]]; then
        warning "No backups found"
        return
    fi
    
    echo ""
    printf "%-20s %-15s %-10s %s\n" "NAME" "DATE" "SIZE" "DESCRIPTION"
    echo "------------------------------------------------------------"
    
    for backup in "$BACKUP_DIR"/*; do
        if [[ -d "$backup" ]]; then
            local name=$(basename "$backup")
            local size=$(du -sh "$backup" 2>/dev/null | cut -f1)
            local date=""
            local desc=""
            
            if [[ -f "$backup/backup_info.txt" ]]; then
                date=$(grep "Created:" "$backup/backup_info.txt" | cut -d: -f2- | xargs)
                desc=$(grep "Backup Type:" "$backup/backup_info.txt" | cut -d: -f2 | xargs)
            fi
            
            printf "%-20s %-15s %-10s %s\n" "$name" "${date:0:15}" "$size" "$desc"
        fi
    done
}

# Clean old backups
clean_backups() {
    local days="${1:-7}"
    
    log "Cleaning backups older than $days days..."
    
    if [[ ! -d "$BACKUP_DIR" ]]; then
        warning "Backup directory does not exist"
        return
    fi
    
    local count=0
    while IFS= read -r -d '' backup; do
        rm -rf "$backup"
        ((count++))
        log "Removed: $(basename "$backup")"
    done < <(find "$BACKUP_DIR" -maxdepth 1 -type d -mtime +$days -print0 2>/dev/null)
    
    if [[ $count -eq 0 ]]; then
        log "No old backups to clean"
    else
        success "Cleaned $count old backups"
    fi
}

# Verify backup
verify_backup() {
    local backup_name="$1"
    
    if [[ -z "$backup_name" ]]; then
        error "Please specify a backup name to verify"
    fi
    
    local backup_path="$BACKUP_DIR/$backup_name"
    
    if [[ ! -d "$backup_path" ]]; then
        error "Backup not found: $backup_path"
    fi
    
    log "Verifying backup: $backup_name"
    
    # Check backup info
    if [[ -f "$backup_path/backup_info.txt" ]]; then
        log "Backup information:"
        cat "$backup_path/backup_info.txt"
        echo ""
    fi
    
    # Verify file integrity
    local errors=0
    
    for file in "$backup_path"/*.tar.gz; do
        if [[ -f "$file" ]]; then
            if tar -tzf "$file" >/dev/null 2>&1; then
                success "$(basename "$file") - OK"
            else
                error "$(basename "$file") - CORRUPTED"
                ((errors++))
            fi
        fi
    done
    
    if [[ -f "$backup_path/mysql_dump.sql" ]]; then
        if head -n 10 "$backup_path/mysql_dump.sql" | grep -q "MySQL dump"; then
            success "mysql_dump.sql - OK"
        else
            error "mysql_dump.sql - INVALID"
            ((errors++))
        fi
    fi
    
    if [[ $errors -eq 0 ]]; then
        success "Backup verification completed - All files are valid"
    else
        error "Backup verification failed - $errors errors found"
    fi
}

# Main function
main() {
    # Create backup directory if it doesn't exist
    mkdir -p "$BACKUP_DIR"
    
    case "${1:-help}" in
        create)
            create_backup "${2:-}"
            ;;
        restore)
            restore_backup "$2"
            ;;
        list)
            list_backups
            ;;
        clean)
            clean_backups "${2:-7}"
            ;;
        verify)
            verify_backup "$2"
            ;;
        help|--help|-h)
            echo "Usage: $0 [COMMAND] [OPTIONS]"
            echo ""
            echo "Commands:"
            echo "  create [name]     Create a new backup (optional custom name)"
            echo "  restore <name>    Restore from backup"
            echo "  list              List all available backups"
            echo "  clean [days]      Clean backups older than N days (default: 7)"
            echo "  verify <name>     Verify backup integrity"
            echo "  help              Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 create"
            echo "  $0 create before_upgrade"
            echo "  $0 restore 20240101_120000"
            echo "  $0 list"
            echo "  $0 clean 30"
            echo "  $0 verify 20240101_120000"
            ;;
        *)
            error "Unknown command: $1. Use '$0 help' for usage information."
            ;;
    esac
}

# Run main function with all arguments
main "$@"