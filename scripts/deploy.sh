#!/bin/bash

# Blue-Green Deployment Script
# Usage: ./scripts/deploy.sh <image-tag> [environment]

set -e

# Configuration
IMAGE_TAG=${1:-"latest"}
ENVIRONMENT=${2:-"production"}
BLUE_PORT=3001
GREEN_PORT=3002
HEALTH_CHECK_URL="http://localhost"
HEALTH_TIMEOUT=60

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

# Function to check if environment is healthy
check_health() {
    local port=$1
    local timeout=$2
    local counter=0

    log_info "Checking health on port $port..."

    while [ $counter -lt $timeout ]; do
        if curl -f -s "http://localhost:$port/health" > /dev/null 2>&1; then
            log_success "Health check passed on port $port"
            return 0
        fi

        counter=$((counter + 1))
        echo -n "."
        sleep 1
    done

    log_error "Health check failed on port $port after $timeout seconds"
    return 1
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
    cat > nginx-new.conf <<EOF
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
    docker cp nginx:/etc/nginx/nginx.conf nginx-backup.conf

    # Apply new config
    docker cp nginx-new.conf nginx:/etc/nginx/nginx.conf

    # Test and reload Nginx
    if docker exec nginx nginx -t; then
        docker exec nginx nginx -s reload
        log_success "Traffic switched to $target_env environment"
        rm -f nginx-new.conf
    else
        log_error "Nginx configuration test failed"
        # Restore backup
        docker cp nginx-backup.conf nginx:/etc/nginx/nginx.conf
        docker exec nginx nginx -s reload
        exit 1
    fi
}

# Main deployment flow
main() {
    log_info "Starting Blue-Green deployment..."
    log_info "Image tag: $IMAGE_TAG"
    log_info "Environment: $ENVIRONMENT"

    # Get current active environment
    CURRENT_ENV=$(get_current_environment)
    TARGET_ENV=$([ "$CURRENT_ENV" = "blue" ] && echo "green" || echo "blue")

    log_info "Current active environment: $CURRENT_ENV"
    log_info "Target environment: $TARGET_ENV"

    # Pull the new image
    log_info "Pulling image: $IMAGE_TAG"
    docker pull "$IMAGE_TAG"

    # Update docker-compose with new image
    sed -i.bak "s|image: .*|image: $IMAGE_TAG|" docker-compose.yml

    # Deploy to target environment
    log_info "Deploying to $TARGET_ENV environment..."

    # Stop target environment if running
    docker-compose stop "app-$TARGET_ENV" || true

    # Start target environment with new image
    COLOR=$TARGET_ENV VERSION=${IMAGE_TAG##*:} docker-compose up -d "app-$TARGET_ENV"

    # Wait for container to start
    sleep 5

    # Health check
    TARGET_PORT=$([ "$TARGET_ENV" = "blue" ] && echo "$BLUE_PORT" || echo "$GREEN_PORT")

    if ! check_health "$TARGET_PORT" "$HEALTH_TIMEOUT"; then
        log_error "Deployment failed - health check did not pass"
        docker-compose stop "app-$TARGET_ENV"
        exit 1
    fi

    # Run smoke tests
    log_info "Running smoke tests..."

    # Test health endpoint
    if curl -f -s "http://localhost:$TARGET_PORT/health" > /dev/null; then
        log_success "Health endpoint test passed"
    else
        log_error "Health endpoint test failed"
        exit 1
    fi

    # Test info endpoint
    if curl -f -s "http://localhost:$TARGET_PORT/info" | grep -q "$TARGET_ENV"; then
        log_success "Info endpoint test passed"
    else
        log_error "Info endpoint test failed"
        exit 1
    fi

    # Confirm traffic switch
    echo
    log_warning "Ready to switch traffic from $CURRENT_ENV to $TARGET_ENV"
    read -p "Do you want to proceed? (y/N): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Switch traffic
        switch_traffic "$TARGET_ENV"

        # Verify traffic switch
        log_info "Verifying traffic switch..."
        sleep 5

        if curl -s "$HEALTH_CHECK_URL" | grep -q "Current Environment: <strong>${TARGET_ENV^^}</strong>"; then
            log_success "✅ Deployment completed successfully!"
            log_success "✅ Traffic is now routed to $TARGET_ENV environment"
            log_info "Previous environment ($CURRENT_ENV) is kept running for immediate rollback if needed"

            # Clean up
            log_info "Cleaning up..."
            rm -f nginx-backup.conf nginx-new.conf
            docker image prune -f

            echo
            log_info "=== Deployment Summary ==="
            log_info "Deployed image: $IMAGE_TAG"
            log_info "Active environment: $TARGET_ENV"
            log_info "Previous environment: $CURRENT_ENV (kept running)"
            log_info "Access application at: http://localhost"
            log_info "Direct access to $TARGET_ENV: http://localhost/$TARGET_ENV"

        else
            log_error "Traffic switch verification failed"
            log_warning "Rolling back to $CURRENT_ENV..."

            # Restore backup and reload
            docker cp nginx-backup.conf nginx:/etc/nginx/nginx.conf
            docker exec nginx nginx -s reload

            # Stop failed deployment
            docker-compose stop "app-$TARGET_ENV"

            log_error "Deployment rolled back"
            exit 1
        fi
    else
        log_warning "Traffic switch cancelled by user"
        log_info "New version is deployed but not activated"
        log_info "Target environment ($TARGET_ENV) is kept running for manual testing"
        log_info "Direct access at: http://localhost:$TARGET_PORT"
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

# Check if docker-compose services are running
if ! docker-compose ps | grep -q "Up"; then
    log_info "Starting docker-compose services..."
    docker-compose up -d
    sleep 10
fi

# Run main function
main "$@"