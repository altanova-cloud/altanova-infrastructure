variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Environment must be either 'dev' or 'prod'."
  }
}

variable "github_actions_role_arn" {
  description = "ARN of GitHub Actions role in Shared Account that will assume this role"
  type        = string
}

variable "state_access_role_arn" {
  description = "ARN of Terraform State Access role in Shared Account"
  type        = string
}

variable "additional_policies" {
  description = "Additional IAM policy ARNs to attach to the deployment role"
  type        = list(string)
  default     = []
}
