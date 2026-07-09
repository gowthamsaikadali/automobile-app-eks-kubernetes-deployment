variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "eks_cluster_security_group_id" {
  description = "The EKS cluster/node shared security group, used to allow DB access only from the cluster"
  type        = string
}

variable "db_name" {
  type    = string
  default = "autoforge"
}

variable "db_username" {
  type    = string
  default = "autoforge_admin"
}

variable "db_password" {
  description = "Master password for RDS. Keep this out of source control - pass via -var or TF_VAR_db_password env var."
  type        = string
  sensitive   = true
}

variable "instance_class" {
  description = "RDS instance size. db.t3.micro is the smallest/cheapest MySQL-compatible class."
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "engine_version" {
  type    = string
  default = "8.0"
}

variable "multi_az" {
  type    = bool
  default = false
}

variable "skip_final_snapshot" {
  type    = bool
  default = true
}

variable "backup_retention_period" {
  description = "Days to retain automated backups. 0 disables backups, saving a little cost/complexity for a demo project."
  type        = number
  default     = 0
}
