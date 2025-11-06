#!/bin/bash

# Health Check Script for Blue-Green Deployment
# Usage: ./scripts/health-check.sh [environment]

set -e

# Configuration
ENVIRONMENT=${1:-"all"}  # Can be 'blue', 'green', or 'all'
BLUE_PORT=3001
GREEN_PORT=3002
MAIN_URL="http://localhost"

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
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Function to check health of a specific endpoint
check_endpoint() {
    local url=$1
    local name=$2
    local expected_content=$3

    echo -n "Checking $name... "

    if response=$(curl -s -f "$url" 2>/dev/null); then
        if [ -n "$expected_content" ]; then
            if echo "$response" | grep -q "$expected_content"; then
                log_success "OK"
                return 0
            else
                log_error "Content mismatch"
                echo "  Expected: $expected_content"
                echo "  Got: $(echo "$response" | head -c 100)..."
                return 1
            fi
        else
            log_success "OK"
            return 0
        fi
    else
        log_error "Failed"
        return 1
    fi
}

# Function to check container status
check_container() {
    local container=$1
    local port=$2

    echo -n "Checking container $container... "

    if docker-compose ps "$container" | grep -q "Up"; then
        log_success "Running"
        return 0
    else
        log_error "Not running"
        return 1
    fi
}

# Function to check detailed health
detailed_health_check() {
    local env=$1
    local port=$2
    local color=${3:-$env}

    echo
    log_info "=== $env Environment Health Check ==="

    # Check container
    if ! check_container "app-$env" "$port"; then
        return 1
    fi

    # Check health endpoint
    echo
    if check_endpoint "http://localhost:$port/health" "Health endpoint"; then
        response=$(curl -s "http://localhost:$port/health")
        echo "  Status: $(echo "$response" | grep -o '"status":"[^"]*"')"
        echo "  Version: $(echo "$response" | grep -o '"version":"[^"]*"')"
        echo "  Color: $(echo "$response" | grep -o '"color":"[^"]*"')"
        echo "  Uptime: $(echo "$response" | grep -o '"uptime":[^,]*')"
    fi

    # Check info endpoint
    echo
    if check_endpoint "http://localhost:$port/info" "Info endpoint" "\"environment\":\"$color\""; then
        response=$(curl -s "http://localhost:$port/info")
        echo "  Environment: $(echo "$response" | grep -o '"environment":"[^"]*"')"
        echo "  Hostname: $(echo "$response" | grep -o '"hostname":"[^"]*"')"
    fi

    # Check main endpoint
    echo
    check_endpoint "http://localhost:$port/" "Main endpoint"

    # Check ready endpoint
    echo
    check_endpoint "http://localhost:$port/ready" "Ready endpoint"
}

# Function to check active environment
check_active_environment() {
    echo
    log_info "=== Active Environment Check ==="

    if check_endpoint "$MAIN_URL" "Main application"; then
        response=$(curl -s "$MAIN_URL")

        if echo "$response" | grep -q "Current Environment: <strong>BLUE</strong>"; then
            log_success "Active environment: BLUE"
            echo "  URL: $MAIN_URL/blue (direct access)"
            echo "  URL: $MAIN_URL/green (direct access)"
        elif echo "$response" | grep -q "Current Environment: <strong>GREEN</strong>"; then
            log_success "Active environment: GREEN"
            echo "  URL: $MAIN_URL/blue (direct access)"
            echo "  URL: $MAIN_URL/green (direct access)"
        else
            log_warning "Could not determine active environment"
        fi

        # Check response headers
        echo
        echo "Response Headers:"
        curl -s -I "$MAIN_URL" | grep -E "^(X-Upstream|X-Server-Info)" || echo "  No custom headers found"
    fi
}

# Function to check Nginx status
check_nginx() {
    echo
    log_info "=== Nginx Health Check ==="

    # Check Nginx container
    if check_container "nginx" "80"; then
        # Check Nginx health endpoint
        check_endpoint "$MAIN_URL/nginx-health" "Nginx health endpoint"

        # Check configuration
        echo
        echo -n "Checking Nginx configuration... "
        if docker exec nginx nginx -t 2>/dev/null; then
            log_success "Valid"
        else
            log_error "Invalid"
        fi

        # Check upstream servers
        echo
        echo "Upstream configuration:"
        docker exec nginx nginx -T 2>/dev/null | grep -A 5 "upstream app_servers" || echo "  Not found"
    fi
}

# Function to show system status
show_system_status() {
    echo
    log_info "=== System Status ==="

    echo "Docker containers:"
    docker-compose ps

    echo
    echo "Network connections:"
    docker network ls | grep blue-green || echo "  No blue-green networks found"

    echo
    echo "Disk usage:"
    docker system df
}

# Main function
main() {
    log_info "Blue-Green Deployment Health Check"
    log_info "=================================="

    case $ENVIRONMENT in
        "blue")
            detailed_health_check "blue" "$BLUE_PORT" "BLUE"
            ;;
        "green")
            detailed_health_check "green" "$GREEN_PORT" "GREEN"
            ;;
        "all"|*)
            detailed_health_check "blue" "$BLUE_PORT" "BLUE"
            detailed_health_check "green" "$GREEN_PORT" "GREEN"
            ;;
    esac

    check_active_environment
    check_nginx
    show_system_status

    echo
    log_info "Health check completed at $(date)"
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