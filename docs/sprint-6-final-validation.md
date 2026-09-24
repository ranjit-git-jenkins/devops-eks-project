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






---

## Task 3 - ECR and Docker Cleanup & Hardening

### Status

**COMPLETE**

### Objective

The objective of this task was to harden the Amazon ECR and Jenkins Docker build workflow, implement automated image cleanup, remove persistent Docker credentials, enable Docker Buildx/BuildKit, and validate the complete CI/CD deployment flow.

### 1. ECR Repository Audit

The existing Amazon ECR repository was reviewed.

Repository:

`devops-eks-app`

Validated configuration:

- Image scanning on push: Enabled
- Encryption: AES256
- Image tags generated dynamically by Jenkins
- Existing repository contained both tagged and untagged images

### 2. ECR Lifecycle Policy

An ECR lifecycle policy was added and managed through Terraform.

File:

`terraform/ecr.tf`

Lifecycle rules:

- Untagged images older than 7 days are expired automatically.
- Only the latest 30 images are retained.

This prevents unnecessary accumulation of old CI/CD images in ECR.

Validation command:

`aws ecr get-lifecycle-policy --repository-name devops-eks-app --region ap-south-1`

The lifecycle policy was successfully verified in AWS.

### 3. Terraform Jenkins AMI Safety

During the initial Terraform validation, Terraform attempted to replace the existing Jenkins EC2 instance because the Jenkins AMI was selected using a `most_recent` Ubuntu AMI data source.

The existing Jenkins instance was using:

`ami-0c0fd09cfe77b59dc`

A newer Ubuntu AMI caused Terraform to detect a replacement.

To prevent an unexpected Jenkins server replacement, the Jenkins AMI was pinned using the Terraform variable:

`jenkins_ami_id`

The Jenkins EC2 resource now references:

`ami = var.jenkins_ami_id`

Final Terraform validation result:

`No changes. Your infrastructure matches the configuration.`

No Jenkins replacement or infrastructure destruction was required.

### 4. Docker Credential Cleanup

A persistent Docker configuration was found on the Jenkins server:

`/var/lib/jenkins/.docker/config.json`

The file contained an authentication entry for the Amazon ECR registry.

The hardened Jenkins pipeline already uses a temporary workspace-level Docker configuration during ECR authentication and removes it during pipeline cleanup.

Therefore, the old permanent Docker credential file was removed.

A search under `/var/lib/jenkins` confirmed that no persistent `config.json` credential file remained.

### 5. Docker Buildx Installation

Docker Buildx was added to the Jenkins Ansible role:

`ansible/roles/jenkins/tasks/main.yml`

Package:

`docker-buildx`

The Jenkins Ansible playbook completed successfully with:

- unreachable=0
- failed=0

Installed Buildx version:

`0.30.1`

BuildKit version:

`v0.26.2`

The default Docker builder was confirmed to be running.

### 6. Buildx Smoke Test

A temporary Alpine Docker image was built using:

`docker buildx build --load`

The image was successfully loaded into the local Docker image store, inspected, and removed.

Result:

`BUILDX SMOKE TEST PASSED`

This confirmed that Buildx and BuildKit were functioning correctly on the Jenkins server.

### 7. Jenkins Pipeline Docker Build Hardening

The Jenkins pipeline was migrated from the legacy Docker build command:

`docker build`

to:

`docker buildx build --load`

The `--load` option is required because the following pipeline stage pushes the locally built image to Amazon ECR.

Updated flow:

GitHub Push
→ Jenkins Webhook
→ Checkout
→ Unit Tests
→ Dynamic Image Tag
→ Docker Buildx / BuildKit Build
→ ECR Login
→ ECR Push
→ EKS Deployment
→ Rollout Verification
→ Health Check
→ Readiness Check
→ Cleanup

### 8. Git Commit

The Task 3 hardening changes were committed as:

`6fede60 Harden ECR lifecycle and Jenkins Docker builds`

The commit included:

- Jenkinsfile Buildx migration
- Ansible Buildx package configuration
- ECR lifecycle policy
- Jenkins AMI pinning
- Terraform variable updates

### 9. End-to-End Deployment Validation

After pushing the changes to GitHub, the CI/CD pipeline built and deployed a new image:

`743610859738.dkr.ecr.ap-south-1.amazonaws.com/devops-eks-app:9-6fede60`

Kubernetes deployment status:

