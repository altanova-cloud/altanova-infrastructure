provider "aws" {
  region = var.region
}

module "bootstrap" {
  source = "../../modules/bootstrap"

  bucket_name         = var.state_bucket_name
  dynamodb_table_name = var.lock_table_name
  dev_account_id      = var.dev_account_id
  prod_account_id     = var.prod_account_id
  gitlab_project_path = var.gitlab_project_path
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

output "gitlab_oidc_role_arn" {
  value = module.bootstrap.gitlab_oidc_role_arn
}
