pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    environment {
        AWS_REGION      = 'ap-south-1'
        AWS_ACCOUNT_ID  = '743610859738'
        ECR_REPOSITORY  = 'devops-eks-app'

        EKS_CLUSTER     = 'devops-eks-dev-cluster'
        K8S_NAMESPACE   = 'devops-app'

        DEPLOYMENT_NAME = 'devops-eks-app'
        CONTAINER_NAME  = 'devops-eks-app'

        ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm

                sh '''
                    echo "===== Git Commit ====="
                    git log -1 --oneline
                '''
            }
        }

        stage('Unit Test') {
            steps {
                sh '''
                    set -e

                    rm -rf .venv

                    python3 -m venv .venv

                    . .venv/bin/activate

                    python -m pip install --upgrade pip
                    pip install -r app/requirements.txt

                    pytest -v app/test_app.py
                '''
            }
        }

        stage('Prepare Image Tag') {
            steps {
                script {
                    env.GIT_SHORT_SHA = sh(
                        script: 'git rev-parse --short HEAD',
                        returnStdout: true
                    ).trim()

                    env.IMAGE_TAG = "${BUILD_NUMBER}-${GIT_SHORT_SHA}"

                    env.IMAGE_URI =
                        "${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}"

                    echo "Image: ${IMAGE_URI}"
                }
            }
        }

        stage('Docker Build') {
            steps {
                sh '''
                    set -e

                    docker build \
                      -f docker/Dockerfile \
                      -t ${IMAGE_URI} \
                      .
                '''
            }
        }

        stage('ECR Login') {
            steps {
                sh '''
                    set -e

                    aws ecr get-login-password \
                      --region ${AWS_REGION} |
                    docker login \
                      --username AWS \
                      --password-stdin ${ECR_REGISTRY}
                '''
            }
        }

        stage('Push Image to ECR') {
            steps {
                sh '''
                    set -e

                    docker push ${IMAGE_URI}
                '''
            }
        }

        stage('Configure EKS') {
            steps {
                sh '''
                    set -e

                    aws eks update-kubeconfig \
                      --region ${AWS_REGION} \
                      --name ${EKS_CLUSTER}

                    kubectl get deployment \
                      -n ${K8S_NAMESPACE}
                '''
            }
        }

        stage('Deploy to EKS') {
            steps {
                sh '''
                    set -e

                    kubectl set image \
                      deployment/${DEPLOYMENT_NAME} \
                      ${CONTAINER_NAME}=${IMAGE_URI} \
                      -n ${K8S_NAMESPACE}

                    kubectl rollout status \
                      deployment/${DEPLOYMENT_NAME} \
                      -n ${K8S_NAMESPACE} \
                      --timeout=180s
                '''
            }
        }

        stage('Verify Deployment') {
            steps {
                sh '''
                    set -e

                    echo "===== Deployment ====="
                    kubectl get deployment \
                      ${DEPLOYMENT_NAME} \
                      -n ${K8S_NAMESPACE}

                    echo "===== Pods ====="
                    kubectl get pods \
                      -n ${K8S_NAMESPACE} \
                      -o wide

                    echo "===== Running Image ====="
                    kubectl get deployment \
                      ${DEPLOYMENT_NAME} \
                      -n ${K8S_NAMESPACE} \
                      -o jsonpath='{.spec.template.spec.containers[0].image}'

                    echo
                '''
            }
        }

        stage('Application Health Check') {
            steps {
                sh '''
                    set -e

                    LB_HOST=$(kubectl get svc \
                      devops-eks-app \
                      -n ${K8S_NAMESPACE} \
                      -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

                    echo "LoadBalancer: ${LB_HOST}"

                    SUCCESS=0

                    for attempt in $(seq 1 12)
                    do
                        echo "Health check attempt ${attempt}/12"

                        if curl \
                          --fail \
                          --silent \
                          --show-error \
                          --max-time 10 \
                          "http://${LB_HOST}/health"
                        then
                            SUCCESS=1
                            break
                        fi

                        sleep 10
                    done

                    if [ "$SUCCESS" -ne 1 ]; then
                        echo "Application health check failed"
                        exit 1
                    fi

                    echo
                    echo "Application health check successful"
                '''
            }
        }
    }

    post {
        success {
            echo "CI/CD pipeline completed successfully."
            echo "Image deployed: ${IMAGE_URI}"
        }

        failure {
            echo "CI/CD pipeline failed. Check the failed stage logs."
        }

        always {
            sh '''
                docker image prune -f || true
            '''
        }
    }
}
