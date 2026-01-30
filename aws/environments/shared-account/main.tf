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

# GitLab Runner Role is manually created with:
# - Trust policy for https://gitlab.com OIDC provider
# - Inline policy allowing assume of DevDeployRole and ProdDeployRole
# ARN: arn:aws:iam::265245191272:role/GitLabRunnerRole
# Managed manually - not in Terraform code

output "state_bucket_arn" {
  value = module.bootstrap.s3_bucket_arn
}

output "lock_table_arn" {
  value = module.bootstrap.dynamodb_table_arn
}

output "cross_account_role_arn" {
  value = module.bootstrap.cross_account_role_arn
}

# GitLab Runner role ARN: arn:aws:iam::265245191272:role/GitLabRunnerRole
# Manage GitLabRunnerRole manually in AWS Console
