terraform {
  required_version = ">= 1.10.0"

  backend "s3" {
    bucket       = "devops-eks-tfstate-743610859738-ap-south-1"
    key          = "devops-eks-project/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
