# GitHub OIDC Module

This module creates an IAM role with trust relationship to GitHub's OIDC provider, enabling GitHub Actions to securely authenticate to AWS without static credentials.

## Features

- **OIDC-based authentication** - No long-lived credentials required
- **Repository-scoped trust** - Only specified repository can assume the role
- **Optional branch restriction** - Can restrict to specific branch (e.g., master)
- **Terraform state access** - Permissions for S3 and DynamoDB state backend
- **Shared account management** - Permissions for managing shared infrastructure

## Prerequisites

- GitHub OIDC provider already created in AWS:
  - URL: `token.actions.githubusercontent.com`
  - Audience: `sts.amazonaws.com`
  - Thumbprint: `6938fd4d98bab03faadb97b34396831e3780aea1`

## Usage

```hcl
module "github_oidc" {
  source = "../../modules/github-oidc"

  github_org         = "altanova-cloud"
  github_repo        = "altanova-infrastructure"
  role_name          = "GitHubActionsRole"
  oidc_provider_arn  = "arn:aws:iam::265245191272:oidc-provider/token.actions.githubusercontent.com"

  state_bucket_arn      = "arn:aws:s3:::altanova-tf-state-eu-central-1"
  state_bucket_name     = "altanova-tf-state-eu-central-1"
  dynamodb_table_arn    = "arn:aws:dynamodb:us-east-1:265245191272:table/altanova-terraform-locks"
  dynamodb_table_name   = "altanova-terraform-locks"
  state_access_role_arn = "arn:aws:iam::265245191272:role/TerraformStateAccessRole"

  restrict_to_branch = "master"  # Optional: restrict to master branch only

  tags = {
    Environment = "shared"
    ManagedBy   = "Terraform"
  }
}
```

## Trust Policy

The module creates a trust policy that allows GitHub Actions to assume the role via OIDC:

```json
{
  "Effect": "Allow",
  "Principal": {
    "Federated": "arn:aws:iam::ACCOUNT:oidc-provider/token.actions.githubusercontent.com"
  },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringEquals": {
      "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
    },
    "StringLike": {
      "token.actions.githubusercontent.com:sub": "repo:ORG/REPO:*"
    }
  }
}
```

## Permissions

The role is granted the following permissions:

### Terraform State Access
- S3 bucket read/write for state files
- DynamoDB table access for state locking
- AssumeRole to TerraformStateAccessRole

### Shared Account Management
- IAM role and policy management (scoped to GitHub* resources)
- ECR repository management
- Secrets Manager access

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| github_org | GitHub organization name | string | - | yes |
| github_repo | GitHub repository name | string | - | yes |
| role_name | Name of the IAM role | string | GitHubActionsRole | no |
| oidc_provider_arn | ARN of GitHub OIDC provider | string | - | yes |
| state_bucket_arn | ARN of Terraform state S3 bucket | string | - | yes |
| state_bucket_name | Name of Terraform state S3 bucket | string | - | yes |
| dynamodb_table_arn | ARN of state lock DynamoDB table | string | - | yes |
| dynamodb_table_name | Name of state lock DynamoDB table | string | - | yes |
| state_access_role_arn | ARN of TerraformStateAccessRole | string | - | yes |
| additional_policy_arns | Additional policy ARNs to attach | list(string) | [] | no |
| restrict_to_branch | Restrict to specific branch | string | "" | no |
| tags | Tags to apply to resources | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| role_arn | ARN of the GitHub Actions IAM role |
| role_name | Name of the GitHub Actions IAM role |
| terraform_state_policy_arn | ARN of the Terraform state access policy |
| shared_account_policy_arn | ARN of the Shared Account access policy |

## Security Considerations

1. **Repository Restriction**: Trust policy restricts access to specified repository only
2. **Branch Restriction**: Optional branch restriction for production deployments
3. **Least Privilege**: Permissions scoped to minimum required for operations
4. **Resource Scoping**: IAM permissions limited to GitHub*-prefixed resources
5. **Audit Trail**: All AssumeRole calls logged in CloudTrail

## GitHub Actions Configuration

To use this role in GitHub Actions:

```yaml
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ vars.AWS_ROLE_ARN }}
    aws-region: us-east-1
    role-session-name: GitHubActions-${{ github.run_id }}
```

## References

- [GitHub OIDC Documentation](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [AWS IAM OIDC Documentation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)
