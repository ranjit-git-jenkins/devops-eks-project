variable "aws_region" {
  description = "AWS region for the project"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "devops-eks"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_1_cidr" {
  description = "CIDR for public subnet in first AZ"
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_2_cidr" {
  description = "CIDR for public subnet in second AZ"
  type        = string
  default     = "10.0.2.0/24"
}

variable "private_subnet_1_cidr" {
  description = "CIDR for private subnet in first AZ"
  type        = string
  default     = "10.0.11.0/24"
}

variable "private_subnet_2_cidr" {
  description = "CIDR for private subnet in second AZ"
  type        = string
  default     = "10.0.12.0/24"
}

variable "jenkins_instance_type" {
  description = "EC2 instance type for Jenkins"
  type        = string
  default     = "t3.medium"
}

variable "jenkins_admin_cidr" {
  description = "CIDR allowed to access Jenkins SSH and Web UI"
  type        = string
}

variable "jenkins_public_key_path" {
  description = "Local SSH public key path for Jenkins EC2"
  type        = string
  default     = "~/.ssh/devops-jenkins.pub"
}

variable "github_webhook_cidrs" {
  description = "GitHub IPv4 CIDRs allowed to deliver Jenkins webhooks"
  type        = list(string)
  default     = []
}
variable "jenkins_ami_id" {
  description = "Pinned AMI ID for Jenkins EC2 instance"
  type        = string
  default     = "ami-0c0fd09cfe77b59dc"
}
variable "eks_public_access_cidrs" {
  description = "CIDR blocks allowed to access the EKS public API endpoint"
  type        = list(string)
}