- Desired replicas: 2
- Ready replicas: 2
- Available replicas: 2
- Pods: Running
- HPA minimum replicas: 2
- HPA maximum replicas: 10
- CPU target: 60%
- Observed CPU during validation: 1%

Application endpoint validation:

`/health` → `{"status":"healthy"}`

`/ready` → `{"status":"ready"}`

### Final Result

Task 3 ECR and Docker Cleanup & Hardening was successfully completed.

The project now includes:

- Automated ECR image lifecycle management
- ECR image scanning on push
- Encrypted ECR storage
- Dynamic immutable-style CI build tags
- No persistent ECR Docker authentication file on Jenkins
- Docker Buildx and BuildKit based builds
- Ansible-managed Buildx installation
- Jenkins AMI pinning to prevent accidental EC2 replacement
- Verified Terraform state consistency
- Successful EKS deployment
- Successful health and readiness validation





---

## Task 4 - Terraform Final Validation & Infrastructure Hardening

### Objective

Validate the final Terraform-managed AWS infrastructure, identify and recover infrastructure drift safely, and apply additional security hardening without replacing existing production resources.

### 1. Terraform Backend and State Validation

The Terraform remote backend was revalidated successfully.

Backend configuration:

- Amazon S3 remote backend
- State locking enabled through S3 lockfile
- Server-side encryption enabled
- S3 bucket versioning enabled
- Public access blocked
- Terraform initialization completed successfully
- Terraform configuration validation passed

Validation commands included:

`terraform init`

`terraform fmt -check -recursive`

`terraform validate`

The remote Terraform state object was confirmed to exist and use server-side AES256 encryption.

### 2. Infrastructure Drift Detection

A full Terraform plan detected infrastructure changes that had occurred outside Terraform.

The following drift was identified:

- NAT Gateway had been deleted
- NAT Gateway Elastic IP had been deleted
- Private route table default route was pointing to the deleted NAT Gateway and was in blackhole state
- Jenkins EC2 instance was stopped
- Jenkins public IP had changed after the EC2 stop/start lifecycle

The initial full Terraform plan also showed a possible Jenkins EC2 replacement.

The full plan was intentionally not applied because replacing the existing Jenkins server would have risked losing the configured CI/CD environment.

### 3. NAT Gateway Recovery

The NAT infrastructure was recovered using a controlled targeted Terraform operation.

The targeted recovery included:

- NAT Elastic IP creation
- NAT Gateway creation
- Private route table repair

Recovery plan result:

`2 to add, 1 to change, 0 to destroy`

After the recovery:

- NAT Gateway status: Available
- Private default route status: Active
- Private EKS nodes regained outbound connectivity
- No Jenkins or EKS resources were destroyed

The targeted Terraform operation was used only as an exceptional recovery procedure.

### 4. EKS Node Group Validation

After NAT recovery, the EKS managed node group was validated.

Node group state:

- Status: ACTIVE
- Capacity type: ON_DEMAND
- Instance type: t3.medium
- Minimum nodes: 1
- Desired nodes: 2
- Maximum nodes: 3
- Health issues: None

Two EC2 worker instances were confirmed:

- InService
- Healthy

Kubernetes validation confirmed:

- 2 worker nodes Ready
- No unhealthy cluster pods
- Application deployment 2/2 available
- HPA operating normally

### 5. Application Validation

The application remained healthy after infrastructure recovery.

Application deployment:

- Ready replicas: 2
- Available replicas: 2
- HPA minimum replicas: 2
- HPA maximum replicas: 10
- CPU target: 60%

Application endpoint validation:

`/health` → `{"status":"healthy"}`

`/ready` → `{"status":"ready"}`

This confirmed that the infrastructure recovery did not impact application availability.

### 6. Jenkins EC2 Preservation

The existing Jenkins EC2 instance was started and validated instead of being recreated.

The instance retained:

- Same EC2 instance ID
- Same private IP
- Existing Jenkins configuration
- Existing Docker installation
- Existing Buildx installation
- Existing IAM instance profile

After the instance was running, a fresh Terraform plan no longer requested Jenkins replacement.

This prevented unnecessary recreation of the CI/CD server.

### 7. Jenkins Elastic IP Hardening

A Terraform-managed Elastic IP was added to provide Jenkins with a stable public address.

Terraform resources added:

`aws_eip.jenkins`

`aws_eip_association.jenkins`

The existing Jenkins EC2 instance was preserved.

Terraform apply result:

`2 added, 0 changed, 0 destroyed`

