terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

module "deployment_role" {
  source = "../../modules/deployment-role"

  environment            = "prod"
  gitlab_runner_role_arn = var.gitlab_runner_role_arn
  state_access_role_arn  = var.state_access_role_arn
}

output "deploy_role_arn" {
  description = "ARN of the Prod deployment role"
  value       = module.deployment_role.role_arn
}

output "deploy_role_name" {
  description = "Name of the Prod deployment role"
  value       = module.deployment_role.role_name
}
