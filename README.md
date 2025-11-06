# Blue-Green Deployment Implementation

This project demonstrates a complete Blue-Green Deployment strategy for a Node.js application using Docker, Nginx, and Jenkins.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Project Structure](#project-structure)
4. [Setup Instructions](#setup-instructions)
5. [Local Testing](#local-testing)
6. [Docker Hub Integration](#docker-hub-integration)
7. [Jenkins Pipeline Setup](#jenkins-pipeline-setup)
8. [Deployment Process](#deployment-process)
9. [Rollback Process](#rollback-process)
10. [Monitoring and Health Checks](#monitoring-and-health-checks)
11. [Troubleshooting](#troubleshooting)
12. [Screenshots Guide](#screenshots-guide)

## Overview

Blue-Green Deployment is a deployment strategy that aims to reduce downtime by running two identical production environments called Blue and Green. At any time, only one of the environments is live, serving production traffic. The other environment is idle and can be used for testing new deployments.

### Benefits:

- **Zero Downtime**: Users can continue using the application while new version is deployed
- **Instant Rollback**: If issues are detected, traffic can be switched back instantly
- **Safe Testing**: New version can be thoroughly tested before going live
- **Risk Reduction**: Production issues can be quickly resolved

### Architecture:

```
┌─────────────┐     ┌──────────┐     ┌──────────────┐
│  User       │────▶│  Nginx   │────▶│   Blue/Green │
│  Traffic    │     │  Proxy   │     │  App Servers │
└─────────────┘     └──────────┘     └──────────────┘
                           │
                           ▼
                   ┌──────────────┐
                   │  Health      │
                   │  Checks      │
                   └──────────────┘
```

## Prerequisites

### Required Software:

1. **Docker** (v20.10+)
   - [Download Docker](https://docs.docker.com/get-docker/)

2. **Docker Compose** (v2.0+)
   - [Install Docker Compose](https://docs.docker.com/compose/install/)

3. **Node.js** (v18+)
   - [Download Node.js](https://nodejs.org/)

4. **Jenkins** (v2.400+)
   - [Download Jenkins](https://jenkins.io/download/)

5. **Git**
   - [Download Git](https://git-scm.com/)

### Jenkins Plugins Required:

- Docker Pipeline
- Docker Plugin
- Blue Ocean
- HTTP Request Plugin
- Pipeline Utility Steps

## Project Structure

```
blue_green_deployment/
├── package.json              # Node.js dependencies
├── server.js                 # Express.js application
├── Dockerfile               # Container configuration
├── .dockerignore            # Files to exclude from Docker
├── docker-compose.yml       # Multi-container orchestration
├── nginx.conf               # Nginx reverse proxy configuration
├── Jenkinsfile              # CI/CD pipeline definition
├── scripts/                 # Helper scripts
│   ├── setup.sh            # Initial setup script
│   ├── deploy.sh           # Deployment script
│   ├── rollback.sh         # Rollback script
│   └── health-check.sh     # Health monitoring script
├── logs/                    # Log directory
├── backups/                 # Backup directory
└── README.md               # This file
```

## Setup Instructions

### Step 1: Clone or Create the Project

```bash
# If using Git
git clone <repository-url>
cd blue_green_deployment

# Otherwise, create the directory and copy files
mkdir blue_green_deployment
cd blue_green_deployment
# Copy all project files here
```

### Step 2: Run the Setup Script

The setup script will check dependencies and initialize the environment:

```bash
# Make setup script executable (Linux/Mac)
chmod +x scripts/setup.sh

# Run setup
./scripts/setup.sh
```

**Screenshots to capture:**
1. Terminal showing setup script execution
2. Docker containers starting up
3. Initial health check results

### Step 3: Verify the Setup

```bash
# Check all services
docker-compose ps

# Run health check
./scripts/health-check.sh
```

**Screenshots to capture:**
1. Docker ps output showing all containers running
2. Health check results showing both environments

## Local Testing

### Access the Application

1. **Main Application**: http://localhost
2. **Blue Environment**: http://localhost:3001 or http://localhost/blue
3. **Green Environment**: http://localhost:3002 or http://localhost/green
4. **Health Checks**:
   - Blue: http://localhost:3001/health
   - Green: http://localhost:3002/health

### Testing Blue-Green Switching Manually

```bash
# Deploy to inactive environment
./scripts/deploy.sh test-image:latest

# Check health
./scripts/health-check.sh

# Rollback if needed
./scripts/rollback.sh
```

**Screenshots to capture:**
1. Browser showing blue environment
2. Browser showing green environment
3. Terminal during deployment process
4. Health check outputs

## Docker Hub Integration

### Step 1: Create Docker Hub Account

1. Sign up at [https://hub.docker.com](https://hub.docker.com)
2. Create a repository for your application

**Screenshots to capture:**
1. Docker Hub account creation
2. Repository creation page

### Step 2: Configure Docker Credentials

```bash
# Login to Docker Hub
docker login

# Or configure in Jenkins UI
# Manage Jenkins -> Manage Credentials -> Add Credentials
```

**Screenshots to capture:**
1. Docker login command execution
2. Jenkins credentials configuration page

### Step 3: Build and Push Image

```bash
# Build image
docker build -t yourusername/blue-green-app:1.0.0 .

# Push to Docker Hub
docker push yourusername/blue-green-app:1.0.0
```

**Screenshots to capture:**
1. Docker build process
2. Docker push process
3. Docker Hub repository showing uploaded image

## Jenkins Pipeline Setup

### Step 1: Install Jenkins

1. Download and run Jenkins:
   ```bash
   # Using Docker
   docker run -d -p 8080:8080 -p 50000:50000 jenkins/jenkins:lts
   ```

2. Access Jenkins at http://localhost:8080

3. Complete initial setup:
   - Get initial password from logs
   - Install suggested plugins
   - Create admin user

**Screenshots to capture:**
1. Jenkins welcome page
2. Plugin installation page
3. Admin user creation
4. Jenkins dashboard

### Step 2: Install Required Plugins

1. Go to `Manage Jenkins` → `Manage Plugins`
2. Install these plugins:
   - Docker Pipeline
   - Docker Plugin
   - Blue Ocean
   - HTTP Request Plugin
   - Pipeline Utility Steps

**Screenshots to capture:**
1. Plugin manager page
2. Plugin installation progress
3. Plugin installation confirmation

### Step 3: Configure Docker Hub Credentials

1. Go to `Manage Jenkins` → `Manage Credentials`
2. Click `Add Credentials`
3. Select `Username with password`
4. Enter Docker Hub credentials
5. Set ID as `docker-hub-credentials`

**Screenshots to capture:**
1. Credentials configuration page
2. Added credentials in the list

### Step 4: Create Pipeline Job

1. From Jenkins dashboard, click `New Item`
2. Enter name: `blue-green-deployment`
3. Select `Pipeline`
4. Click `OK`
5. In pipeline configuration:
   - Select `Pipeline script from SCM`
   - SCM: Git
   - Repository URL: your repository URL
   - Script path: `Jenkinsfile`
6. Save

**Screenshots to capture:**
1. New item creation page
2. Pipeline configuration page
3. Git repository configuration
4. Jenkinsfile reference

### Step 5: Run the Pipeline

1. Click `Build Now`
2. Monitor the pipeline execution
3. Check each stage status

**Screenshots to capture:**
1. Pipeline execution page
2. Stage view showing progress
3. Console output logs
4. Successful completion message

## Deployment Process

### Automated Deployment via Jenkins

1. Trigger Jenkins pipeline:
   - Manual: Click `Build Now`
   - Automatic: On Git push (if webhook configured)

2. Pipeline stages:
   - **Preparation**: Sets version and environment variables
   - **Build**: Creates Docker image
   - **Tests**: Runs health checks
   - **Push**: Uploads to Docker Hub
   - **Deploy**: Deploys to inactive environment
   - **Health Check**: Verifies deployment
   - **Smoke Tests**: Runs integration tests
   - **Switch Traffic**: Updates Nginx routing
   - **Validation**: Confirms successful switch

**Screenshots to capture:**
1. Pipeline stage view
2. Each stage execution
3. Traffic switch confirmation dialog
4. Final deployment success message

### Manual Deployment

```bash
# Deploy with version tag
./scripts/deploy.sh yourusername/blue-green-app:1.0.0

# The script will:
# 1. Determine current active environment
# 2. Deploy to inactive environment
# 3. Run health checks
# 4. Ask for confirmation to switch traffic
# 5. Update Nginx configuration
# 6. Validate the switch
```

**Screenshots to capture:**
1. Deployment script execution
2. Health check results
3. Traffic switch confirmation
4. Final deployment status

## Rollback Process

### Instant Rollback

```bash
# Quick rollback to previous version
./scripts/rollback.sh

# Or rollback to specific environment
./scripts/rollback.sh blue
./scripts/rollback.sh green
```

### Rollback via Jenkins

1. Go to pipeline execution page
2. Click `Replay` on successful build
3. Modify to rollback configuration
4. Or run rollback script in Jenkins script console

**Screenshots to capture:**
1. Rollback script execution
2. Traffic switching back
3. Validation after rollback
4. Application showing previous version

## Monitoring and Health Checks

### Health Check Endpoints

- **Application Health**: `/health`
  ```json
  {
    "status": "healthy",
    "version": "1.0.0",
    "color": "BLUE",
    "timestamp": "2024-01-01T00:00:00.000Z",
    "uptime": 3600
  }
  ```

- **Application Info**: `/info`
  ```json
  {
    "name": "Blue-Green Deployment Demo",
    "version": "1.0.0",
    "environment": "BLUE",
    "hostname": "container-id",
    "port": 3000
  }
  ```

- **Nginx Health**: `/nginx-health`
  ```
  healthy
  ```

### Monitoring Commands

```bash
# Check overall health
./scripts/health-check.sh

# Check specific environment
./scripts/health-check.sh blue
./scripts/health-check.sh green

# View logs
docker-compose logs -f
docker-compose logs -f app-blue
docker-compose logs -f app-green
docker-compose logs -f nginx

# Monitor resource usage
docker stats
```

**Screenshots to capture:**
1. Health check output
2. Docker logs showing application logs
3. Docker stats showing resource usage

## Troubleshooting

### Common Issues and Solutions

#### 1. Port Already in Use

```bash
# Check what's using the port
lsof -i :80
lsof -i :3001
lsof -i :3002

# Kill the process or change ports
```

**Screenshot**: Port conflict error message

#### 2. Docker Container Won't Start

```bash
# Check logs
docker-compose logs app-blue
docker-compose logs app-green

# Check configuration
docker-compose config

# Rebuild image
docker-compose build --no-cache
```

**Screenshot**: Container error logs

#### 3. Nginx Configuration Errors

```bash
# Test Nginx configuration
docker exec nginx nginx -t

# Check Nginx logs
docker-compose logs nginx

# Reload Nginx
docker exec nginx nginx -s reload
```

**Screenshot**: Nginx error logs

#### 4. Health Check Failures

```bash
# Check if application is responding
curl -v http://localhost:3001/health
curl -v http://localhost:3002/health

# Check firewall settings
# Check Docker network connectivity
```

**Screenshot**: Health check failure output

#### 5. Jenkins Pipeline Failures

- **Build Failures**: Check Jenkins console output
- **Docker Push Failures**: Verify Docker Hub credentials
- **Test Failures**: Check test logs and fix issues
- **Deployment Failures**: Check Docker logs on target server

**Screenshot**: Jenkins console error output

### Recovery Procedures

1. **Service Down**:
   ```bash
   # Restart all services
   docker-compose down
   docker-compose up -d
   ```

2. **Database Issues** (if applicable):
   ```bash
   # Check database container
   docker-compose ps db
   docker-compose logs db
   ```

3. **Full Recovery**:
   ```bash
   # Clean up everything
   docker-compose down -v
   docker system prune -a

   # Start fresh
   ./scripts/setup.sh
   ```

## Screenshots Guide

### Required Screenshots for Documentation:

1. **Setup Phase**:
   - [ ] Terminal with setup script execution
   - [ ] Docker containers list showing all services
   - [ ] Initial health check successful output

2. **Docker Hub Setup**:
   - [ ] Docker Hub website showing repository
   - [ ] Docker build and push commands
   - [ ] Repository with pushed image

3. **Jenkins Setup**:
   - [ ] Jenkins dashboard
   - [ ] Plugin installation page
   - [ ] Credentials configuration
   - [ ] Pipeline job configuration
   - [ ] Pipeline execution in progress
   - [ ] Successful pipeline completion

4. **Deployment Process**:
   - [ ] Blue environment in browser
   - [ ] Green environment in browser
   - [ ] Deployment script running
   - [ ] Traffic switch confirmation
   - [ ] Application showing new version
   - [ ] Health check after deployment

5. **Rollback Process**:
   - [ ] Rollback script execution
   - [ ] Traffic switching back
   - [ ] Application showing previous version
   - [ ] Confirmation of successful rollback

6. **Monitoring**:
   - [ ] Health check outputs
   - [ ] Docker logs
   - [ ] Resource usage statistics
   - [ ] Nginx configuration status

7. **Troubleshooting** (if applicable):
   - [ ] Error messages encountered
   - [ ] Resolution steps
   - [ ] Final successful state

### How to Take Screenshots:

**Windows**: Use Snipping Tool or Win+Shift+S
**Mac**: Use Cmd+Shift+4 or Screenshot app
**Linux**: Use gnome-screenshot or Flameshot

### Organizing Screenshots:

Create a folder structure:
```
documentation/
├── screenshots/
│   ├── setup/
│   ├── docker-hub/
│   ├── jenkins/
│   ├── deployment/
│   ├── rollback/
│   ├── monitoring/
│   └── troubleshooting/
└── blue-green-deployment-doc.docx
```

## Best Practices

1. **Always test in staging before production**
2. **Keep rollback plans ready**
3. **Monitor both environments continuously**
4. **Automate as much as possible**
5. **Document every step**
6. **Use version tags for all deployments**
7. **Implement proper logging**
8. **Set up alerts for failures**
9. **Regular backup of configurations**
10. **Security scan of Docker images**

## Conclusion

This implementation provides a robust, zero-downtime deployment strategy using Blue-Green methodology. The combination of Docker, Nginx, and Jenkins creates a powerful CI/CD pipeline that ensures safe deployments with instant rollback capabilities.

For any issues or questions, refer to the troubleshooting section or check the logs for detailed error information.

---

**Note**: Replace `yourusername` in all examples with your actual Docker Hub username.