Terraform outputs were updated to use the Jenkins Elastic IP and its associated public DNS name.

Benefits:

- Jenkins public IP remains stable after EC2 stop/start operations
- Ansible inventory no longer needs repeated public IP updates
- GitHub webhook URL remains stable
- Existing Jenkins server is preserved

### 8. Jenkins Security Group Validation

The Jenkins security group was reviewed and validated.

Inbound access:

- SSH TCP/22 restricted to the trusted administrator /32 CIDR
- Jenkins TCP/8080 restricted to the trusted administrator /32 CIDR
- GitHub webhook access allowed only from configured GitHub webhook CIDR ranges

Outbound access remains enabled for required package repositories, AWS APIs, ECR, EKS, and other external dependencies.

The previous administrator IP drift was corrected through Terraform.

Jenkins external access was validated successfully:

`HTTP/1.1 200 OK`

### 9. Jenkins Service Validation

Jenkins was validated internally using AWS Systems Manager and externally using the Elastic IP.

Verified:

- SSM Agent: Online
- Jenkins service: Active
- Docker service: Active
- Jenkins TCP/8080: Listening
- Jenkins local login endpoint: HTTP 200
- Jenkins external login endpoint: HTTP 200
- Docker Buildx: Available

Ansible connectivity using the permanent Jenkins Elastic IP also succeeded:

`ping: pong`

### 10. EC2 Metadata Security

The Jenkins EC2 Instance Metadata Service configuration was audited.

Validated settings:

- Metadata endpoint: enabled
- IMDSv2 token requirement: required
- HTTP PUT response hop limit: 2
- Metadata configuration state: applied

This confirms that IMDSv2 is enforced for the Jenkins EC2 instance.

### 11. EKS API Endpoint Hardening

The EKS API endpoint originally allowed public access from:

`0.0.0.0/0`

A dedicated Terraform variable was added:

`eks_public_access_cidrs`

The EKS public API endpoint was restricted to the trusted administrator /32 CIDR.

Final endpoint configuration:

- Public endpoint: Enabled
- Private endpoint: Enabled
- Public access: Restricted to trusted administrator CIDR

Terraform updated the EKS cluster in place.

Plan result:

`0 to add, 1 to change, 0 to destroy`

No EKS node group or application resources were recreated.

### 12. Jenkins to EKS Private Access Validation

After EKS public endpoint hardening, Jenkins-to-EKS access was tested.

Jenkins successfully executed:

`kubectl auth can-i get pods -n devops-app`

Result:

`yes`

Jenkins also successfully listed the application pods in the `devops-app` namespace.

This confirms that Jenkins can continue accessing EKS through the VPC/private endpoint while external public API access remains restricted.

### 13. Stable GitHub Webhook Validation

The GitHub webhook was updated to use the permanent Jenkins Elastic IP.

Webhook endpoint:

`http://<JENKINS_EIP>:8080/github-webhook/`

A GitHub webhook redelivery was performed after the update.

Validation result:

- Event: push
- Request method: POST
- Response: HTTP 200
- Delivery: Successful

This confirms that GitHub can successfully trigger Jenkins through the new permanent endpoint.

### 14. Terraform Reproducibility

A new example Terraform variable file was added:

`terraform/terraform.tfvars.example`

The example file documents the required Terraform variables without committing the real local administrator IP or local SSH key path.

The real:

`terraform/terraform.tfvars`

remains ignored by Git.

Validation:

- `terraform fmt -check -recursive` passed
- `terraform validate` passed
- `git diff --check` passed

### 15. Final Terraform Drift Validation

After completing the recovery and hardening work, a final full Terraform plan was executed.

Final result:

`No changes. Your infrastructure matches the configuration.`

This confirms that the Terraform configuration, Terraform remote state, and deployed AWS infrastructure are synchronized.

### Final Result

Task 4 Terraform Final Validation & Infrastructure Hardening was successfully completed.

The environment now includes:

- Validated encrypted remote Terraform state
- S3 versioning and public access protection
- Recovered NAT Gateway connectivity
- Healthy private EKS worker nodes
- Stable Terraform-managed Jenkins Elastic IP
- Restricted Jenkins administrative access
- IMDSv2 enforcement
- Restricted EKS public API endpoint
- Enabled EKS private API endpoint
- Verified Jenkins-to-EKS private connectivity
- Stable GitHub-to-Jenkins webhook integration
- Reproducible Terraform example variables
- Successful application health and readiness checks
- Final Terraform state with zero infrastructure drift
