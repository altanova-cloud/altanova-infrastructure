variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "gitlab_runner_role_arn" {
  description = "ARN of GitLab Runner role in Shared Account"
  type        = string
}

variable "state_access_role_arn" {
  description = "ARN of Terraform State Access role in Shared Account"
  type        = string
}
