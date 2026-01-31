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

# Note: domain_name and route53_zone_id are only used in Shared account
# Prod uses only VPC and IAM infrastructure
