# =============================================================================
# IAM - Workspace-based Deployment Roles
# =============================================================================
#
# Uses Terraform workspaces for environment + region separation.
#
# Workspace naming: {env}-{region_code}
#   - dev-euw1   (Dev in eu-west-1)
#   - prod-euw1  (Prod in eu-west-1)
#
# Usage:
#   terraform workspace new dev-euw1
#   terraform workspace select dev-euw1
#   terraform plan
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

# =============================================================================
# Workspace Configuration
# =============================================================================
locals {
  # Parse workspace: "dev-euw1" -> env="dev", region_code="euw1"
  workspace_parts = split("-", terraform.workspace)
  environment     = local.workspace_parts[0]
  region_code     = local.workspace_parts[1]

  # Region mapping
  region_map = {
    euw1 = "eu-west-1"
    euw2 = "eu-west-2"
    eus2 = "eu-south-2" # Spain
    use1 = "us-east-1"
    use2 = "us-east-2"
  }
  region = local.region_map[local.region_code]

  # Shared account IAM roles
  gitlab_runner_role_arn = "arn:aws:iam::265245191272:role/GitLabRunnerRole"
  state_access_role_arn  = "arn:aws:iam::265245191272:role/TerraformStateAccessRole"
}

# =============================================================================
# Provider
# =============================================================================
provider "aws" {
  region = local.region

  default_tags {
    tags = {
      Environment = local.environment
      Region      = local.region
      ManagedBy   = "Terraform"
      Project     = "AltaNova"
      Workspace   = terraform.workspace
    }
  }
}

# =============================================================================
# Deployment Role Module
# =============================================================================
module "deployment_role" {
  source = "../modules/deployment-role"

  environment            = local.environment
  gitlab_runner_role_arn = local.gitlab_runner_role_arn
  state_access_role_arn  = local.state_access_role_arn
  additional_policies    = []
}

# =============================================================================
# Outputs
# =============================================================================
output "workspace" {
  description = "Current workspace"
  value       = terraform.workspace
}

output "environment" {
  description = "Environment"
  value       = local.environment
}

output "region" {
  description = "AWS Region"
  value       = local.region
}

output "deployment_role_arn" {
  description = "ARN of the deployment role"
  value       = module.deployment_role.role_arn
}

output "deployment_role_name" {
  description = "Name of the deployment role"
  value       = module.deployment_role.role_name
}
