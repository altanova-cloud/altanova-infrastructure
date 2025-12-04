provider "aws" {
  region = var.region
}

module "bootstrap" {
  source = "../../modules/bootstrap"

  bucket_name         = var.state_bucket_name
  dynamodb_table_name = var.lock_table_name
  dev_account_id      = var.dev_account_id
  prod_account_id     = var.prod_account_id
}

# GitHub OIDC module for GitHub Actions authentication
module "github_oidc" {
  source = "../../modules/github-oidc"

  github_org        = var.github_org
  github_repo       = var.github_repo
  role_name         = "GitHubActionsRole"
  oidc_provider_arn = var.github_oidc_provider_arn

  state_bucket_arn      = module.bootstrap.s3_bucket_arn
  state_bucket_name     = var.state_bucket_name
  dynamodb_table_arn    = module.bootstrap.dynamodb_table_arn
  dynamodb_table_name   = var.lock_table_name
  state_access_role_arn = module.bootstrap.cross_account_role_arn

  restrict_to_branch = ""

  tags = {
    Environment = "shared"
    ManagedBy   = "Terraform"
    Purpose     = "GitHub Actions CI/CD"
  }
}

output "state_bucket_arn" {
  value = module.bootstrap.s3_bucket_arn
}

output "lock_table_arn" {
  value = module.bootstrap.dynamodb_table_arn
}

output "cross_account_role_arn" {
  value = module.bootstrap.cross_account_role_arn
}

output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions IAM role"
  value       = module.github_oidc.role_arn
}

output "github_actions_role_name" {
  description = "Name of the GitHub Actions IAM role"
  value       = module.github_oidc.role_name
}
