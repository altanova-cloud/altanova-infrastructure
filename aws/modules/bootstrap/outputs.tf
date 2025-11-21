output "s3_bucket_arn" {
  value = aws_s3_bucket.terraform_state.arn
}

output "dynamodb_table_arn" {
  value = aws_dynamodb_table.terraform_locks.arn
}

output "cross_account_role_arn" {
  value = aws_iam_role.terraform_state_access.arn
}

output "gitlab_oidc_role_arn" {
  value = aws_iam_role.gitlab_runner.arn
}
