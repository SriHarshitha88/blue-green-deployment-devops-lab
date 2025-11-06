#!/bin/bash

# Blue-Green Rollback Script
# Usage: ./scripts/rollback.sh [target-environment]

set -e

# Configuration
TARGET_ENV=${1:-""}  # If not specified, will detect which one is inactive
BLUE_PORT=3001
GREEN_PORT=3002
HEALTH_CHECK_URL="http://localhost"

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

# Function to get current active environment
get_current_environment() {
    local response=$(curl -s "$HEALTH_CHECK_URL" 2>/dev/null || echo "")

    if echo "$response" | grep -q "Current Environment: <strong>BLUE</strong>"; then
        echo "blue"
    elif echo "$response" | grep -q "Current Environment: <strong>GREEN</strong>"; then
        echo "green"
    else
        echo "blue"  # Default to blue if unable to determine
    fi
}

# Function to switch traffic
switch_traffic() {
    local target_env=$1

    log_info "Switching traffic to $target_env environment..."

    # Update Nginx configuration
    cat > nginx-rollback.conf <<EOF
events {
    worker_connections 1024;
}

http {
    upstream app_servers {
        server app-$target_env:3000 max_fails=3 fail_timeout=30s;
        keepalive 32;
    }

    # Health check for blue environment
    upstream blue_backend {
        server app-blue:3000;
    }

    # Health check for green environment
    upstream green_backend {
        server app-green:3000;
    }

    # Rate limiting
    limit_req_zone \$binary_remote_addr zone=api:10m rate=10r/s;

    # Logging
    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for" '
                    'rt=\$request_time uct="\$upstream_connect_time" '
                    'uht="\$upstream_header_time" urt="\$upstream_response_time"';

    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log warn;

    # Basic settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 16M;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    server {
        listen 80;
        server_name localhost;

        # Header with upstream info
        add_header X-Upstream \$upstream_addr always;
        add_header X-Server-Info \$hostname always;

        # Main application route
        location / {
            limit_req zone=api burst=20 nodelay;

            proxy_pass http://app_servers;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_cache_bypass \$http_upgrade;

            # Timeouts
            proxy_connect_timeout 5s;
            proxy_send_timeout 10s;
            proxy_read_timeout 10s;
        }

        # Health check endpoint for monitoring
        location /nginx-health {
            access_log off;
            return 200 "healthy\\n";
            add_header Content-Type text/plain;
        }

        # Blue environment direct access
        location /blue {
            proxy_pass http://blue_backend;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }

        # Green environment direct access
        location /green {
            proxy_pass http://green_backend;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
    }
}
EOF

    # Backup current config
    docker cp nginx:/etc/nginx/nginx.conf nginx-rollback-backup.conf

    # Apply rollback config
    docker cp nginx-rollback.conf nginx:/etc/nginx/nginx.conf

    # Test and reload Nginx
    if docker exec nginx nginx -t; then
        docker exec nginx nginx -s reload
        log_success "Traffic switched to $target_env environment"
        rm -f nginx-rollback.conf
    else
        log_error "Nginx configuration test failed"
        # Restore backup
        docker cp nginx-rollback-backup.conf nginx:/etc/nginx/nginx.conf
        docker exec nginx nginx -s reload
        exit 1
    fi
}

# Main rollback flow
main() {
    log_info "Starting Blue-Green rollback..."

    # Get current active environment
    CURRENT_ENV=$(get_current_environment)

    # Determine target environment for rollback
    if [ -z "$TARGET_ENV" ]; then
        TARGET_ENV=$([ "$CURRENT_ENV" = "blue" ] && echo "green" || echo "blue")
    fi

    log_info "Current active environment: $CURRENT_ENV"
    log_info "Rolling back to: $TARGET_ENV"

    # Check if target environment is running
    if ! docker-compose ps "app-$TARGET_ENV" | grep -q "Up"; then
        log_error "Target environment ($TARGET_ENV) is not running!"
        log_info "Starting $TARGET_ENV environment..."

        # Start target environment
        COLOR=$TARGET_ENV docker-compose up -d "app-$TARGET_ENV"

        # Wait for container to be ready
        sleep 5

        # Health check
        TARGET_PORT=$([ "$TARGET_ENV" = "blue" ] && echo "$BLUE_PORT" || echo "$GREEN_PORT")

        local counter=0
        local timeout=60
        while [ $counter -lt $timeout ]; do
            if curl -f -s "http://localhost:$TARGET_PORT/health" > /dev/null 2>&1; then
                log_success "Health check passed for $TARGET_ENV environment"
                break
            fi
            counter=$((counter + 1))
            echo -n "."
            sleep 1
        done

        if [ $counter -eq $timeout ]; then
            log_error "Health check failed for $TARGET_ENV environment"
            exit 1
        fi
    fi

    # Confirm rollback
    echo
    log_warning "About to rollback from $CURRENT_ENV to $TARGET_ENV"
    read -p "Do you want to proceed? (y/N): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Switch traffic
        switch_traffic "$TARGET_ENV"

        # Verify traffic switch
        log_info "Verifying rollback..."
        sleep 5

        if curl -s "$HEALTH_CHECK_URL" | grep -q "Current Environment: <strong>${TARGET_ENV^^}</strong>"; then
            log_success "✅ Rollback completed successfully!"
            log_success "✅ Traffic is now routed to $TARGET_ENV environment"

            # Stop the previous environment (optional)
            log_warning "Do you want to stop the previous environment ($CURRENT_ENV)? (y/N)"
            read -p "" -n 1 -r
            echo

            if [[ $REPLY =~ ^[Yy]$ ]]; then
                docker-compose stop "app-$CURRENT_ENV"
                log_info "Stopped $CURRENT_ENV environment"
            fi

            # Clean up
            log_info "Cleaning up..."
            rm -f nginx-rollback-backup.conf

            echo
            log_info "=== Rollback Summary ==="
            log_info "Previous environment: $CURRENT_ENV"
            log_info "Active environment: $TARGET_ENV"
            log_info "Access application at: http://localhost"
            log_info "Direct access to $TARGET_ENV: http://localhost/$TARGET_ENV"

        else
            log_error "Rollback verification failed"
            log_warning "Restoring original configuration..."

            # Restore backup and reload
            docker cp nginx-rollback-backup.conf nginx:/etc/nginx/nginx.conf
            docker exec nginx nginx -s reload

            log_error "Rollback failed - original configuration restored"
            exit 1
        fi
    else
        log_warning "Rollback cancelled by user"
        exit 0
    fi
}

# Check dependencies
command -v docker >/dev/null 2>&1 || { log_error "Docker is required but not installed"; exit 1; }
command -v docker-compose >/dev/null 2>&1 || { log_error "Docker Compose is required but not installed"; exit 1; }
command -v curl >/dev/null 2>&1 || { log_error "curl is required but not installed"; exit 1; }

# Check if docker is running
if ! docker info >/dev/null 2>&1; then
    log_error "Docker is not running"
    exit 1
fi

# Run main function
main "$@"