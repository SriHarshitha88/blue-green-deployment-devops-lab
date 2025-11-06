#!/bin/bash

# Setup Script for Blue-Green Deployment
# This script sets up the environment for blue-green deployment

set -e

# Configuration
PROJECT_NAME="blue-green-deployment"
DOCKER_COMPOSE_FILE="docker-compose.yml"
NGINX_CONFIG="nginx.conf"

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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check Docker installation
check_docker() {
    log_info "Checking Docker installation..."

    if command_exists docker; then
        log_success "Docker is installed"
        docker --version
    else
        log_error "Docker is not installed"
        log_info "Please install Docker from: https://docs.docker.com/get-docker/"
        exit 1
    fi

    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker is not running"
        log_info "Please start Docker"
        exit 1
    fi
}

# Function to check Docker Compose installation
check_docker_compose() {
    log_info "Checking Docker Compose installation..."

    if command_exists docker-compose; then
        log_success "Docker Compose is installed"
        docker-compose --version
    else
        log_error "Docker Compose is not installed"
        log_info "Please install Docker Compose from: https://docs.docker.com/compose/install/"
        exit 1
    fi
}

# Function to check other dependencies
check_dependencies() {
    log_info "Checking other dependencies..."

    # Check curl
    if command_exists curl; then
        log_success "curl is installed"
    else
        log_error "curl is not installed"
        log_info "Please install curl"
        exit 1
    fi

    # Check git
    if command_exists git; then
        log_success "git is installed"
        git --version
    else
        log_warning "git is not installed (optional for version tracking)"
    fi
}

# Function to set up Docker Hub credentials
setup_docker_credentials() {
    echo
    log_info "Setting up Docker Hub credentials..."
    log_warning "This is optional for local testing, but required for pushing images"

    read -p "Do you want to configure Docker Hub credentials? (y/N): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter your Docker Hub username: " DOCKER_USERNAME
        read -s -p "Enter your Docker Hub password or access token: " DOCKER_PASSWORD
        echo

        if docker login -u "$DOCKER_USERNAME" --password-stdin <<<"$DOCKER_PASSWORD"; then
            log_success "Docker Hub credentials configured successfully"
        else
            log_error "Failed to configure Docker Hub credentials"
            exit 1
        fi
    fi
}

# Function to create necessary directories
create_directories() {
    log_info "Creating necessary directories..."

    mkdir -p logs
    mkdir -p backups
    mkdir -p scripts

    log_success "Directories created"
}

# Function to make scripts executable
make_scripts_executable() {
    log_info "Making scripts executable..."

    chmod +x scripts/*.sh

    log_success "Scripts are now executable"
}

# Function to build Docker image
build_image() {
    log_info "Building Docker image..."

    if docker build -t "$PROJECT_NAME:latest" .; then
        log_success "Docker image built successfully"
    else
        log_error "Failed to build Docker image"
        exit 1
    fi
}

# Function to start services
start_services() {
    log_info "Starting services..."

    if docker-compose up -d; then
        log_success "Services started successfully"

        # Wait for services to be ready
        log_info "Waiting for services to be ready..."
        sleep 10
    else
        log_error "Failed to start services"
        exit 1
    fi
}

# Function to run initial health check
run_health_check() {
    log_info "Running initial health check..."

    # Check blue environment
    if curl -f -s http://localhost:3001/health >/dev/null; then
        log_success "Blue environment is healthy"
    else
        log_warning "Blue environment is not responding (this might be normal during startup)"
    fi

    # Check green environment
    if curl -f -s http://localhost:3002/health >/dev/null; then
        log_success "Green environment is healthy"
    else
        log_warning "Green environment is not responding (this might be normal during startup)"
    fi

    # Check main application
    if curl -f -s http://localhost/ >/dev/null; then
        log_success "Main application is accessible"
    else
        log_warning "Main application is not accessible through Nginx"
    fi
}

# Function to display next steps
display_next_steps() {
    echo
    log_info "=== Setup Complete! ==="
    echo
    echo "Next steps:"
    echo
    echo "1. Check the status of your deployment:"
    echo "   ./scripts/health-check.sh"
    echo
    echo "2. Access the application:"
    echo "   Main: http://localhost"
    echo "   Blue: http://localhost:3001 or http://localhost/blue"
    echo "   Green: http://localhost:3002 or http://localhost/green"
    echo
    echo "3. Deploy a new version:"
    echo "   ./scripts/deploy.sh <image-tag>"
    echo
    echo "4. Rollback if needed:"
    echo "   ./scripts/rollback.sh"
    echo
    echo "5. View logs:"
    echo "   docker-compose logs -f"
    echo "   docker-compose logs -f app-blue"
    echo "   docker-compose logs -f app-green"
    echo "   docker-compose logs -f nginx"
    echo
    echo "For Jenkins integration:"
    echo "   - Configure Jenkins with Docker pipeline plugin"
    echo "   - Set up Docker Hub credentials in Jenkins"
    echo "   - Create a pipeline job using the Jenkinsfile"
    echo
    log_success "Blue-Green deployment environment is ready!"
}

# Main setup function
main() {
    log_info "Setting up Blue-Green Deployment Environment"
    log_info "============================================"
    echo

    # Check if running in the correct directory
    if [ ! -f "docker-compose.yml" ]; then
        log_error "docker-compose.yml not found!"
        log_info "Please run this script from the project root directory"
        exit 1
    fi

    # Run setup steps
    check_docker
    check_docker_compose
    check_dependencies
    setup_docker_credentials
    create_directories
    make_scripts_executable
    build_image
    start_services
    run_health_check
    display_next_steps
}

# Run main function
main "$@"