# Pipeline Workflow Test

This is a test merge request to validate the complete CI/CD pipeline workflow.

## What This Tests

1. **Security Stage**:
   - Checkov scan
   - tfsec scan
   - Results uploaded to GitLab Security Dashboard

2. **Validation Stage**:
   - Terraform fmt check
   - Terraform validate (all 3 environments in parallel)

3. **Plan Stage**:
   - Generate Terraform plans for shared, dev, and prod
   - Post plan summaries to MR comments
   - Store plan artifacts

4. **Cost Stage** (MR only):
   - Infracost estimation (if configured)

## Expected Behavior

- ✅ Security scans run and report findings
- ✅ Validation passes
- ✅ Plans are generated
- ✅ Plan summaries appear in MR comments
- ❌ Approve/Apply stages do NOT run (MR only)

## After Merge

When this MR is merged to master:
- Approve jobs will appear (manual)
- Apply jobs will run after approval
- Changes will be deployed to AWS

---

**Test Date**: 2025-11-24
**Purpose**: Validate GitOps workflow with environment-specific IAM roles
