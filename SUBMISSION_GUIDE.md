# LAB EXERCISE 12 – Blue-Green Deployment Submission Document

**Name:** _________________________
**Date:** _________________________
**Course:** _________________________

## Objectives
- Implement a Blue-Green Deployment strategy for a Node.js application
- Containerize the application using Docker
- Set up Jenkins pipeline for automated deployment
- Achieve zero-downtime deployment with instant rollback capability

---

## TASK 1: Project Setup and Environment Configuration

### Step 1.1: Project Structure Creation
Create the project directory structure with all necessary files:

**Actions Performed:**
1. Created project directory: `blue_green_deployment`
2. Set up all configuration files (Dockerfile, docker-compose.yml, nginx.conf)
3. Created Node.js application with health endpoints
4. Set up Jenkins pipeline configuration

**Screenshots to include:**
- [ ] **Screenshot 1.1.1**: Project directory structure showing all files
- [ ] **Screenshot 1.1.2**: Content of package.json showing Node.js dependencies
- [ ] **Screenshot 1.1.3**: Dockerfile configuration
- [ ] **Screenshot 1.1.4**: docker-compose.yml configuration

---

### Step 1.2: Environment Initialization
Run the setup script to initialize the Blue-Green deployment environment.

**Commands Used:**
```bash
cd blue_green_deployment
chmod +x scripts/setup.sh
./scripts/setup.sh
```

**Screenshots to include:**
- [ ] **Screenshot 1.2.1**: Terminal showing setup script execution (Docker checks, dependency verification)
- [ ] **Screenshot 1.2.2**: Docker containers starting up (output of docker-compose up -d)
- [ ] **Screenshot 1.2.3**: Initial health check results from setup script

**Observations:**
- All dependencies were verified successfully ✓
- Docker containers were created and started ✓
- Both blue and green environments are running ✓

---

## TASK 2: Application Testing and Verification

### Step 2.1: Manual Application Testing
Access and test both Blue and Green environments.

**Actions Performed:**
1. Accessed main application at http://localhost
2. Tested Blue environment directly at http://localhost:3001
3. Tested Green environment directly at http://localhost:3002
4. Verified health endpoints are working

