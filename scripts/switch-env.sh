#!/bin/bash

# Script to manually switch traffic between blue and green environments
# Usage: ./scripts/switch-env.sh [blue|green]

set -e

TARGET_ENV=${1:-""}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to switch traffic
switch_traffic() {
    local target_env=$1

    log_info "Switching traffic to $target_env environment..."

    # Update Nginx configuration
    cat > nginx-switch.conf <<EOF
events {
    worker_connections 1024;
}

http {
    upstream app_servers {
        server app-$target_env:3000 max_fails=3 fail_timeout=30s;
        keepalive 32;
    }

    # Include other configurations
    include /etc/nginx/conf.d/*.conf;
}
EOF

    # Backup current config
    docker cp nginx:/etc/nginx/nginx.conf nginx-switch-backup.conf

    # Apply new config
    docker cp nginx-switch.conf nginx:/etc/nginx/nginx.conf

    # Test and reload Nginx
    if docker exec nginx nginx -t; then
        docker exec nginx nginx -s reload
        log_success "Traffic switched to $target_env environment"
        rm -f nginx-switch.conf
    else
        log_error "Nginx configuration test failed"
        # Restore backup
        docker cp nginx-switch-backup.conf nginx:/etc/nginx/nginx.conf
        docker exec nginx nginx -s reload
        exit 1
    fi
}

# Main function
main() {
    if [ -z "$TARGET_ENV" ]; then
        log_error "Please specify target environment: blue or green"
        echo "Usage: $0 [blue|green]"
        exit 1
    fi

    if [ "$TARGET_ENV" != "blue" ] && [ "$TARGET_ENV" != "green" ]; then
        log_error "Invalid environment: $TARGET_ENV"
        echo "Valid options: blue, green"
        exit 1
    fi

    # Check if target environment is running
    if ! docker-compose ps "app-$TARGET_ENV" | grep -q "Up"; then
        log_error "Target environment ($TARGET_ENV) is not running!"
        exit 1
    fi

    # Check health of target environment
    local port=$([ "$TARGET_ENV" = "blue" ] && echo "3001" || echo "3002")
    if ! curl -f -s "http://localhost:$port/health" > /dev/null; then
        log_error "Target environment ($TARGET_ENV) health check failed!"
        exit 1
    fi

    # Confirm switch
    echo
    log_warning "About to switch traffic to $TARGET_ENV environment"
    read -p "Do you want to proceed? (y/N): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        switch_traffic "$TARGET_ENV"

        # Verify
        sleep 5
        if curl -s http://localhost | grep -q "Current Environment: <strong>${TARGET_ENV^^}</strong>"; then
            log_success "✅ Traffic successfully switched to $TARGET_ENV!"
        else
            log_error "❌ Traffic switch verification failed"
            exit 1
        fi
    else
        log_warning "Traffic switch cancelled"
    fi
}

# Check dependencies
command -v docker >/dev/null 2>&1 || { log_error "Docker is required"; exit 1; }
command -v curl >/dev/null 2>&1 || { log_error "curl is required"; exit 1; }

# Run main function
main "$@"