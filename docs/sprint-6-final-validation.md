# Sprint 6 - Final Validation, Hardening and Project Readiness

## Overview

Sprint 6 focuses on final production-style validation, CI/CD hardening,
infrastructure verification, monitoring validation, documentation,
rollback testing, and project readiness.

---

## Task 1 - Kubernetes Deployment Rollback Test

### Objective

The objective of this task was to validate how the Kubernetes deployment
behaves when an invalid application image is deployed and to verify that
the previous healthy version can be restored successfully.

### Initial State

Application deployment:

```text
Deployment: devops-eks-app
Namespace: devops-app
Replicas: 2
HPA Minimum Pods: 2
HPA Maximum Pods: 10
CPU Target: 60%

Healthy application image:

743610859738.dkr.ecr.ap-south-1.amazonaws.com/devops-eks-app:3-6832de1

Initial deployment status:

READY: 2/2
AVAILABLE: 2

Application health:

/health = healthy
Rollout History Before Test

Command:

kubectl rollout history \
  deployment/devops-eks-app \
  -n devops-app

Current revision before the test:

Revision: 4
Save Current Healthy Image

Command:

CURRENT_IMAGE=$(kubectl get deployment devops-eks-app \
  -n devops-app \
  -o jsonpath='{.spec.template.spec.containers[0].image}')

echo "$CURRENT_IMAGE"

Output:

743610859738.dkr.ecr.ap-south-1.amazonaws.com/devops-eks-app:3-6832de1
Simulate a Bad Deployment

A non-existent image tag was intentionally used:

rollback-test-bad

Command:

BAD_IMAGE="743610859738.dkr.ecr.ap-south-1.amazonaws.com/devops-eks-app:rollback-test-bad"

kubectl set image \
  deployment/devops-eks-app \
  devops-eks-app="$BAD_IMAGE" \
  -n devops-app
Observed Failure

The newly created pods failed with:

ErrImagePull
ImagePullBackOff

Example:

devops-eks-app-7f64d597b5-nhqx6   0/1   ImagePullBackOff
devops-eks-app-7f64d597b5-p8d8l   0/1   ImagePullBackOff

The old healthy application pod remained running.

Root Cause

The configured image tag did not exist in Amazon ECR.

Kubernetes attempted to pull:

devops-eks-app:rollback-test-bad

but the registry returned an image-not-found error.

Rollout Status

Command:

kubectl rollout status \
  deployment/devops-eks-app \
  -n devops-app \
  --timeout=60s

Result:

error: timed out waiting for the condition

The deployment could not complete because the new pods were not healthy.

Availability During Failed Rollout

The application health endpoint was tested while the new deployment was failing.

Command:

curl -sS --fail \
  "http://${LB_HOST}/health"

Result:

{"status":"healthy"}

This demonstrated that the old healthy replica continued serving traffic
while the new unhealthy pods were prevented from becoming ready.

Rollback

Command:

kubectl rollout undo \
  deployment/devops-eks-app \
  -n devops-app

Result:

deployment.apps/devops-eks-app rolled back

Rollback status:

kubectl rollout status \
  deployment/devops-eks-app \
  -n devops-app \
  --timeout=180s

Result:

deployment "devops-eks-app" successfully rolled out
Rollback Image Verification

Before failed deployment:

743610859738.dkr.ecr.ap-south-1.amazonaws.com/devops-eks-app:3-6832de1

After rollback:

743610859738.dkr.ecr.ap-south-1.amazonaws.com/devops-eks-app:3-6832de1

Verification:

ROLLBACK VERIFIED
Final Kubernetes State

Deployment:

READY: 2/2
UP-TO-DATE: 2
AVAILABLE: 2

HPA:

Minimum Pods: 2
Maximum Pods: 10
Current Replicas: 2
CPU Target: 60%

Both application pods returned to the Running state.

Final Application Validation

Health endpoint:

{"status":"healthy"}

Readiness endpoint:

{"status":"ready"}
Important Observation

The following warning was displayed during kubectl rollout undo:

The deployment was previously managed with kubectl apply.
Rolling back will not update the
kubectl.kubernetes.io/last-applied-configuration annotation.

This will be considered during the pipeline and deployment hardening tasks.

Final Result
Bad deployment detected       : PASS
ImagePullBackOff detected      : PASS
Application remained available: PASS
Rollback completed             : PASS
Previous image restored        : PASS
Deployment returned to 2/2     : PASS
Health endpoint verified       : PASS
Readiness endpoint verified    : PASS



---

## Task 2 - Jenkins CI/CD Pipeline Hardening

### Objective

The objective of this task was to improve the existing Jenkins CI/CD
pipeline by adding safer deployment handling, dynamic image tagging,
deployment verification, change detection, temporary ECR authentication,
and cleanup mechanisms.

The hardened pipeline was validated using a real GitHub webhook triggered
build.

---

### Initial CI/CD Flow

The original pipeline performed the following flow:

```text
GitHub Push
    ↓
