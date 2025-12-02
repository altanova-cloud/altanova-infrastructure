# Terraform Multi-Cloud Landing Zones Bootcamp

## Overview
This bootcamp covers building a production-ready, multi-account AWS infrastructure using Terraform with GitLab CI/CD integration. The setup demonstrates enterprise best practices for infrastructure as code, including centralized state management, OIDC authentication, and cross-account access patterns.

## Architecture Components

### 1. Centralized State Management
**What we built:**
- **S3 Bucket** (`altanova-tf-state-eu-central-1`): Centralized storage for all Terraform state files across environments
  - Versioning enabled for state history
  - Server-side encryption (AES256)
  - Public access blocked
  - Lifecycle policy to prevent accidental deletion

- **DynamoDB Table** (`altanova-terraform-locks`): State locking mechanism
  - Prevents concurrent modifications
  - Pay-per-request billing mode
  - Hash key: `LockID`

**Why this matters:**
- Single source of truth for infrastructure state
- Team collaboration without conflicts
- State history and rollback capability
- Secure storage with encryption

### 2. GitLab OIDC Authentication
**What we built:**
- **IAM OIDC Provider**: Trust relationship with GitLab.com
  - URL: `https://gitlab.com`
  - Thumbprint: `9e99a48a9960b14926bb7f3b02e22da2b0ab7280`
  - Audience: `https://gitlab.com`

- **GitLab Runner IAM Role** (`GitLabRunnerRole`):
  - Assumes role via OIDC (no static credentials)
  - Trust policy restricted to specific project: `ghabin2004/altanova-infrastructure`
  - Permissions: AdministratorAccess (can be scoped down)

**Why this matters:**
- No AWS credentials stored in GitLab
- Automatic credential rotation
- Fine-grained access control per project/branch
- Follows AWS security best practices

### 3. Cross-Account Access Pattern
**What we built:**
- **Shared Account** (265245191272): Central hub for state and OIDC
- **Dev Account** (975050047325): Development environment
- **Prod Account** (624755517249): Production environment

- **Cross-Account IAM Role** (`TerraformStateAccessRole`):
  - Allows Dev and Prod accounts to access state bucket
  - Scoped permissions for S3 and DynamoDB
  - Trust policy for account principals

**Why this matters:**
- Account isolation for security
- Centralized state management
- Simplified multi-account deployments
- Clear separation of environments

### 4. GitLab CI/CD Pipeline
**What we built:**
- **Stages**: `validate` → `plan` → `apply`
- **Environments**: shared-account, dev-app-account, prod-app-account
- **Authentication**: OIDC-based (no credentials in code)
- **State Backend**: S3 with DynamoDB locking

**Pipeline Features:**
- Automatic validation on every commit
- Terraform plan artifacts (1 week retention)
- Manual approval required for apply
- Parallel validation across environments
- Environment-specific jobs

**Pipeline Flow:**
```
1. GitLab generates OIDC token (JWT)
2. Pipeline assumes AWS role using token
3. Terraform init with S3 backend
4. Terraform validate/plan/apply
5. State stored in S3, locked via DynamoDB
```

## Directory Structure
```
landing-zones/
├── .gitlab-ci.yml                    # CI/CD pipeline configuration
├── .gitignore                        # Excludes sensitive files
├── aws/
│   ├── modules/
│   │   └── bootstrap/                # Bootstrap module
│   │       ├── main.tf               # S3, DynamoDB, IAM resources
│   │       ├── variables.tf          # Input variables
│   │       ├── outputs.tf            # ARNs and resource IDs
│   │       └── BOOTSTRAP_GUIDE.md    # One-time setup instructions
│   └── environments/
│       ├── shared-account/           # Shared services account
│       │   ├── main.tf               # Calls bootstrap module
│       │   ├── backend.tf            # S3 backend config
│       │   ├── backend.conf          # Backend parameters
│       │   ├── variables.tf          # Environment variables
│       │   └── terraform.auto.tfvars # Auto-loaded values
│       ├── dev-app-account/          # Development environment
│       └── prod-app-account/         # Production environment
```

## Key Concepts Demonstrated

### 1. Infrastructure as Code (IaC)
- Declarative infrastructure definition
- Version-controlled infrastructure
- Repeatable deployments
- Documentation through code

### 2. GitOps Workflow
- Git as single source of truth
- Automated deployments via CI/CD
- Pull request reviews for changes
- Audit trail through Git history

### 3. Security Best Practices
- OIDC instead of static credentials
- Least privilege IAM policies
- Encrypted state storage
- Cross-account isolation
- No secrets in code

