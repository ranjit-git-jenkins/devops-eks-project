# DevOps EKS Project

End-to-end DevOps project demonstrating infrastructure provisioning,
containerization, Kubernetes deployment, CI/CD automation, monitoring,
alerting, and secure AWS integration.

## Architecture

```text
Developer
   |
   v
GitHub
   |
   v
Jenkins
   |
   +--> Unit Testing
   |
   +--> Docker Build
   |
   +--> Amazon ECR
   |
   v
Amazon EKS
   |
   +--> Kubernetes Deployment
   +--> LoadBalancer Service
   +--> Horizontal Pod Autoscaler
   |
   v
Prometheus + Grafana + Alertmanager

## Technologies Used

AWS
Amazon EKS
Amazon ECR
Terraform
Ansible
Jenkins
Docker
Kubernetes
Python Flask
Prometheus
Grafana
Alertmanager
Git and GitHub
Project Components
Application

Python Flask application providing:

Application endpoint
Health endpoint
Readiness endpoint
Prometheus metrics endpoint
Unit tests using pytest
Docker

The application is containerized using Docker and runs with Gunicorn.

Prometheus multiprocess support is configured for Gunicorn workers.

## Terraform

Terraform provisions:

VPC
Public and private subnets
Internet Gateway
NAT Gateway
Route tables
Amazon EKS cluster
EKS managed node group
IAM roles
Jenkins EC2 instance
Security groups
EKS access entry

Terraform state is stored remotely in Amazon S3.

## Kubernetes

The application is deployed to Amazon EKS using:

Namespace
Deployment
LoadBalancer Service
Liveness probe
Readiness probe
Resource requests and limits
Horizontal Pod Autoscaler

The HPA scales the application between:

Minimum Pods: 2
Maximum Pods: 10
CPU Target:   60%

## Jenkins

Jenkins runs on a dedicated EC2 instance.

The Jenkins server is configured using Ansible with:

Java
Jenkins
Docker
AWS CLI
kubectl
Git

Jenkins uses an EC2 IAM instance role instead of static AWS credentials.

## AWS IAM Security
Jenkins authenticates to AWS using:

EC2
 |
 v
IAM Instance Profile
 |
 v
Temporary AWS Credentials

No AWS access key or secret key is stored on the Jenkins server.

Jenkins has namespace-scoped access to the Kubernetes devops-app namespace.

Cluster-wide access is intentionally restricted.

## Monitoring
Monitoring is implemented using the kube-prometheus-stack.

Components include:

Prometheus
Grafana
Alertmanager
kube-state-metrics
Node Exporter

Custom application metrics are collected using a Kubernetes ServiceMonitor.

## Grafana Dashboard
The dashboard monitors:

Application request rate
Application availability
Running pods
Pod CPU usage
Pod memory usage
Total application requests

## Prometheus Alerts
Configured alerts include:

Application Down
High CPU Usage
Low Replica Count

Alerts are routed to Alertmanager.

## CI/CD Flow

GitHub
   |
   v
Jenkins
   |
   v
Run Unit Tests
   |
   v
Docker Build
   |
   v
Push Image to Amazon ECR
   |
   v
Update Kubernetes Deployment
   |
   v
EKS Rolling Update
   |
   v
Application Verification

## Repository Structure

'''text

devops-eks-project/
├── ansible/
├── app/
├── docker/
├── kubernetes/
├── monitoring/
├── scripts/
├── terraform/
├── .gitignore
└── README.md
'''

## Security Practices

AWS credentials are not stored in the repository
Terraform state files are excluded from Git
Terraform variable files are excluded from Git
SSH private keys are excluded from Git
Jenkins inventory containing runtime IP information is excluded
Jenkins uses an IAM instance role
Jenkins Kubernetes access is namespace scoped
Jenkins SSH and Web UI access are restricted using security groups


## Author
Ranjit Kumar Shrivastava

