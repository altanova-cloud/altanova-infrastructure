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

# GitLab Runner Role (for GitLab CI/CD)
# References manually-created GitLab OIDC provider at https://gitlab.com
# OIDC provider ARN: arn:aws:iam::265245191272:oidc-provider/gitlab.com
resource "aws_iam_role" "gitlab_runner" {
  name = "GitLabRunnerRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = "arn:aws:iam::265245191272:oidc-provider/gitlab.com"
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

output "gitlab_runner_role_arn" {
  description = "ARN of the GitLab Runner IAM role"
  value       = aws_iam_role.gitlab_runner.arn
}

output "gitlab_runner_role_name" {
  description = "Name of the GitLab Runner IAM role"
  value       = aws_iam_role.gitlab_runner.name
}