### 4. State Management
- Remote state in S3
- State locking with DynamoDB
- Partial backend configuration
- State isolation per environment

### 5. Multi-Account Strategy
- Shared services account pattern
- Environment isolation
- Cross-account role assumption
- Centralized state management

## Bootstrap Process (One-Time Setup)

### Prerequisites
1. AWS CLI configured with admin access to Shared Account
2. Terraform installed (or Docker)
3. GitLab project created

### Steps
1. **Local Bootstrap**:
   ```bash
   cd aws/environments/shared-account
   terraform init
   terraform apply
   ```

2. **Capture Outputs**:
   ```bash
   terraform output gitlab_oidc_role_arn
   ```

3. **Configure GitLab**:
   - Add CI/CD variable: `AWS_ROLE_ARN` = `<role_arn_from_output>`

4. **Migrate State to S3**:
   ```bash
   terraform init -migrate-state -backend-config=backend.conf
   ```

5. **Push to GitLab**:
   ```bash
   git push origin master
   ```

## CI/CD Variables Required

| Variable | Description | Example |
|----------|-------------|---------|
| `AWS_ROLE_ARN` | GitLab Runner IAM Role ARN | `arn:aws:iam::265245191272:role/GitLabRunnerRole` |

All other configuration is in `terraform.auto.tfvars` (committed to repo).

## Pipeline Jobs

### Validation Stage
- Runs on every commit
- Validates Terraform syntax
- Parallel execution across environments
- Fast feedback loop

### Plan Stage
- Generates execution plan
- Stores plan as artifact
- Shows what will change
- Required before apply

### Apply Stage
- Manual trigger only
- Applies planned changes
- Updates infrastructure
- Stores state in S3

## Learning Outcomes

After completing this bootcamp, you will understand:

1. **Terraform Fundamentals**
   - Modules and reusability
   - State management
   - Backend configuration
   - Variable handling

2. **AWS IAM & Security**
   - OIDC federation
   - Cross-account access
   - Trust policies
   - Least privilege

3. **CI/CD Integration**
   - GitLab CI/CD pipelines
   - OIDC authentication
   - Artifact management
   - Environment promotion

4. **Multi-Account Architecture**
   - Account isolation
   - Shared services pattern
   - Cross-account roles
   - State centralization

5. **DevOps Best Practices**
   - Infrastructure as Code
   - GitOps workflow
   - Automated testing
   - Change management

## Next Steps

1. **Extend to Dev/Prod**:
   - Create `backend.conf` for dev-app-account
   - Create `backend.conf` for prod-app-account
   - Define infrastructure modules (VPC, EKS, RDS, etc.)

2. **Implement Modules**:
   - Network module (VPC, subnets, routing)
   - Compute module (EC2, EKS, Lambda)
   - Database module (RDS, DynamoDB)
   - Monitoring module (CloudWatch, SNS)

3. **Enhance Security**:
   - Scope down GitLab Runner permissions
   - Implement state encryption with KMS
   - Add MFA for manual applies
   - Enable CloudTrail logging

4. **Improve Pipeline**:
   - Add cost estimation (Infracost)
   - Add security scanning (tfsec, Checkov)
   - Add drift detection
   - Add automated testing (Terratest)

## Resources

- [Terraform S3 Backend](https://developer.hashicorp.com/terraform/language/settings/backends/s3)
- [GitLab OIDC with AWS](https://docs.gitlab.com/ee/ci/cloud_services/aws/)
- [AWS Multi-Account Strategy](https://aws.amazon.com/organizations/getting-started/best-practices/)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)

## Troubleshooting

### Common Issues

1. **OIDC Authentication Fails**
   - Verify GitHub repository name matches exactly in trust policy
   - Check `AWS_ROLE_ARN` is set in GitHub Actions variables
   - Ensure GitHub OIDC provider exists in AWS
   - See `docs/PIPELINE.md` for troubleshooting

2. **State Lock Errors**
   - Check DynamoDB table exists
   - Verify IAM permissions for DynamoDB
   - Manually remove lock if stuck (use with caution)

3. **Backend Initialization Fails**
   - Ensure `backend.conf` exists
   - Verify S3 bucket is accessible
   - Check AWS credentials are valid

4. **Resources Already Exist**
   - State file not found (check S3 backend config)
   - Import existing resources: `terraform import`
   - Or delete and recreate (dev only)

## Conclusion

This infrastructure setup provides a solid foundation for managing multi-account AWS environments using Terraform and GitLab CI/CD. The patterns demonstrated here scale to enterprise-level deployments and follow AWS Well-Architected Framework principles.
