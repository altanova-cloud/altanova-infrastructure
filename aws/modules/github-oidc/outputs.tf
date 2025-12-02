output "role_arn" {
  description = "ARN of the GitHub Actions IAM role"
  value       = aws_iam_role.github_actions.arn
}

output "role_name" {
  description = "Name of the GitHub Actions IAM role"
  value       = aws_iam_role.github_actions.name
}

output "terraform_state_policy_arn" {
  description = "ARN of the Terraform state access policy"
  value       = aws_iam_policy.terraform_state_access.arn
}

output "shared_account_policy_arn" {
  description = "ARN of the Shared Account access policy"
  value       = aws_iam_policy.shared_account_access.arn
}
