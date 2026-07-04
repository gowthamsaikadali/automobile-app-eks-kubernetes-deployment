terraform {
  required_version = ">= 1.6.0"

  backend "s3" {
    bucket         = "autoforge-tfstate-bucket"   # must already exist, or bootstrap separately
    key            = "eks/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "autoforge-tf-lock"          # DynamoDB table for state locking
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}
