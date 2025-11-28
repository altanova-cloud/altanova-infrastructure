# Improved CI/CD Pipeline - User Guide

## Overview
The CI/CD pipeline now follows GitOps best practices with merge request-driven deployments, automated security scanning, and approval gates.

## Pipeline Stages

```
security → validate → plan → cost → approve → apply
```

### 1. Security Stage
- **Checkov**: Scans for security misconfigurations
- **tfsec**: Terraform-specific security checks
- **Runs on**: All branches (MRs and master)
- **Blocks**: Pipeline fails if HIGH/CRITICAL issues found

### 2. Validate Stage  
- **terraform fmt**: Checks code formatting
- **terraform validate**: Validates syntax
- **Runs on**: All branches
- **Parallel**: Across all environments

### 3. Plan Stage
- **terraform plan**: Generates execution plan
- **MR Comments**: Posts plan summary to merge request
- **Runs on**: All branches
- **Artifacts**: Plan files (7 days retention)

### 4. Cost Stage
- **Infracost**: Estimates infrastructure costs
- **Runs on**: Merge requests only
- **Optional**: Requires `INFRACOST_API_KEY`

### 5. Approve Stage
- **Manual gate**: Requires human approval
- **Runs on**: Master branch only
- **Shows**: Plan output for review

### 6. Apply Stage
- **terraform apply**: Deploys infrastructure
- **Runs on**: Master branch after approval
- **Automatic**: Runs after approve stage succeeds

## Workflow

### Developer Workflow
1. **Create feature branch**:
   ```bash
   git checkout -b feature/add-vpc
   ```

2. **Make changes**: Edit Terraform files

3. **Push and create MR**:
   ```bash
   git push origin feature/add-vpc
   # Create MR in GitLab UI
   ```

4. **Pipeline runs on MR**:
   - ✅ Security scans
   - ✅ Validation
   - ✅ Plan (posted to MR comments)
   - ✅ Cost estimation (if configured)

5. **Review**: Team reviews plan in MR

6. **Merge**: Merge to master after approval

7. **Master pipeline runs**:
   - ✅ Security, validate, plan
   - ⏸️ Approve (manual - click to approve)
   - ✅ Apply (automatic after approval)

### Approval Workflow
1. MR merged to master
2. Pipeline runs through plan stage
3. Approve job waits for manual trigger
4. Reviewer clicks "Run" on approve job
5. Apply stage executes automatically

## CI/CD Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `AWS_ROLE_ARN` | ✅ Yes | GitLab Runner IAM Role ARN |
| `GITLAB_TOKEN` | ⚠️ Optional | For posting MR comments |
| `INFRACOST_API_KEY` | ⚠️ Optional | For cost estimation |

### Setting Variables
1. Go to **Settings** > **CI/CD** > **Variables**
2. Add each variable
3. Mark `AWS_ROLE_ARN` as **Protected**

## Security Scanning

### Viewing Results
- **GitLab Security Dashboard**: Security & Compliance → Vulnerability Report
- **Merge Request Widget**: Shows security findings inline
- **Pipeline Logs**: Detailed scan output

### Common Findings
1. **IAM overly permissive**: Scope down permissions
2. **Missing encryption**: Enable KMS encryption
3. **Public access**: Ensure resources are private
4. **Missing tags**: Add standard tags

### Handling Findings
- **Fix**: Update code to address issue
- **Accept risk**: Add to `.checkov.yaml` or `.tfsec.yaml` skip list with justification

## Cost Estimation

### Setup (Optional)
1. Sign up at [infracost.io](https://www.infracost.io)
2. Get API key
3. Add `INFRACOST_API_KEY` to CI/CD variables

### Viewing Costs
- Cost diff posted to MR comments
- Shows monthly cost estimate
- Highlights cost increases

## Troubleshooting

### Pipeline Fails on Security
- Review security scan logs
- Fix critical issues or add justified exceptions
- Re-run pipeline

### Plan Not Posted to MR
- Ensure `GITLAB_TOKEN` is set
- Check token has `api` scope
- Verify MR is not from fork

### Apply Doesn't Run
- Ensure you're on master branch
- Check approve job completed successfully
- Verify no upstream job failures

## Best Practices

1. **Always use MRs**: Never commit directly to master
2. **Review plans**: Always review plan output before merging
3. **Small changes**: Keep MRs focused and small
4. **Test in dev**: Test changes in dev before prod
5. **Document exceptions**: Always justify security check skips

## Migration from Old Pipeline

The new pipeline is backward compatible but adds:
- Security scanning (may find existing issues)
- Approval gates (requires manual approval)
- MR workflow (direct commits to master won't trigger apply)

**Action required**: Create MRs for all future changes
