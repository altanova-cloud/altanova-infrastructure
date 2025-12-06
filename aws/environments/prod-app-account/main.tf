terraform {
}

module "deployment_role" {
  source = "../../modules/deployment-role"

  environment             = "prod"
  github_actions_role_arn = var.github_actions_role_arn
  state_access_role_arn   = var.state_access_role_arn
}

output "deploy_role_arn" {
  description = "ARN of the Prod deployment role"
  value       = module.deployment_role.role_arn
}

output "deploy_role_name" {
  description = "Name of the Prod deployment role"
  value       = module.deployment_role.role_name
}
