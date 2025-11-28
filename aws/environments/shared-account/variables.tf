variable "region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "dev_account_id" {
  description = "AWS Account ID for the Development environment"
  type        = string
}

variable "prod_account_id" {
  description = "AWS Account ID for the Production environment"
  type        = string
}

variable "gitlab_project_path" {
  description = "Path of the GitLab project (group/project) for OIDC trust"
  type        = string
}

variable "state_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  type        = string
}

variable "lock_table_name" {
  description = "Name of the DynamoDB table for state locking"
  type        = string
}