Jenkins Checkout
    ↓
Unit Test
    ↓
Docker Build
    ↓
ECR Login
    ↓
Push Image
    ↓
Configure EKS
    ↓
Deploy Application
    ↓
Verify Deployment
    ↓
Application Health Check

The pipeline was already functional, but additional production-style
hardening was required.

Improvements Implemented

The Jenkins pipeline was updated with the following improvements:

1. skipDefaultCheckout(true)
2. Git change detection
3. Dynamic AWS account discovery
4. Dynamic Docker image tagging
5. Previous healthy image capture
6. Deployment rollout verification
7. Running image verification
8. Health endpoint verification
9. Readiness endpoint verification
10. Kubernetes deployment change-cause annotation
11. Temporary Docker authentication directory
12. Docker credential cleanup after pipeline execution
13. Docker image cleanup
14. Automatic rollback logic for failed deployments
15. Build retention and concurrent-build protection
Duplicate Checkout Optimization

The following Jenkins option was added:

skipDefaultCheckout(true)

The pipeline now uses the explicit Checkout stage rather than performing
an unnecessary additional default checkout.

Change Detection

A new Detect Changes stage was introduced.

The pipeline compares the current Git commit with the previous commit.

Application deployment is required when changes occur in:

Jenkinsfile
app/
docker/
kubernetes/

For documentation, Terraform, Ansible, monitoring, or other non-application
changes, the application build and deployment can be skipped.

During validation, Jenkins detected:

Changed File:
Jenkinsfile

Deploy required:
true
Unit Test Validation

The Jenkins pipeline created a Python virtual environment and executed
the application test suite.

Command:

pytest -v app/test_app.py

Result:

test_home       PASSED
test_health     PASSED
test_ready      PASSED
test_metrics    PASSED

4 passed
Dynamic Image Tagging

The pipeline dynamically obtains the AWS account ID:

aws sts get-caller-identity \
  --query Account \
  --output text

The Docker image tag is generated using:

Jenkins Build Number + Git Short SHA

Successful validation produced:

AWS Account : 743610859738
Image Tag   : 7-93045ac

Image URI:
743610859738.dkr.ecr.ap-south-1.amazonaws.com/devops-eks-app:7-93045ac

This provides traceability between:

Git Commit
    ↓
Jenkins Build
    ↓
Docker Image
    ↓
Kubernetes Deployment
Issue Found During Initial Hardening Test

During the first execution of the hardened Jenkinsfile, dynamically
generated variables became null.

Observed output:

AWS Account : null
Image Tag   : null
Image URI   : null

As a result, Docker received an invalid command similar to:

docker build -t .

and the pipeline failed before deployment.

Root Cause

Runtime variables had been declared as empty values inside the top-level
Declarative Pipeline environment block.

Examples:

AWS_ACCOUNT_ID = ''
ECR_REGISTRY   = ''
IMAGE_TAG      = ''
IMAGE_URI      = ''

The runtime assignments did not behave as intended during pipeline
execution.

Fix Applied

Only static configuration values were retained in the main environment
block:

environment {
    AWS_REGION      = 'ap-south-1'
    ECR_REPOSITORY  = 'devops-eks-app'

    EKS_CLUSTER     = 'devops-eks-dev-cluster'
    K8S_NAMESPACE   = 'devops-app'

    DEPLOYMENT_NAME = 'devops-eks-app'
    CONTAINER_NAME  = 'devops-eks-app'
    SERVICE_NAME    = 'devops-eks-app'
}

Dynamic variables are now created during runtime using env.*.

Examples:

env.AWS_ACCOUNT_ID
env.ECR_REGISTRY
env.GIT_SHORT_SHA
env.IMAGE_TAG
env.IMAGE_URI
env.PREVIOUS_IMAGE
env.DEPLOY_REQUIRED
env.DEPLOYMENT_ATTEMPTED

After this fix, all dynamic values were generated correctly.

Docker Build Validation

The following application image was successfully built:

743610859738.dkr.ecr.ap-south-1.amazonaws.com/devops-eks-app:7-93045ac

Docker build result:

Successfully built
Successfully tagged
Amazon ECR Push Validation

Jenkins authenticated with Amazon ECR using:

aws ecr get-login-password

A temporary Docker configuration directory was used inside the Jenkins
workspace.

The image was successfully pushed to:

743610859738.dkr.ecr.ap-south-1.amazonaws.com/devops-eks-app:7-93045ac

Image digest was successfully generated after the push.

Previous Healthy Image Capture

Before modifying the Kubernetes Deployment, Jenkins records the currently
running application image.

Previous healthy image during the test:

743610859738.dkr.ecr.ap-south-1.amazonaws.com/devops-eks-app:5-f537515

