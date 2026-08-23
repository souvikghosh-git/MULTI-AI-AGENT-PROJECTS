pipeline {
    agent any

    environment {
        SONAR_PROJECT_KEY = 'LLMOPS'
        AWS_REGION        = 'us-east-1'
        ECR_REPO          = 'my-repo'
        IMAGE_TAG         = 'latest'
        ECS_CLUSTER       = 'multi-ai-agent-cluster-prod'
        ECS_SERVICE       = 'multi-ai-agent-service-prod'
    }

    stages {
        stage('Checkout Source Code') {
            steps {
                echo 'Cloning GitHub repository to Jenkins workspace...'
                checkout scm
            }
        }

        stage('SonarQube Analysis') {
            steps {
                script {
                    echo 'Running SonarQube static code quality analysis...'
                    try {
                        withSonarQubeEnv('Sonarqube') {
                            def scannerHome = tool 'Sonarqube'
                            sh """
                            ${scannerHome}/bin/sonar-scanner \
                                -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                                -Dsonar.sources=. \
                                -Dsonar.host.url=http://sonarqube-dind:9000 \
                                -Dsonar.login=admin \
                                -Dsonar.password=admin || true
                            """
                        }
                    } catch (Exception e) {
                        echo "SonarQube step encountered a non-blocking warning: ${e.message}"
                    }
                }
            }
        }

        stage('Build and Push Docker Image to ECR') {
            steps {
                script {
                    echo "Building and pushing container to ECR: ${env.ECR_REPO}:${env.IMAGE_TAG}..."
                    def accountId = sh(script: "aws sts get-caller-identity --query Account --output text", returnStdout: true).trim()
                    def ecrUrl = "${accountId}.dkr.ecr.${env.AWS_REGION}.amazonaws.com/${env.ECR_REPO}"

                    sh """
                    aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ecrUrl}
                    docker build -t ${env.ECR_REPO}:${IMAGE_TAG} .
                    docker tag ${env.ECR_REPO}:${IMAGE_TAG} ${ecrUrl}:${IMAGE_TAG}
                    docker push ${ecrUrl}:${IMAGE_TAG}
                    """
                }
            }
        }

        stage('Deploy to ECS Fargate') {
            steps {
                script {
                    echo "Rolling out latest deployment to ECS Service: ${env.ECS_SERVICE}..."
                    sh """
                    aws ecs update-service \
                        --cluster ${env.ECS_CLUSTER} \
                        --service ${env.ECS_SERVICE} \
                        --force-new-deployment \
                        --region ${env.AWS_REGION}
                    """
                }
            }
        }
    }

    post {
        success {
            echo "🎉 Pipeline build succeeded and deployed live to ECS Fargate!"
        }
        failure {
            echo "❌ Pipeline build failed. Please check stage logs."
        }
    }
}