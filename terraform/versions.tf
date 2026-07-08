terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Remote state (S3 + DynamoDB lock table).
  # IMPORTANT: create the bucket and DynamoDB table FIRST (see scripts/bootstrap-backend.ps1),
  # then uncomment this block and run `terraform init` again.
  backend "s3" {
  bucket         = "gowthamautoforgetfstate34"
  key            = "eks/terraform.tfstate"
  region         = "ap-south-1"
  dynamodb_table = "autoforge-tf-lock"
  encrypt        = true
   }
}