This image can be used by the automatic rollback logic if a deployment
fails after the rollout starts.

Kubernetes Deployment

New image deployed:

743610859738.dkr.ecr.ap-south-1.amazonaws.com/devops-eks-app:7-93045ac

Jenkins executed the deployment using:

kubectl set image \
  deployment/devops-eks-app \
  devops-eks-app=<NEW_IMAGE> \
  -n devops-app

Rollout verification:

kubectl rollout status \
  deployment/devops-eks-app \
  -n devops-app \
  --timeout=180s

Result:

deployment "devops-eks-app" successfully rolled out
Deployment Verification

Final Deployment state:

READY       : 2/2
UP-TO-DATE  : 2
AVAILABLE   : 2

Both application pods were Running.

Jenkins compared the expected Docker image with the actual Kubernetes
Deployment image.

Expected image:

devops-eks-app:7-93045ac

Running image:

devops-eks-app:7-93045ac

Result:

Running image verification successful.
Application Health Verification

Jenkins automatically obtained the Kubernetes LoadBalancer hostname and
tested the application.

Health endpoint:

/health

Result:

{"status":"healthy"}

Readiness endpoint:

/ready

Result:

{"status":"ready"}

Both checks passed successfully.

Deployment Change Cause

The Jenkins pipeline now adds deployment information using:

kubectl annotate deployment/devops-eks-app \
  kubernetes.io/change-cause="Jenkins build <BUILD>: <IMAGE>"

The Kubernetes rollout history now contains Jenkins build information.

Example:

Jenkins build 7:
743610859738.dkr.ecr.ap-south-1.amazonaws.com/devops-eks-app:7-93045ac

This improves deployment traceability.

HPA Validation During Pipeline

The Horizontal Pod Autoscaler remained active after the deployment.

Observed state:

Minimum Pods : 2
Maximum Pods : 10
CPU Target   : 60%
Replicas     : 2
Automatic Rollback Logic

Automatic rollback logic was added to the Jenkinsfile.

The pipeline performs the following logic:

Capture Previous Healthy Image
        ↓
Deploy New Image
        ↓
Rollout / Verification
        ↓
     Failure?
        ↓
Restore Previous Image
        ↓
Wait for Rollback Rollout
        ↓
Verify Restored Image
        ↓
Check Application Health

The rollback implementation restores the exact value stored in:

PREVIOUS_IMAGE

rather than relying only on Kubernetes revision numbers.

A forced bad-release test for this Jenkins automatic rollback logic was
not performed as part of Task 2.

The rollback logic remains configured in the Jenkinsfile for future
deployment failures.

Pipeline Cleanup

The pipeline performs cleanup in the post -> always section.

Actions include:

Docker ECR logout
Temporary .docker directory removal
Python virtual environment removal
Locally built Docker image removal
Unused Docker image pruning

During the successful pipeline run, the Docker credentials were removed
from the Jenkins workspace and the locally built application image was
deleted.

Operational Issue Encountered During Validation

During Task 2 validation, the Jenkins EC2 instance was found in a stopped
state.

Observed state:

EC2 State  : stopped
Public IP  : None
Private IP : 10.0.1.98

The Jenkinsfile was not responsible for stopping the EC2 instance.

The EC2 instance was started again and received a new public IP:

52.66.135.163

Jenkins returned:

HTTP/1.1 200 OK

after the instance was started.

Because the instance does not currently use a static Elastic IP, its
public IP can change after stop/start.

The GitHub webhook URL and Ansible inventory therefore need to reference
the current Jenkins public IP.

This infrastructure improvement can be handled separately during final
infrastructure hardening.

Final CI/CD Flow
Developer Git Push
        ↓
GitHub Webhook
        ↓
Jenkins
        ↓
Checkout
        ↓
Detect Changes
        ↓
Unit Tests
        ↓
Generate Dynamic Image Tag
        ↓
Docker Build
        ↓
ECR Authentication
        ↓
Push Image to ECR
        ↓
Configure EKS
        ↓
Capture Previous Healthy Image
        ↓
Deploy New Image
        ↓
Kubernetes Rollout Verification
        ↓
Running Image Verification
        ↓
Health Check
        ↓
Readiness Check
        ↓
Deployment Summary
        ↓
Pipeline Cleanup
Final Validation Result
GitHub webhook trigger          : PASS
Correct Git commit checkout     : PASS
Change detection                : PASS
Unit tests                      : PASS
Dynamic AWS account discovery   : PASS
Dynamic image tagging           : PASS
Docker image build              : PASS
Amazon ECR push                 : PASS
Previous image capture          : PASS
EKS rollout                     : PASS
Running image verification      : PASS
Health endpoint                 : PASS
Readiness endpoint              : PASS
Deployment change-cause         : PASS
HPA remained healthy            : PASS
Temporary credential cleanup    : PASS
Docker image cleanup            : PASS



