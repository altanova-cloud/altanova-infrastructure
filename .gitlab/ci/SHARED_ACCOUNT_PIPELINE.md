# Shared Account Pipeline - Isolated Backend Infrastructure

## Overview

The shared account pipeline is **isolated** from the main application pipelines to protect the foundational backend infrastructure.

## Why Isolation?

The shared account hosts **critical backend infrastructure**:
- ✅ S3 state bucket (stores Terraform state for all environments)
- ✅ DynamoDB lock table (prevents concurrent state modifications)
- ✅ GitLabRunnerRole (OIDC authentication)
- ✅ TerraformStateAccessRole (cross-account state access)

**Changes to this infrastructure are high-risk** and could break deployments across all environments.

## How It Works

### Path-Based Triggers
The shared account pipeline **only runs** when files in these paths change:
- `aws/environments/shared-account/**/*`
- `aws/modules/bootstrap/**/*`

### What This Means

✅ **Normal app changes** (dev/prod VPC, EKS, etc.) → Shared pipeline **does not run**

✅ **Backend changes** (IAM roles, S3 bucket, etc.) → Shared pipeline **runs automatically**

✅ **Reduced risk** - Backend infrastructure isn't touched unless necessary

✅ **Faster pipelines** - No unnecessary validation/planning for unchanged infrastructure

## Pipeline Flow

### When Shared Account Files Change:

**On Merge Request:**
```
shared-fmt → shared-lint → shared-validate → shared-plan
                                                  ↓
                                            shared-approve (manual)
                                                  ↓
                                            shared-apply (manual)
```

**On Master Branch:**
```
shared-plan → shared-approve (manual) → shared-apply (manual)
```

### When Only App Account Files Change:

**Shared pipeline does not run at all** ✅

## Manual Override

If you need to run the shared account pipeline manually:

1. Go to GitLab → CI/CD → Pipelines
2. Click "Run Pipeline"
3. Select the branch
4. The shared jobs will appear if the files have changed

## Deployment Guidelines

### ⚠️ Before Deploying Shared Account Changes:

1. **Review carefully** - These changes affect all environments
2. **Test in a separate AWS account** if possible
3. **Coordinate with team** - Ensure no one is running deployments
4. **Have rollback plan** - Know how to revert changes
5. **Monitor state bucket** - Ensure no active locks before applying

### Safe Changes:
- Adding new IAM policies to GitLabRunnerRole
- Updating trust policies
- Adding new deployment roles

### High-Risk Changes:
- Modifying S3 bucket configuration
- Changing DynamoDB table settings
- Updating state backend configuration
- Deleting or renaming IAM roles

## Files in This Pipeline

- `.gitlab/ci/shared-account.yml` - Pipeline definition
- `aws/environments/shared-account/` - Shared account Terraform code
- `aws/modules/bootstrap/` - Bootstrap module (S3, DynamoDB, IAM)

## Troubleshooting

### Pipeline doesn't run when I expect it to
- Check if your changes are in the monitored paths
- Verify the `changes` rules in `.gitlab/ci/shared-account.yml`

### Need to force a run
- Make a small change to a file in `aws/environments/shared-account/`
- Or use GitLab's "Run Pipeline" with manual job triggers

### State is locked
- Check DynamoDB table for active locks
- Verify no other pipelines are running
- Use `terraform force-unlock` if necessary (with caution)

## Related Documentation

- [IAM Roles Implementation](../docs/IAM_ROLES_IMPLEMENTATION.md)
- [Bootstrap Guide](../aws/modules/bootstrap/BOOTSTRAP_GUIDE.md)
