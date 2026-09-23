pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        skipDefaultCheckout(true)
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    environment {
        AWS_REGION      = 'ap-south-1'
        ECR_REPOSITORY  = 'devops-eks-app'

        EKS_CLUSTER     = 'devops-eks-dev-cluster'
        K8S_NAMESPACE   = 'devops-app'

        DEPLOYMENT_NAME = 'devops-eks-app'
        CONTAINER_NAME  = 'devops-eks-app'
        SERVICE_NAME    = 'devops-eks-app'

        AWS_ACCOUNT_ID      = ''
        ECR_REGISTRY        = ''
        IMAGE_TAG           = ''
        IMAGE_URI           = ''
        PREVIOUS_IMAGE      = ''
        DEPLOY_REQUIRED     = 'true'
        DEPLOYMENT_ATTEMPTED = 'false'
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


        stage('Detect Changes') {
            steps {
                script {

                    def changedFiles = sh(
                        script: '''
                            if git rev-parse HEAD^ >/dev/null 2>&1
                            then
                                git diff --name-only HEAD^ HEAD
                            else
                                git ls-tree -r --name-only HEAD
                            fi
                        ''',
                        returnStdout: true
                    ).trim()

                    echo "===== Changed Files ====="

                    if (changedFiles) {
                        echo changedFiles
                    } else {
                        echo "No file changes detected."
                    }

                    def deploymentChange = false

                    if (changedFiles) {
                        changedFiles.readLines().each { file ->

                            if (
                                file == 'Jenkinsfile' ||
                                file.startsWith('app/') ||
                                file.startsWith('docker/') ||
                                file.startsWith('kubernetes/')
                            ) {
                                deploymentChange = true
                            }
                        }
                    }

                    env.DEPLOY_REQUIRED =
                        deploymentChange ? 'true' : 'false'

                    echo "Deploy required: ${env.DEPLOY_REQUIRED}"
                }
            }
        }


        stage('Unit Test') {

            when {
                expression {
                    return env.DEPLOY_REQUIRED == 'true'
                }
            }

            steps {
                sh '''
                    set -e

                    echo "===== Creating Python Virtual Environment ====="

                    rm -rf .venv

                    python3 -m venv .venv

                    . .venv/bin/activate

                    python -m pip install --upgrade pip

                    pip install \
                      -r app/requirements.txt

                    echo "===== Running Unit Tests ====="

                    pytest -v app/test_app.py
                '''
            }
        }


        stage('Prepare Image Tag') {

            when {
                expression {
                    return env.DEPLOY_REQUIRED == 'true'
                }
            }

            steps {
                script {

                    env.AWS_ACCOUNT_ID = sh(
                        script: '''
                            aws sts get-caller-identity \
                              --query Account \
                              --output text
                        ''',
                        returnStdout: true
                    ).trim()

                    env.ECR_REGISTRY =
                        "${env.AWS_ACCOUNT_ID}.dkr.ecr.${env.AWS_REGION}.amazonaws.com"

                    env.GIT_SHORT_SHA = sh(
                        script: '''
                            git rev-parse --short HEAD
                        ''',
                        returnStdout: true
                    ).trim()

                    env.IMAGE_TAG =
                        "${BUILD_NUMBER}-${env.GIT_SHORT_SHA}"

                    env.IMAGE_URI =
                        "${env.ECR_REGISTRY}/${env.ECR_REPOSITORY}:${env.IMAGE_TAG}"

                    echo "===== Image Information ====="
                    echo "AWS Account : ${env.AWS_ACCOUNT_ID}"
                    echo "Image Tag   : ${env.IMAGE_TAG}"
                    echo "Image URI   : ${env.IMAGE_URI}"
                }
            }
        }


        stage('Docker Build') {

            when {
                expression {
                    return env.DEPLOY_REQUIRED == 'true'
                }
            }

            steps {
                sh '''
                    set -e

                    echo "===== Building Docker Image ====="

                    docker build \
                      -f docker/Dockerfile \
                      -t ${IMAGE_URI} \
                      .
                '''
            }
        }


        stage('ECR Login') {

            when {
                expression {
                    return env.DEPLOY_REQUIRED == 'true'
                }
            }

            steps {
                sh '''
                    set -e

                    echo "===== ECR Login ====="

                    rm -rf "${WORKSPACE}/.docker"

                    mkdir -p \
                      "${WORKSPACE}/.docker"

                    chmod 700 \
                      "${WORKSPACE}/.docker"

                    aws ecr get-login-password \
                      --region ${AWS_REGION} |
                    docker \
                      --config "${WORKSPACE}/.docker" \
                      login \
                      --username AWS \
                      --password-stdin \
                      ${ECR_REGISTRY}
                '''
            }
        }


        stage('Push Image to ECR') {

            when {
                expression {
                    return env.DEPLOY_REQUIRED == 'true'
                }
            }

            steps {
                sh '''
                    set -e

                    echo "===== Pushing Image to ECR ====="

                    docker \
                      --config "${WORKSPACE}/.docker" \
                      push ${IMAGE_URI}
                '''
            }
        }


        stage('Configure EKS') {

            when {
                expression {
                    return env.DEPLOY_REQUIRED == 'true'
                }
            }

            steps {

                sh '''
                    set -e

                    echo "===== Configuring EKS Access ====="

                    aws eks update-kubeconfig \
                      --region ${AWS_REGION} \
                      --name ${EKS_CLUSTER}

                    echo "===== Current Deployment ====="

                    kubectl get deployment \
                      ${DEPLOYMENT_NAME} \
                      -n ${K8S_NAMESPACE}

                    echo "===== Verify Current Deployment is Stable ====="

                    kubectl rollout status \
                      deployment/${DEPLOYMENT_NAME} \
                      -n ${K8S_NAMESPACE} \
                      --timeout=60s
                '''

                script {

                    env.PREVIOUS_IMAGE = sh(
                        script: '''
                            kubectl get deployment \
                              ${DEPLOYMENT_NAME} \
                              -n ${K8S_NAMESPACE} \
                              -o jsonpath='{.spec.template.spec.containers[0].image}'
                        ''',
                        returnStdout: true
                    ).trim()

                    echo "Previous healthy image: ${env.PREVIOUS_IMAGE}"
                }
            }
        }


        stage('Deploy to EKS') {

            when {
                expression {
                    return env.DEPLOY_REQUIRED == 'true'
                }
            }

            steps {

                sh '''
                    set -e

                    echo "===== New Deployment ====="
                    echo "Previous Image : ${PREVIOUS_IMAGE}"
                    echo "New Image      : ${IMAGE_URI}"

                    kubectl annotate \
                      deployment/${DEPLOYMENT_NAME} \
                      -n ${K8S_NAMESPACE} \
                      kubernetes.io/change-cause="Jenkins build ${BUILD_NUMBER}: ${IMAGE_URI}" \
                      --overwrite

                    kubectl set image \
                      deployment/${DEPLOYMENT_NAME} \
                      ${CONTAINER_NAME}=${IMAGE_URI} \
                      -n ${K8S_NAMESPACE}
                '''

                script {
                    env.DEPLOYMENT_ATTEMPTED = 'true'
                }

                sh '''
                    set -e

                    echo "===== Waiting for Kubernetes Rollout ====="

                    kubectl rollout status \
                      deployment/${DEPLOYMENT_NAME} \
                      -n ${K8S_NAMESPACE} \
                      --timeout=180s
                '''
            }
        }


        stage('Verify Deployment') {

            when {
                expression {
                    return env.DEPLOY_REQUIRED == 'true'
                }
            }

            steps {
                sh '''
                    set -e

                    echo "===== Deployment ====="

                    kubectl get deployment \
                      ${DEPLOYMENT_NAME} \
                      -n ${K8S_NAMESPACE}

                    echo

                    echo "===== Pods ====="

                    kubectl get pods \
                      -n ${K8S_NAMESPACE} \
                      -o wide

                    echo

                    echo "===== Expected Image ====="

                    echo "${IMAGE_URI}"

                    echo

                    echo "===== Running Image ====="

                    RUNNING_IMAGE=$(kubectl get deployment \
                      ${DEPLOYMENT_NAME} \
                      -n ${K8S_NAMESPACE} \
                      -o jsonpath='{.spec.template.spec.containers[0].image}')

                    echo "${RUNNING_IMAGE}"

                    if [ "${RUNNING_IMAGE}" != "${IMAGE_URI}" ]
                    then
                        echo "ERROR: Running image does not match expected image."
                        exit 1
                    fi

                    echo
                    echo "Running image verification successful."
                '''
            }
        }


        stage('Application Health Check') {

            when {
                expression {
                    return env.DEPLOY_REQUIRED == 'true'
                }
            }

            steps {
                sh '''
                    set -e

                    echo "===== Application Health Check ====="

                    LB_HOST=$(kubectl get svc \
                      ${SERVICE_NAME} \
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

                    if [ "${SUCCESS}" -ne 1 ]
                    then
                        echo "ERROR: Application health check failed."
                        exit 1
                    fi

                    echo
                    echo "Health endpoint successful."

                    echo
                    echo "===== Application Readiness Check ====="

                    curl \
                      --fail \
                      --silent \
                      --show-error \
                      --max-time 10 \
                      "http://${LB_HOST}/ready"

                    echo
                    echo "Readiness endpoint successful."
                '''
            }
        }


        stage('Deployment Summary') {

            when {
                expression {
                    return env.DEPLOY_REQUIRED == 'true'
                }
            }

            steps {
                sh '''
                    set -e

                    echo "======================================"
                    echo "        DEPLOYMENT SUMMARY"
                    echo "======================================"

                    echo "Build Number   : ${BUILD_NUMBER}"
                    echo "Git Commit     : ${GIT_SHORT_SHA}"
                    echo "Previous Image : ${PREVIOUS_IMAGE}"
                    echo "New Image      : ${IMAGE_URI}"

                    echo

                    echo "===== Rollout History ====="

                    kubectl rollout history \
                      deployment/${DEPLOYMENT_NAME} \
                      -n ${K8S_NAMESPACE}

                    echo

                    echo "===== HPA ====="

                    kubectl get hpa \
                      -n ${K8S_NAMESPACE}

                    echo

                    echo "===== Service ====="

                    kubectl get svc \
                      ${SERVICE_NAME} \
                      -n ${K8S_NAMESPACE}
                '''
            }
        }


        stage('No Application Deployment Required') {

            when {
                expression {
                    return env.DEPLOY_REQUIRED == 'false'
                }
            }

            steps {
                echo '''
Only documentation, Terraform, Ansible, monitoring,
or other non-application files changed.

Application Docker build and EKS deployment were skipped.
'''
            }
        }
    }


    post {

        success {

            script {

                if (env.DEPLOY_REQUIRED == 'true') {

                    echo "CI/CD pipeline completed successfully."
                    echo "Image deployed: ${env.IMAGE_URI}"

                } else {

                    echo "Pipeline completed successfully."
                    echo "No application deployment was required."
                }
            }
        }


        failure {

            script {

                echo "CI/CD pipeline failed."

                if (
                    env.DEPLOYMENT_ATTEMPTED == 'true' &&
                    env.PREVIOUS_IMAGE
                ) {

                    echo "Deployment had already started."
                    echo "Starting automatic rollback."
                    echo "Rollback image: ${env.PREVIOUS_IMAGE}"

                    int rollbackStatus = sh(
                        returnStatus: true,
                        script: '''
                            set -e

                            echo "===== Automatic Rollback ====="

                            CURRENT_LIVE_IMAGE=$(kubectl get deployment \
                              ${DEPLOYMENT_NAME} \
                              -n ${K8S_NAMESPACE} \
                              -o jsonpath='{.spec.template.spec.containers[0].image}')

                            echo "Current image  : ${CURRENT_LIVE_IMAGE}"
                            echo "Rollback image : ${PREVIOUS_IMAGE}"

                            if [ "${CURRENT_LIVE_IMAGE}" = "${PREVIOUS_IMAGE}" ]
                            then
                                echo "Previous image is already running."
                                exit 0
                            fi

                            kubectl annotate \
                              deployment/${DEPLOYMENT_NAME} \
                              -n ${K8S_NAMESPACE} \
                              kubernetes.io/change-cause="Automatic rollback from Jenkins build ${BUILD_NUMBER} to ${PREVIOUS_IMAGE}" \
                              --overwrite

                            kubectl set image \
                              deployment/${DEPLOYMENT_NAME} \
                              ${CONTAINER_NAME}=${PREVIOUS_IMAGE} \
                              -n ${K8S_NAMESPACE}

                            echo "Waiting for rollback rollout..."

                            kubectl rollout status \
                              deployment/${DEPLOYMENT_NAME} \
                              -n ${K8S_NAMESPACE} \
                              --timeout=180s

                            echo
                            echo "===== Rollback Image Verification ====="

                            RESTORED_IMAGE=$(kubectl get deployment \
                              ${DEPLOYMENT_NAME} \
                              -n ${K8S_NAMESPACE} \
                              -o jsonpath='{.spec.template.spec.containers[0].image}')

                            echo "Restored image: ${RESTORED_IMAGE}"

                            if [ "${RESTORED_IMAGE}" != "${PREVIOUS_IMAGE}" ]
                            then
                                echo "ERROR: Rollback image verification failed."
                                exit 1
                            fi

                            echo
                            echo "===== Rollback Health Check ====="

                            LB_HOST=$(kubectl get svc \
                              ${SERVICE_NAME} \
                              -n ${K8S_NAMESPACE} \
                              -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

                            RECOVERY_SUCCESS=0

                            for attempt in $(seq 1 12)
                            do
                                echo "Rollback health attempt ${attempt}/12"

                                if curl \
                                  --fail \
                                  --silent \
                                  --show-error \
                                  --max-time 10 \
                                  "http://${LB_HOST}/health"
                                then
                                    RECOVERY_SUCCESS=1
                                    break
                                fi

                                sleep 10
                            done

                            if [ "${RECOVERY_SUCCESS}" -ne 1 ]
                            then
                                echo "ERROR: Rollback completed but application health check failed."
                                exit 1
                            fi

                            echo
                            echo "Automatic rollback completed successfully."
                        '''
                    )

                    if (rollbackStatus == 0) {

                        echo "Previous healthy image restored successfully."

                    } else {

                        echo "WARNING: Automatic rollback did not complete successfully."
                        echo "Manual investigation is required."
                    }

                } else {

                    echo "Application deployment was not started."
                    echo "No rollback is required."
                }
            }
        }


        always {

            sh '''
                echo "===== Pipeline Cleanup ====="

                if [ -n "${ECR_REGISTRY:-}" ] && \
                   [ -d "${WORKSPACE}/.docker" ]
                then
                    docker \
                      --config "${WORKSPACE}/.docker" \
                      logout "${ECR_REGISTRY}" || true
                fi

                rm -rf \
                  "${WORKSPACE}/.docker" \
                  "${WORKSPACE}/.venv" || true

                if [ -n "${IMAGE_URI:-}" ]
                then
                    docker image rm \
                      "${IMAGE_URI}" || true
                fi

                docker image prune -f || true

                echo "Pipeline cleanup completed."
            '''
        }
    }
}
