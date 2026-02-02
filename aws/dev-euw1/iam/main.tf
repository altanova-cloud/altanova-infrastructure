# =============================================================================
# IAM - Dev Account (eu-west-1)
# =============================================================================
# State: dev-euw1-iam
# =============================================================================

terraform {
  required_version = ">= 1.8"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "http" {}
}

locals {
  environment = "dev"
  region      = "eu-west-1"

  # Shared account IAM roles
  gitlab_runner_role_arn = "arn:aws:iam::265245191272:role/GitLabRunnerRole"
  state_access_role_arn  = "arn:aws:iam::265245191272:role/TerraformStateAccessRole"
}

provider "aws" {
  region = local.region

  default_tags {
    tags = {
      Environment = local.environment
      Region      = local.region
      ManagedBy   = "Terraform"
      Project     = "AltaNova"
    }
  }
}

module "deployment_role" {
  source = "../../modules/deployment-role"

  environment            = local.environment
  gitlab_runner_role_arn = local.gitlab_runner_role_arn
  state_access_role_arn  = local.state_access_role_arn
  additional_policies    = []
}

# =============================================================================
# Outputs
# =============================================================================
output "deployment_role_arn" {
  description = "ARN of the deployment role"
  value       = module.deployment_role.role_arn
}

output "deployment_role_name" {
  description = "Name of the deployment role"
  value       = module.deployment_role.role_name
}
