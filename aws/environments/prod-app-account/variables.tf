# Prod Environment - Variables
# IAM role ARNs for cross-account access

variable "state_access_role_arn" {
  description = "ARN of Terraform State Access role in Shared Account"
  type        = string
  default     = "arn:aws:iam::265245191272:role/TerraformStateAccessRole"
}

variable "gitlab_runner_role_arn" {
  description = "ARN of GitLab Runner role in Shared Account"
  type        = string
  default     = "arn:aws:iam::265245191272:role/GitLabRunnerRole"
}
