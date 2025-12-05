variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "github_actions_role_arn" {
  description = "ARN of GitHub Actions role in Shared Account"
  type        = string
  default     = "arn:aws:iam::265245191272:role/GitHubActionsRole"
}

variable "state_access_role_arn" {
  description = "ARN of Terraform State Access role in Shared Account"
  type        = string
}
