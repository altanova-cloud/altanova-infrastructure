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

# Inline policy to allow GitHubActionsRole to assume Dev/Prod deploy roles
resource "aws_iam_role_policy" "cross_account_assume" {
  name = "CrossAccountAssume"
  role = module.github_oidc.role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
      Resource = [
        "arn:aws:iam::${var.dev_account_id}:role/DevDeployRole",
        "arn:aws:iam::${var.prod_account_id}:role/ProdDeployRole"
      ]
    }]
  })
}

# GitLab OIDC Identity Provider
resource "aws_iam_openid_connect_provider" "gitlab" {
  url             = "https://gitlab.com"
  client_id_list  = ["https://gitlab.com"]
  thumbprint_list = ["2b8f1b57330dbba2d07a6c51f70ee90ddab9ad8e"]

  tags = {
    Environment = "shared"
    ManagedBy   = "Terraform"
    Purpose     = "GitLab CI/CD OIDC"
  }
}

# GitLab Runner Role (for GitLab CI/CD)
# Trusts GitLab OIDC tokens with audience "sts.amazonaws.com" (standard for AWS STS)
resource "aws_iam_role" "gitlab_runner" {
  name = "GitLabRunnerRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.gitlab.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
    }]
  })

  tags = {
    Environment = "shared"
    ManagedBy   = "Terraform"
    Purpose     = "GitLab CI/CD"
  }
}

# Policy to allow GitLabRunnerRole to assume Dev/Prod deploy roles
resource "aws_iam_role_policy" "gitlab_cross_account_assume" {
  name = "GitLabCrossAccountAssume"
  role = aws_iam_role.gitlab_runner.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
      Resource = [
        "arn:aws:iam::${var.dev_account_id}:role/DevDeployRole",
        "arn:aws:iam::${var.prod_account_id}:role/ProdDeployRole"
      ]
    }]
  })
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

output "gitlab_oidc_provider_arn" {
  description = "ARN of the GitLab OIDC provider"
  value       = aws_iam_openid_connect_provider.gitlab.arn
}

output "gitlab_runner_role_arn" {
  description = "ARN of the GitLab Runner IAM role"
  value       = aws_iam_role.gitlab_runner.arn
}

output "gitlab_runner_role_name" {
  description = "Name of the GitLab Runner IAM role"
  value       = aws_iam_role.gitlab_runner.name
}
