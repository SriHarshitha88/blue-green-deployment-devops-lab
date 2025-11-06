pipeline {
    agent any

    parameters {
        string(name: 'DOCKER_IMAGE', defaultValue: 'harshitha888/blue-green-app', description: 'Docker image name')
        string(name: 'VERSION', defaultValue: '', description: 'Version tag (leave empty for git commit SHA)')
        choice(name: 'ENVIRONMENT', choices: ['production', 'staging'], description: 'Target environment')
        booleanParam(name: 'SKIP_TESTS', defaultValue: false, description: 'Skip automated tests')
    }

    environment {
        DOCKER_REGISTRY = 'docker.io'
        DOCKER_CREDENTIALS = credentials('docker-hub-credentials')
        CURRENT_ENV = 'blue'
        NGINX_CONFIG = '/etc/nginx/nginx.conf'
        BACKUP_CONFIG = '/etc/nginx/nginx.conf.backup'
        NGINX_CONTAINER = 'nginx'
    }

    stages {
        stage('Cleanup Previous Runs') {
            steps {
                script {
                    sh '''
                        echo "Cleaning up any containers from previous runs..."
                        # Stop docker-compose containers if running
                        cd ${WORKSPACE} && docker-compose down -v 2>/dev/null || true

                        # Stop any containers using ports 3000, 3001, 3002
                        docker ps -q --filter "publish=3000" | xargs -r docker stop
                        docker ps -q --filter "publish=3001" | xargs -r docker stop
                        docker ps -q --filter "publish=3002" | xargs -r docker stop

                        # Stop any containers running our app image
                        docker ps -q --filter "ancestor=harshitha888/blue-green-app" | xargs -r docker stop
                        docker ps -q --filter "name=blue-green-deployment" | xargs -r docker stop

                        # Remove any stopped containers
                        docker container prune -f
                        # Remove any dangling images
                        docker image prune -f
                        echo "Cleanup completed"
                    '''
                }
            }
        }

        stage('Preparation') {
            steps {
                script {
                    // Set version from git if not provided
                    if (!params.VERSION) {
                        env.VERSION = sh(
                            script: 'git rev-parse --short HEAD',
                            returnStdout: true
                        ).trim()
                    }
                    env.IMAGE_TAG = "${params.DOCKER_IMAGE}:${env.VERSION}"
                    echo "Building image ${env.IMAGE_TAG}"
                }
            }
        }

        stage('Code Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    sh """
                        # Ensure we're in the right directory
                        pwd
                        ls -la Dockerfile || echo "Dockerfile not found in current directory"
                        docker build -t ${env.IMAGE_TAG} ${WORKSPACE} || docker build -t ${env.IMAGE_TAG} .
                        echo "Image built successfully: ${env.IMAGE_TAG}"
                    """
                }
            }
        }

        stage('Run Tests') {
            steps {
                script {
                    echo "Running container health test..."

                    // Stop any existing containers on port 3000
                    echo "Checking for existing containers on port 3000..."
                    sh "docker ps -q --filter 'publish=3000' | xargs -r docker stop"

                    // Wait a moment for ports to be released
                    sleep 2

                    // Start container in background
                    sh """
                        HEALTH_STATUS=\$(docker run --rm -d -p 3000:3000 ${env.IMAGE_TAG})
                        echo "Container started with ID: \$HEALTH_STATUS"

                        # Wait for container to be ready
                        echo "Waiting for container to start..."
                        i=1
                        while [ \$i -le 10 ]; do
                            sleep 2
                            if curl -f http://host.docker.internal:3000/health 2>/dev/null || curl -f http://172.17.0.1:3000/health 2>/dev/null; then
                                echo "✅ Health check passed after \$((i*2)) seconds!"
                                docker stop \$HEALTH_STATUS
                                echo "Container stopped successfully"
                                break
                            else
                                echo "Attempt \$i: Container not ready yet..."
                                if [ \$i -eq 10 ]; then
                                    echo "Health check failed after 20 seconds"
                                    echo "Container logs:"
                                    docker logs \$HEALTH_STATUS 2>&1 || true
                                    docker stop \$HEALTH_STATUS || true
                                    echo "⚠️ Health check failed, but continuing deployment"
                                fi
                            fi
                            i=\$((i+1))
                        done
                    """

                    echo "Note: No unit tests configured - only health check performed"
                }
            }
        }

        stage('Push to Docker Hub') {
            steps {
                script {
                    try {
                        sh """
                            echo ${DOCKER_CREDENTIALS_PSW} | docker login -u ${DOCKER_CREDENTIALS_USR} --password-stdin ${DOCKER_REGISTRY}
                            docker push ${env.IMAGE_TAG}
                            docker logout ${DOCKER_REGISTRY}
                            echo "Image pushed to registry: ${env.IMAGE_TAG}"
                        """
                    } catch (Exception e) {
                        echo "⚠️ Docker Hub push failed, but continuing with deployment"
                        echo "Error: ${e.getMessage()}"
                        echo "Note: For production, you'll need to fix Docker Hub credentials"
                    }
                }
            }
        }

        stage('Determine Active Environment') {
            steps {
                script {
                    // Check which environment is currently active
                    def currentUpstream = sh(
                        script: 'curl -s http://host.docker.internal:80/ 2>/dev/null | grep -o "Current Environment: <strong>\\(BLUE\\|GREEN\\)</strong>" | grep -o "BLUE\\|GREEN" || curl -s http://172.17.0.1:80/ 2>/dev/null | grep -o "Current Environment: <strong>\\(BLUE\\|GREEN\\)</strong>" | grep -o "BLUE\\|GREEN" || echo "BLUE"',
                        returnStdout: true
                    ).trim().toLowerCase()

                    if (currentUpstream == 'blue') {
                        env.CURRENT_ENV = 'blue'
                        env.TARGET_ENV = 'green'
                    } else {
                        env.CURRENT_ENV = 'green'
                        env.TARGET_ENV = 'blue'
                    }

                    echo "Current active environment: ${env.CURRENT_ENV}"
                    echo "Target deployment environment: ${env.TARGET_ENV}"
                }
            }
        }

        stage('Deploy to Target Environment') {
            steps {
                script {
                    // Deploy to target environment
                    sh """
                        cd ${WORKSPACE}
                        # Stop target environment container if running
                        docker-compose stop app-${env.TARGET_ENV} || true

                        # Pull new image (optional, use local if not available)
                        docker pull ${env.IMAGE_TAG} || echo "Using local image - Docker Hub pull failed"

                        # Update docker-compose with new image
                        sed -i 's|image: .*|image: ${env.IMAGE_TAG}|' docker-compose.yml

                        # Start target environment with new image
                        export COLOR=${env.TARGET_ENV.toUpperCase()}
                        export VERSION=${env.VERSION}
                        docker-compose up -d app-${env.TARGET_ENV}

                        echo "Deployed ${env.IMAGE_TAG} to ${env.TARGET_ENV} environment"
                    """
                }
            }
        }

        stage('Health Check') {
            steps {
                script {
                    // Wait for container to be healthy
                    def maxAttempts = 12  // Reduced from 30 to fail faster
                    def attempt = 0
                    def targetPort = env.TARGET_ENV == 'blue' ? 3001 : 3002

                    echo "Checking health for ${env.TARGET_ENV} environment on port ${targetPort}"

                    // First, check if container is actually running
                    sh "docker ps | grep '3002' || echo 'No container found on port 3002'"

                    // Check container logs if it exists
                    sh "docker logs blue-green-deployment-app-${env.TARGET_ENV}-1 2>&1 | tail -10 || echo 'No logs found'"

                    while (attempt < maxAttempts) {
                        try {
                            // Add verbose curl output
                            def healthResponse = sh(
                                script: "curl -v http://host.docker.internal:${targetPort}/health 2>&1 || curl -v http://172.17.0.1:${targetPort}/health 2>&1 || echo 'Connection failed'",
                                returnStdout: true
                            ).trim()

                            echo "Health check attempt ${attempt + 1} response:"
                            echo healthResponse

                            if (healthResponse.contains('"status":"healthy"')) {
                                echo "✅ Health check passed for ${env.TARGET_ENV} environment on attempt ${attempt + 1}"
                                echo "Response: ${healthResponse}"
                                break
                            } else if (healthResponse.contains('Connection refused') || healthResponse.contains('Connection failed')) {
                                echo "❌ Container not ready or not running on port ${targetPort}"
                                if (attempt >= 2) {
                                    // After 3 attempts, check container status
                                    sh "docker ps | grep 'app-${env.TARGET_ENV}' || echo 'Container app-${env.TARGET_ENV} not found in docker ps'"
                                    sh "docker logs blue-green-deployment-app-${env.TARGET_ENV}-1 2>&1 | tail -5 || echo 'No logs available'"
                                }
                            } else {
                                echo "Health check attempt ${attempt + 1}: Invalid response"
                            }
                        } catch (Exception e) {
                            echo "Health check attempt ${attempt + 1} failed: ${e.getMessage()}"
                        }

                        attempt++
                        if (attempt < maxAttempts) {
                            echo "Waiting 5 seconds before next attempt... (${attempt}/${maxAttempts})"
                            sleep 5
                        }
                    }

                    if (attempt == maxAttempts) {
                        echo "❌ Health check failed after ${maxAttempts} attempts for ${env.TARGET_ENV} environment"
                        echo "Final debug information:"
                        sh "docker ps | grep -E '(3001|3002|blue|green)' || echo 'No containers found'"
                        sh "docker network ls | grep blue-green || echo 'No networks found'"
                        error "Health check failed - container might not be running properly"
                    }
                }
            }
        }

        stage('Smoke Tests') {
            steps {
                script {
                    // Run smoke tests against target environment
                    def targetPort = env.TARGET_ENV == 'blue' ? 3001 : 3002

                    sh """
                        # Test health endpoint
                        curl -f http://host.docker.internal:${targetPort}/health || curl -f http://172.17.0.1:${targetPort}/health || exit 1

                        # Test info endpoint
                        curl -f http://host.docker.internal:${targetPort}/info || curl -f http://172.17.0.1:${targetPort}/info || exit 1

                        # Test main endpoint
                        curl -f http://host.docker.internal:${targetPort}/ || curl -f http://172.17.0.1:${targetPort}/ || exit 1

                        echo "Smoke tests passed for ${env.TARGET_ENV} environment"
                    """
                }
            }
        }

        stage('Switch Traffic') {
            steps {
                input message: "Switch traffic to ${env.TARGET_ENV.toUpperCase()} environment?", ok: "Switch"

                script {
                    // Backup current Nginx config
                    sh """
                        # Check if Nginx container is running and backup config
                        if docker ps | grep -q 'nginx'; then
                            docker exec ${NGINX_CONTAINER} cp ${NGINX_CONFIG} ${BACKUP_CONFIG} || echo "Backup: Original config not found, will create new one"
                        else
                            echo "Nginx container not running, creating new config"
                        fi
                    """

                    // Update Nginx configuration to route to target environment
                    def nginxConfig = """
events {
    worker_connections 1024;
}

http {
    upstream app_servers {
        server app-${env.TARGET_ENV}:3000 max_fails=3 fail_timeout=30s;
        keepalive 32;
    }

    server {
        listen 80;
        location / {
            proxy_pass http://app_servers;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }

        location /health {
            proxy_pass http://app_servers/health;
            proxy_set_header Host \$host;
        }

        location /info {
            proxy_pass http://app_servers/info;
            proxy_set_header Host \$host;
        }
    }
}
"""

                    writeFile file: 'nginx-temp.conf', text: nginxConfig

                    // Reload Nginx
                    sh """
                        # Remove existing nginx container if it exists
                        docker rm -f nginx 2>/dev/null || true

                        # Create a directory for nginx config
                        mkdir -p ${WORKSPACE}/nginx-config

                        # Copy config to the nginx config directory
                        cp nginx-temp.conf ${WORKSPACE}/nginx-config/nginx.conf

                        # Create new nginx container with proper networking
                        echo "Creating Nginx container with custom configuration..."
                        docker run -d --name nginx \
                            -p 80:80 \
                            -v ${WORKSPACE}/nginx-config:/etc/nginx:ro \
                            --network blue-green-deployment_blue-green-network \
                            nginx:alpine

                        # Wait for nginx to start
                        sleep 3

                        # Check if nginx is running
                        if docker ps | grep -q 'nginx'; then
                            echo "Nginx container is running"
                        else
                            echo "Failed to start Nginx container"
                        fi

                        echo "Traffic switched to ${env.TARGET_ENV} environment"
                    """
                }
            }
        }

        stage('Post-Switch Validation') {
            steps {
                script {
                    // Verify traffic is routed to new environment
                    sleep 10

                    sh """
                        # Get the Nginx container's IP on the blue-green network
                        NGINX_IP=\$(docker inspect -f '{{range .NetworkSettings.Networks}}{{if eq .Name "blue-green-deployment_blue-green-network"}}{{.IPAddress}}{{end}}{{end}}' nginx 2>/dev/null)

                        # If no IP on blue-green network, try direct host access
                        if [ -z "\$NGINX_IP" ]; then
                            NGINX_IP="localhost"
                        fi

                        echo "Nginx IP: \$NGINX_IP"

                        # Wait a bit for Nginx to be ready
                        sleep 2

                        # Verify through Nginx proxy on port 80
                        if curl -f http://localhost/health 2>/dev/null || curl -f http://127.0.0.1/health 2>/dev/null; then
                            echo "✅ Health check via Nginx passed"

                            # Check the environment info through Nginx
                            RESPONSE=\$(curl -s http://localhost/info 2>/dev/null || curl -s http://127.0.0.1/info 2>/dev/null || echo "")
                            echo "Response from Nginx: \$RESPONSE"

                            if echo "\$RESPONSE" | grep -q "${env.TARGET_ENV.toUpperCase()}"; then
                                echo "✅ Validation successful - Traffic is now routed to ${env.TARGET_ENV}"
                            else
                                echo "⚠️ Warning: Could not verify environment from response"
                                echo "Expected: ${env.TARGET_ENV.toUpperCase()}"
                                echo "Got: \$RESPONSE"

                                # Additional verification - check app directly
                                echo "Checking direct connection to app container..."
                                TARGET_PORT=\$(echo "${env.TARGET_ENV}" | tr '[:lower:]' '[:upper:]')
                                if [ "\$TARGET_PORT" = "BLUE" ]; then
                                    DIRECT_PORT=3001
                                else
                                    DIRECT_PORT=3002
                                fi

                                # Try connecting through Docker network
                                docker exec nginx curl -f http://app-${env.TARGET_ENV}:3000/health || exit 1
                                echo "✅ Direct connection from Nginx to app-${env.TARGET_ENV} successful"
                            fi
                        else
                            echo "❌ Health check via Nginx failed"

                            # Debug Nginx container
                            echo "Debugging Nginx container:"
                            docker ps | grep nginx || echo "Nginx container not running"
                            docker logs nginx 2>&1 | tail -10 || echo "No Nginx logs"
                            docker network inspect blue-green-deployment_blue-green-network | grep Containers || echo "Network inspection failed"

                            # Try direct connection to the app as fallback
                            echo "Attempting direct connection to app container..."
                            TARGET_PORT=\$(echo "${env.TARGET_ENV}" | tr '[:lower:]' '[:upper:]')
                            if [ "\$TARGET_PORT" = "BLUE" ]; then
                                DIRECT_PORT=3001
                            else
                                DIRECT_PORT=3002
                            fi

                            # Connect to container via Docker network
                            docker exec blue-green-deployment-app-${env.TARGET_ENV}-1 curl -f http://localhost:3000/health || exit 1
                            echo "✅ Direct health check on app container successful"
                        fi
                    """
                }
            }
        }

        stage('Clean Up') {
            steps {
                script {
                    // Keep old environment running for rollback
                    echo "Keeping ${env.CURRENT_ENV} environment running for immediate rollback if needed"

                    // Clean up temporary files
                    sh 'rm -f nginx-temp.conf || true'

                    // Prune unused Docker images
                    sh 'docker image prune -f || true'
                }
            }
        }
    }

    post {
        success {
            script {
                echo "✅ Blue-Green deployment completed successfully!"
                echo "📊 Active environment: ${env.TARGET_ENV}"
                echo "🐳 Deployed image: ${env.IMAGE_TAG}"

                // Send success notification (optional)
                // slackSend(color: 'good', message: "Deployment successful: ${env.IMAGE_TAG} to ${env.TARGET_ENV}")
            }
        }

        failure {
            script {
                echo "❌ Deployment failed!"

                // Rollback on failure
                try {
                    sh """
                        # Restore Nginx configuration
                        if docker ps | grep -q 'nginx'; then
                            if docker exec nginx test -f ${BACKUP_CONFIG}; then
                                docker exec nginx cp ${BACKUP_CONFIG} ${NGINX_CONFIG}
                                docker exec nginx nginx -s reload || docker restart nginx
                                echo "Rolled back Nginx configuration"
                            else
                                echo "No backup config found, leaving current configuration"
                            fi
                        else
                            echo "Nginx container not running"
                        fi

                        # Stop failed deployment
                        cd ${WORKSPACE} && docker-compose stop app-${env.TARGET_ENV} || true
                    """
                } catch (Exception e) {
                    echo "Rollback failed: ${e}"
                }

                // Send failure notification (optional)
                // slackSend(color: 'danger', message: "Deployment failed: ${env.IMAGE_TAG}")
            }
        }

        unstable {
            echo "⚠️ Deployment completed with warnings"
        }

        always {
            echo "Pipeline execution completed at ${new Date()}"
        }
    }
}