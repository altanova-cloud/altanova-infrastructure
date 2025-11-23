# Deployment Role Module

This module creates an IAM role for GitLab CI/CD deployments to a specific environment (dev or prod).

## Features

- Environment-specific IAM role with scoped permissions
- Trust relationship with GitLab Runner role in Shared Account
- Production role requires external ID for additional security
- Permissions for common infrastructure resources (EC2, EKS, RDS, S3, etc.)
- Ability to assume Terraform State Access role for state management

## Usage

```hcl
module "deployment_role" {
  source = "../../modules/deployment-role"

  environment              = "dev"  # or "prod"
  gitlab_runner_role_arn   = "arn:aws:iam::SHARED_ACCOUNT:role/GitLabRunnerRole"
  state_access_role_arn    = "arn:aws:iam::SHARED_ACCOUNT:role/TerraformStateAccessRole"
}
```

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| environment | Environment name (dev or prod) | string | yes |
| gitlab_runner_role_arn | ARN of GitLab Runner role | string | yes |
| state_access_role_arn | ARN of State Access role | string | yes |
| additional_policies | Additional policy ARNs to attach | list(string) | no |

## Outputs

| Name | Description |
|------|-------------|
| role_arn | ARN of the deployment role |
| role_name | Name of the deployment role |
| role_id | ID of the deployment role |

## Permissions

The deployment role has permissions for:
- EC2 and VPC resources
- EKS clusters
- RDS databases
- S3 buckets
- DynamoDB tables
- Lambda functions
- CloudWatch and Logs
- Limited IAM operations
- Assuming the Terraform State Access role

## Security

- Production role requires external ID "production-deployment"
- Scoped permissions (not AdministratorAccess)
- Can only be assumed by GitLab Runner role
- Tagged for tracking and auditing
