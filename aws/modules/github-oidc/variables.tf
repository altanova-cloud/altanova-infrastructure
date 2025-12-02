variable "github_org" {
  description = "GitHub organization name"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (without org prefix)"
  type        = string
}

variable "role_name" {
  description = "Name of the IAM role for GitHub Actions"
  type        = string
  default     = "GitHubActionsRole"
}

variable "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider (already created in AWS)"
  type        = string
}

variable "state_bucket_arn" {
  description = "ARN of the S3 bucket for Terraform state"
  type        = string
}

variable "state_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  type        = string
}

variable "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table for state locking"
  type        = string
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table for state locking"
  type        = string
}

variable "state_access_role_arn" {
  description = "ARN of the TerraformStateAccessRole for cross-account state access"
  type        = string
}

variable "additional_policy_arns" {
  description = "Additional IAM policy ARNs to attach to the role"
  type        = list(string)
  default     = []
}

variable "restrict_to_branch" {
  description = "Restrict OIDC authentication to a specific branch (e.g., 'master'). Set to empty string for no restriction."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
