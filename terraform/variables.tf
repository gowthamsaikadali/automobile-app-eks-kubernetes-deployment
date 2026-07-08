variable "project_name" {
  description = "Short project name used to prefix resource names"
  type        = string
  default     = "autoforge"
}

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-south-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "cluster_name" {
  type    = string
  default = "autoforge-eks"
}

variable "cluster_version" {
  type    = string
  default = "1.30"
}

variable "node_instance_types" {
  description = "Free-trial friendly instance type. t3.micro has only 1GB RAM; keep pod resource requests small."
  type        = list(string)
  default     = ["t3.micro"]
}

variable "node_desired_size" {
  type    = number
  default = 1
}

variable "node_min_size" {
  type    = number
  default = 1
}

variable "node_max_size" {
  type    = number
  default = 2
}

variable "github_oidc_repo" {
  description = "GitHub repo allowed to assume the CI/CD IAM role, format: your-github-username/your-repo-name. Leave empty to skip creating the GitHub OIDC role."
  type        = string
  default     = ""
}
