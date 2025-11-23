# Environment-Specific IAM Roles - Implementation Guide

## What Was Implemented

Successfully implemented environment-specific IAM roles with role assumption architecture for proper environment isolation.

## Changes Made

### 1. Deployment Role Module
Created reusable module at `aws/modules/deployment-role/`:
- **Purpose**: Creates environment-specific IAM roles (DevDeployRole, ProdDeployRole)
- **Trust Policy**: Trusts GitLabRunnerRole in Shared Account
- **Permissions**: Scoped to infrastructure resources (EC2, EKS, RDS, S3, etc.)
- **Security**: Prod role requires external ID for additional protection

### 2. Dev Account Configuration
Created `aws/environments/dev-app-account/`:
- `main.tf` - Uses deployment-role module
- `variables.tf` - Role ARN inputs
- `terraform.auto.tfvars` - Auto-loaded values
- `backend.tf` - S3 backend configuration
- `backend.conf` - Backend parameters

### 3. Prod Account Configuration  
Created `aws/environments/prod-app-account/`:
- Same structure as dev account
- Prod-specific deployment role
- Separate state file key

### 4. Bootstrap Module Updates
Modified `aws/modules/bootstrap/main.tf`:
- **Removed**: `AdministratorAccess` policy attachment
- **Added**: Role assumption policy (can assume Dev/Prod roles)
- **Added**: Scoped Shared Account deployment policy

### 5. Pipeline Updates
Modified `.gitlab-ci.yml`:
- **New template**: `.assume_deploy_role` for role assumption chain
- **Dev jobs**: Use role assumption to deploy to Dev account
- **Prod jobs**: Use role assumption to deploy to Prod account
- **Shared jobs**: Continue using GitLabRunnerRole directly

## Architecture

```
GitLab OIDC → GitLabRunnerRole (Shared Account)
              ├─> Direct: Deploy to Shared Account
              ├─> Assume DevDeployRole → Deploy to Dev Account
              └─> Assume ProdDeployRole → Deploy to Prod Account
```

## Deployment Steps

### Step 1: Deploy Dev Account Role
```bash
# Navigate to dev account directory
cd aws/environments/dev-app-account

# Authenticate to Dev Account
aws-vault exec dev-account-admin --

# Initialize and apply
terraform init -backend-config=backend.conf
terraform apply

# Note the output: deploy_role_arn
```

### Step 2: Deploy Prod Account Role
```bash
# Navigate to prod account directory
cd aws/environments/prod-app-account

# Authenticate to Prod Account
aws-vault exec prod-account-admin --

# Initialize and apply
terraform init -backend-config=backend.conf
terraform apply

# Note the output: deploy_role_arn
```

### Step 3: Update Shared Account Bootstrap
```bash
# Navigate to shared account directory
cd aws/environments/shared-account

# Authenticate to Shared Account
aws-vault exec sharedou-ro --

# Apply updated bootstrap (removes AdministratorAccess, adds role assumption)
terraform apply
```

### Step 4: Configure GitLab CI/CD Variables
Add these variables in GitLab Project Settings → CI/CD → Variables:

| Variable | Value | Example |
|----------|-------|---------|
| `DEV_DEPLOY_ROLE_ARN` | From Step 1 output | `arn:aws:iam::975050047325:role/DevDeployRole` |
| `PROD_DEPLOY_ROLE_ARN` | From Step 2 output | `arn:aws:iam::624755517249:role/ProdDeployRole` |

### Step 5: Test Pipeline
```bash
# Create test branch
git checkout -b test/role-assumption

# Make small change
echo "# Test" >> README.md

# Push and create MR
git add .
git commit -m "Test role assumption"
git push origin test/role-assumption
```

## Verification

### Test Role Assumption Locally
```bash
# Test assuming Dev role
aws sts assume-role \
  --role-arn arn:aws:iam::975050047325:role/DevDeployRole \
  --role-session-name test

# Test assuming Prod role  
aws sts assume-role \
  --role-arn arn:aws:iam::624755517249:role/ProdDeployRole \
  --role-session-name test \
  --external-id production-deployment
```

### Verify Environment Isolation
1. Dev pipeline can only deploy to Dev account
2. Prod pipeline can only deploy to Prod account
3. Shared pipeline can deploy to Shared account
4. All accounts can access centralized state

## Security Improvements

### Before
- ❌ Single role with `AdministratorAccess`
- ❌ No environment isolation
- ❌ Dev pipeline could deploy to prod

### After
- ✅ Environment-specific roles with scoped permissions
- ✅ Role assumption chain for isolation
- ✅ Prod role requires external ID
- ✅ Clear audit trail of role assumptions
- ✅ Least privilege principle

## Rollback Plan

If issues arise:
1. Revert `.gitlab-ci.yml` to previous version
2. Revert `aws/modules/bootstrap/main.tf` to use `AdministratorAccess`
3. Apply bootstrap changes
4. Remove `DEV_DEPLOY_ROLE_ARN` and `PROD_DEPLOY_ROLE_ARN` variables

## Files Changed

- `aws/modules/deployment-role/` - New module
- `aws/environments/dev-app-account/` - Dev role configuration
- `aws/environments/prod-app-account/` - Prod role configuration
- `aws/modules/bootstrap/main.tf` - Updated GitLabRunnerRole permissions
- `.gitlab-ci.yml` - Added role assumption logic

## Next Steps

1. Deploy roles to dev and prod accounts
2. Update shared account bootstrap
3. Add role ARNs to GitLab CI/CD variables
4. Test pipeline with role assumption
5. Monitor CloudTrail for role assumption events
