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
