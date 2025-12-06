# Prod Environment - IAM Resources
# Deployment role for CI/CD pipeline

module "deployment_role" {
  source = "../../modules/deployment-role"

  environment             = local.environment
  github_actions_role_arn = var.github_actions_role_arn
  state_access_role_arn   = var.state_access_role_arn
}