**Screenshots to include:**
- [ ] **Screenshot 2.1.1**: Browser showing main application (http://localhost) - displaying BLUE environment
- [ ] **Screenshot 2.1.2**: Browser showing Blue environment (http://localhost:3001) with BLUE background
- [ ] **Screenshot 2.1.3**: Browser showing Green environment (http://localhost:3002) with GREEN background
- [ ] **Screenshot 2.1.4**: Health check endpoint output for Blue environment (http://localhost:3001/health)
- [ ] **Screenshot 2.1.5**: Health check endpoint output for Green environment (http://localhost:3002/health)
- [ ] **Screenshot 2.1.6**: Terminal output of `./scripts/health-check.sh` showing both environments healthy

**Results:**
- Main application successfully routes to BLUE environment ✓
- Both environments respond correctly ✓
- Health endpoints return proper JSON ✓

---

## TASK 3: Docker Hub Integration

### Step 3.1: Docker Hub Repository Setup
Create and configure Docker Hub repository for the application.

**Actions Performed:**
1. Created Docker Hub account
2. Created new repository: `blue-green-app`
3. Built Docker image locally
4. Pushed image to Docker Hub

**Commands Used:**
```bash
# Build Docker image
docker build -t yourusername/blue-green-app:1.0.0 .

# Login to Docker Hub
docker login

# Push image
docker push yourusername/blue-green-app:1.0.0
```

**Screenshots to include:**
- [ ] **Screenshot 3.1.1**: Docker Hub website showing created repository
- [ ] **Screenshot 3.1.2**: Docker build command execution with successful build
- [ ] **Screenshot 3.1.3**: Docker push command execution
- [ ] **Screenshot 3.1.4**: Docker Hub repository showing uploaded image tag

**Results:**
- Docker image successfully built ✓
- Image pushed to Docker Hub repository ✓

---

## TASK 4: Jenkins Pipeline Configuration

### Step 4.1: Jenkins Installation and Plugin Setup
Install Jenkins and configure required plugins.

**Actions Performed:**
1. Installed Jenkins on local machine/Docker
2. Completed initial Jenkins setup
3. Installed required plugins:
   - Docker Pipeline
   - Docker Plugin
   - Blue Ocean
   - HTTP Request Plugin
   - Pipeline Utility Steps

**Screenshots to include:**
- [ ] **Screenshot 4.1.1**: Jenkins welcome screen with initial password
- [ ] **Screenshot 4.1.2**: Plugin installation page showing required plugins
- [ ] **Screenshot 4.1.3**: Jenkins dashboard after setup
- [ ] **Screenshot 4.1.4**: Manage Plugins page confirming all plugins installed

### Step 4.2: Jenkins Credentials Configuration
Configure Docker Hub credentials in Jenkins.

**Actions Performed:**
1. Navigated to Manage Jenkins → Manage Credentials
2. Added new Docker Hub credentials
3. Set ID as `docker-hub-credentials`

**Screenshots to include:**
- [ ] **Screenshot 4.2.1**: Jenkins credentials configuration page
- [ ] **Screenshot 4.2.2**: Successfully added Docker Hub credentials
- [ ] **Screenshot 4.2.3**: Credentials list showing Docker Hub credentials

### Step 4.3: Pipeline Job Creation
Create Jenkins pipeline job for Blue-Green deployment.

**Actions Performed:**
1. Created new pipeline job: `blue-green-deployment`
2. Configured Git repository as source
3. Set Jenkinsfile as pipeline script
4. Saved configuration

**Screenshots to include:**
- [ ] **Screenshot 4.3.1**: New Item creation page in Jenkins
- [ ] **Screenshot 4.3.2**: Pipeline configuration page showing Git setup
- [ ] **Screenshot 4.3.3**: Pipeline script path configuration
- [ ] **Screenshot 4.3.4**: Pipeline job configuration summary

---

## TASK 5: Automated Deployment Execution

### Step 5.1: Pipeline Execution
Run the Jenkins pipeline for automated deployment.

**Actions Performed:**
1. Triggered pipeline build
2. Monitored all stages execution
3. Verified successful deployment
4. Confirmed traffic switch

**Screenshots to include:**
- [ ] **Screenshot 5.1.1**: Pipeline execution page showing all stages
- [ ] **Screenshot 5.1.2**: Stage view showing successful completion of all stages
- [ ] **Screenshot 5.1.3**: Console output showing build progress
- [ ] **Screenshot 5.1.4**: Traffic switch confirmation dialog
- [ ] **Screenshot 5.1.5**: Pipeline execution completed successfully (green checkmarks)
- [ ] **Screenshot 5.1.6**: Browser showing application after deployment (now showing GREEN environment)

**Stage Execution Details:**
- Preparation: ✓ Completed
- Code Checkout: ✓ Completed
- Build Docker Image: ✓ Completed
- Run Tests: ✓ Completed
- Push to Docker Hub: ✓ Completed
- Determine Active Environment: ✓ Current was BLUE
- Deploy to Target (GREEN): ✓ Completed
- Health Check: ✓ Passed
- Smoke Tests: ✓ Passed
- Switch Traffic: ✓ Switched to GREEN
- Post-Switch Validation: ✓ Passed

---

## TASK 6: Rollback Testing

### Step 6.1: Manual Rollback Test
Test the rollback functionality by switching back to previous version.

**Actions Performed:**
1. Executed rollback script
2. Confirmed rollback action
3. Verified traffic switched back
4. Validated application is running previous version

**Commands Used:**
```bash
./scripts/rollback.sh
```

**Screenshots to include:**
- [ ] **Screenshot 6.1.1**: Rollback script execution in terminal
- [ ] **Screenshot 6.1.2**: Rollback confirmation prompt
- [ ] **Screenshot 6.1.3**: Terminal showing successful rollback
- [ ] **Screenshot 6.1.4**: Browser showing application after rollback (back to BLUE environment)
- [ ] **Screenshot 6.1.5**: Health check after rollback confirming BLUE is active

**Results:**
- Rollback executed successfully ✓
- Traffic switched back to BLUE environment ✓
- Zero downtime during rollback ✓

---

## TASK 7: Monitoring and Health Verification

### Step 7.1: Comprehensive Health Check
Run comprehensive health checks on both environments.

**Actions Performed:**
1. Executed health check script for all environments
2. Checked Docker container status
3. Verified Nginx configuration
4. Monitored resource usage

**Commands Used:**
```bash
./scripts/health-check.sh all
docker-compose ps
docker stats
```

**Screenshots to include:**
- [ ] **Screenshot 7.1.1**: Complete health check output showing both environments
- [ ] **Screenshot 7.1.2**: Docker container status showing all services running
- [ ] **Screenshot 7.1.3**: Docker resource usage statistics
- [ ] **Screenshot 7.1.4**: Nginx health check endpoint output

---

## TASK 8: Troubleshooting and Error Handling

### Step 8.1: Error Scenarios (if encountered)
Document any errors encountered and their solutions.

**Screenshots to include (if errors occurred):**
- [ ] **Screenshot 8.1.1**: Error message encountered
- [ ] **Screenshot 8.1.2**: Troubleshooting steps performed
- [ ] **Screenshot 8.1.3**: Error resolution confirmation

*Note: If no errors were encountered, state: "No errors encountered during the implementation process. All components worked as expected."*

---

## SUMMARY AND CONCLUSIONS

### Implementation Summary:
1. ✅ Successfully created Node.js application with health endpoints
2. ✅ Containerized application using Docker
3. ✅ Set up Nginx reverse proxy for traffic routing
4. ✅ Implemented complete Jenkins CI/CD pipeline
5. ✅ Executed zero-downtime deployment
6. ✅ Tested instant rollback capability
7. ✅ Verified monitoring and health checks

### Key Achievements:
- **Zero Downtime**: Users experienced no interruption during deployment
- **Instant Rollback**: Previous version restored within seconds
- **Automation**: Complete CI/CD pipeline with Jenkins
- **Health Monitoring**: Comprehensive health checks for both environments
- **Container Orchestration**: Docker Compose managing multiple services

### Challenges Faced:
- *(List any challenges encountered during implementation)*

### Lessons Learned:
1. Blue-Green deployment eliminates downtime during updates
2. Health checks are crucial for successful deployments
3. Automation reduces human error in deployment process
4. Rollback capability is essential for production systems
5. Containerization simplifies environment management

### Future Improvements:
- Add automated testing stage in pipeline
- Implement notification system for deployment status
- Add metrics collection and monitoring dashboard
- Implement database migration strategies
- Add canary deployment option

---

## Appendix: Commands Reference

### Essential Commands Used:
```bash
# Setup
./scripts/setup.sh

# Health Check
./scripts/health-check.sh

# Deploy
./scripts/deploy.sh yourusername/blue-green-app:1.0.0

# Rollback
./scripts/rollback.sh

# Manual Switch
./scripts/switch-env.sh blue  # or green

# Docker Commands
docker-compose ps
docker-compose logs -f
docker stats
```

### Endpoints Used:
- Main Application: http://localhost
- Blue Environment: http://localhost:3001 or http://localhost/blue
- Green Environment: http://localhost:3002 or http://localhost/green
- Blue Health: http://localhost:3001/health
- Green Health: http://localhost:3002/health
- Nginx Health: http://localhost/nginx-health

---

**Grade:** _________________________
**Instructor's Comments:** __________________________________________________
_____________________________________________________________________________
_____________________________________________________________________________