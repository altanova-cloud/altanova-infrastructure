# IaC Security Scanning Implementation Plan

## Goal
Add automated security scanning to the Terraform CI/CD pipeline using Checkov and tfsec, with results displayed in both GitLab Security Dashboard and SonarQube for comprehensive security governance.

## User Review Required

> [!IMPORTANT]
> **SonarQube Setup Decision Required**
> - Option A: SonarCloud (managed, $10-120/month for private repos)
> - Option B: Self-hosted SonarQube (free, requires infrastructure)
> 
> Please confirm which option you prefer before implementation.

> [!WARNING]
> **Pipeline Impact**
> - Security stage will add ~2-3 minutes to pipeline execution
> - Critical findings will block merges by default
> - Existing code may have findings that need remediation

## Proposed Changes

### Pipeline Configuration

#### [MODIFY] [.gitlab-ci.yml](file:///Users/marwanghubein/tech-repo/landing-zones/.gitlab-ci.yml)

**Add security stage:**
- New stage: `security` (runs before `validate`)
- Job: `checkov-scan` - Scans all Terraform files for security issues
- Job: `tfsec-scan` - Terraform-specific security checks
- Job: `sonarqube-scan` - Code quality and security analysis
- Outputs: GitLab SAST reports, SonarQube analysis

**Key features:**
- Parallel execution of Checkov and tfsec
- Fail pipeline on HIGH/CRITICAL severity
- Generate artifacts for both dashboards
- Allow manual override for non-critical issues

---

### Security Scanner Configuration

#### [NEW] [.checkov.yaml](file:///Users/marwanghubein/tech-repo/landing-zones/.checkov.yaml)

Checkov configuration file:
- Skip specific checks (with justification)
- Set severity thresholds
- Define baseline exceptions
- Configure output formats

#### [NEW] [.tfsec.yaml](file:///Users/marwanghubein/tech-repo/landing-zones/.tfsec.yaml)

tfsec configuration file:
- Custom severity levels
- Exclude specific checks
- Define ignore patterns
- Configure output formats

#### [NEW] [sonar-project.properties](file:///Users/marwanghubein/tech-repo/landing-zones/sonar-project.properties)

SonarQube project configuration:
- Project key and name
- Source directories
- Exclusions (node_modules, .terraform)
- External issue import settings
- Quality gate configuration

---

### Documentation Updates

#### [MODIFY] [BOOTCAMP.md](file:///Users/marwanghubein/tech-repo/landing-zones/BOOTCAMP.md)

Add section on security scanning:
- How to interpret scan results
- Common findings and remediation
- Dashboard access instructions
- Quality gate policies

---

## Implementation Steps

### Phase 1: GitLab Security Dashboard (Week 1)

1. **Update `.gitlab-ci.yml`**
   - Add `security` stage before `validate`
   - Add `checkov-scan` job with GitLab SAST output
   - Add `tfsec-scan` job with SARIF output
   - Configure artifact reports

2. **Create Configuration Files**
   - `.checkov.yaml` with baseline exceptions
   - `.tfsec.yaml` with custom rules

3. **Test and Validate**
   - Run pipeline and review findings
   - Create baseline exceptions for accepted risks
   - Verify GitLab Security Dashboard displays results

### Phase 2: SonarQube Integration (Week 2)

1. **Set Up SonarQube**
   - Create SonarCloud/SonarQube project
   - Generate authentication token
   - Add token to GitLab CI/CD variables

2. **Configure Pipeline**
   - Add `sonarqube-scan` job
   - Install SonarScanner
   - Configure external issue import

3. **Configure Quality Gates**
   - Set coverage thresholds
   - Define security rating requirements
   - Configure blocking conditions

### Phase 3: Remediation & Documentation (Week 3)

1. **Address Findings**
   - Fix critical/high severity issues
   - Document accepted risks
   - Update baseline files

2. **Update Documentation**
   - Add security scanning section to BOOTCAMP.md
   - Create remediation guide
   - Document dashboard access

## Verification Plan

### Automated Tests
1. **Pipeline Execution**
   ```bash
   # Trigger pipeline manually
   git commit --allow-empty -m "Test security scanning"
   git push origin master
   ```

2. **Expected Results**
   - Security stage completes successfully
   - GitLab Security Dashboard shows findings
   - SonarQube project updated with results
   - Merge request shows security widget

### Manual Verification
1. **GitLab Security Dashboard**
   - Navigate to Security & Compliance → Vulnerability Report
   - Verify findings are categorized by severity
   - Check merge request security widget

2. **SonarQube Dashboard**
   - Log in to SonarQube/SonarCloud
   - Verify project appears
   - Check security hotspots and vulnerabilities
   - Review quality gate status

3. **Merge Request Blocking**
   - Create MR with intentional security issue
   - Verify pipeline fails
   - Verify security widget shows issue
   - Test manual override capability

## CI/CD Variables Required

| Variable | Description | Example |
|----------|-------------|---------|
| `SONAR_TOKEN` | SonarQube authentication token | `sqp_xxxxxxxxxxxxx` |
| `SONAR_HOST_URL` | SonarQube server URL | `https://sonarcloud.io` |

## Expected Findings (Current Code)

Based on initial analysis, expect these findings:

1. **HIGH**: IAM role with AdministratorAccess policy
   - File: `aws/modules/bootstrap/main.tf`
   - Recommendation: Scope down to specific permissions

2. **MEDIUM**: S3 bucket using AES256 instead of KMS
   - File: `aws/modules/bootstrap/main.tf`
   - Recommendation: Use KMS for encryption

3. **MEDIUM**: DynamoDB table without point-in-time recovery
   - File: `aws/modules/bootstrap/main.tf`
   - Recommendation: Enable PITR for production

4. **LOW**: Missing resource tagging
   - Files: Multiple
   - Recommendation: Add standard tags

## Rollback Plan

If issues arise:
1. Comment out security stage in `.gitlab-ci.yml`
2. Push change to restore pipeline
3. Investigate and fix issues offline
4. Re-enable security stage

## Success Criteria

- ✅ Security stage runs on every commit
- ✅ GitLab Security Dashboard displays findings
- ✅ SonarQube receives and displays results
- ✅ Critical findings block merges
- ✅ Team can view and track remediation
- ✅ Documentation updated with security scanning info
