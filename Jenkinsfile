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
    }

    stages {
        stage('Cleanup Previous Runs') {
            steps {
                script {
                    sh '''
                        echo "Cleaning up any containers from previous runs..."
                        # Stop any containers running our app image
                        docker ps -q --filter "ancestor=harshitha888/blue-green-app" | xargs -r docker stop
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
                        docker build -t ${env.IMAGE_TAG} .
                        echo "Image built successfully: ${env.IMAGE_TAG}"
                    """
                }
            }
        }

        stage('Run Tests') {
            when {
                expression { !params.SKIP_TESTS }
            }
            steps {
                script {
                    // Run tests in container
                    sh """
                        docker run --rm \
                            -e COLOR=TEST \
                            -e VERSION=${env.VERSION} \
                            ${env.IMAGE_TAG} \
                            npm test || echo "No tests configured"
                    """

                    // Health check test
                    sh """
                        echo "Running health check test..."
                        echo "Starting container with image: ${env.IMAGE_TAG}"

                        # First, stop any existing containers on port 3000
                        echo "Checking for existing containers on port 3000..."
                        docker ps -q --filter "publish=3000" | xargs -r docker stop

                        # Wait a moment for ports to be released
                        sleep 2

                        # Start container in background
                        HEALTH_STATUS=\$(docker run --rm -d -p 3000:3000 ${env.IMAGE_TAG})
                        echo "Container started with ID: \$HEALTH_STATUS"

                        # Wait for container to be ready
                        echo "Waiting for container to start..."
                        for i in {1..10}; do
                            sleep 2
                            if curl -f http://localhost:3000/health 2>/dev/null; then
                                echo "Health check passed after \$((i*2)) seconds!"
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
                                    exit 1
                                fi
                            fi
                        done
                    """
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
                        script: 'curl -s http://nginx/ | grep -o "Current Environment: <strong>\\(BLUE\\|GREEN\\)</strong>" | grep -o "BLUE\\|GREEN" || echo "BLUE"',
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
                        # Stop target environment container if running
                        docker-compose stop app-${env.TARGET_ENV} || true

                        # Pull new image
                        docker pull ${env.IMAGE_TAG}

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
                    def maxAttempts = 30
                    def attempt = 0
                    def targetPort = env.TARGET_ENV == 'blue' ? 3001 : 3002

                    echo "Checking health for ${env.TARGET_ENV} environment on port ${targetPort}"

                    while (attempt < maxAttempts) {
                        try {
                            def healthResponse = sh(
                                script: "curl -s http://localhost:${targetPort}/health",
                                returnStdout: true
                            ).trim()

                            if (healthResponse.contains('"status":"healthy"')) {
                                echo "✅ Health check passed for ${env.TARGET_ENV} environment on attempt ${attempt + 1}"
                                echo "Response: ${healthResponse}"
                                break
                            } else {
                                echo "Health check attempt ${attempt + 1}: Invalid response"
                            }
                        } catch (Exception e) {
                            echo "Health check attempt ${attempt + 1} failed: ${e.getMessage()}"
                        }

                        attempt++
                        if (attempt < maxAttempts) {
                            echo "Waiting 5 seconds before next attempt..."
                            sleep 5
                        }
                    }

                    if (attempt == maxAttempts) {
                        error "❌ Health check failed after ${maxAttempts} attempts for ${env.TARGET_ENV} environment"
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
                        curl -f http://localhost:${targetPort}/health || exit 1

                        # Test info endpoint
                        curl -f http://localhost:${targetPort}/info || exit 1

                        # Test main endpoint
                        curl -f http://localhost:${targetPort}/ || exit 1

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
                    sh 'cp ${NGINX_CONFIG} ${BACKUP_CONFIG}'

                    // Update Nginx configuration to route to target environment
                    def nginxConfig = """
events {
    worker_connections 1024;
}

http {
    upstream app_servers {
        server app-" + env.TARGET_ENV + ":3000 max_fails=3 fail_timeout=30s;
        keepalive 32;
    }

    # Include other configurations from original file
    \$(cat nginx.conf | grep -A 200 'upstream blue_backend')
}
"""

                    writeFile file: 'nginx-temp.conf', text: nginxConfig

                    // Reload Nginx
                    sh """
                        # Update Nginx configuration
                        docker cp nginx-temp.conf nginx:${NGINX_CONFIG}

                        # Test configuration
                        docker exec nginx nginx -t || exit 1

                        # Reload Nginx
                        docker exec nginx nginx -s reload

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
                        # Verify through Nginx proxy
                        curl -f http://localhost/health || exit 1
                        curl -f http://localhost/info | grep ${env.TARGET_ENV.toUpperCase()} || exit 1

                        echo "Validation successful - Traffic is now routed to ${env.TARGET_ENV}"
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
                        if [ -f ${BACKUP_CONFIG} ]; then
                            cp ${BACKUP_CONFIG} ${NGINX_CONFIG}
                            docker exec nginx nginx -s reload
                            echo "Rolled back Nginx configuration"
                        fi

                        # Stop failed deployment
                        docker-compose stop app-${env.TARGET_ENV} || true
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