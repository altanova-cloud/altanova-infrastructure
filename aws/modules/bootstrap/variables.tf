variable "bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  type        = string
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table for state locking"
  type        = string
}

variable "dev_account_id" {
  description = "AWS Account ID for the Development environment"
  type        = string
}

variable "prod_account_id" {
  description = "AWS Account ID for the Production environment"
  type        = string
}

variable "gitlab_url" {
  description = "URL of the GitLab instance (e.g., https://gitlab.com)"
  type        = string
  default     = "https://gitlab.com"
}

variable "gitlab_project_path" {
  description = "Path of the GitLab project (group/project) for OIDC trust"
  type        = string
}
