# GitHub Actions CI/CD Pipeline for Terraform
## Multi-Account AWS Infrastructure Deployment

---

## 📋 Document Overview

This document provides comprehensive documentation for the GitHub Actions CI/CD pipeline used to deploy and manage Terraform infrastructure across multiple AWS accounts.

**Important Notes:**
- Main branch: `master` (not main)
- This document will be updated as the pipeline evolves through phases
- Referenced in CLAUDE.md for AI assistant context

---

## 🏢 Current Infrastructure Context

### AWS Accounts:
- **Shared Services Account:** 265245191272 (State, OIDC, ECR)
- **Dev Account:** 975050047325 (Development workloads)
- **Prod Account:** 624755517249 (Production workloads)

### Existing Setup:
- ✅ GitLab OIDC Provider (will migrate to GitHub OIDC)
- ✅ S3 State Bucket: `altanova-tf-state-eu-central-1` (us-east-1)
- ✅ DynamoDB Lock Table: `altanova-terraform-locks`
- ✅ Cross-account IAM Roles: DevDeployRole, ProdDeployRole, TerraformStateAccessRole

### Repository:
- **GitHub:** `altanova-cloud/altanova-infrastructure`
- **Main Branch:** `master`

---

## 🎯 Pipeline Goals & Principles

### Goals:
1. **Security First:** OIDC-based authentication, no static credentials
2. **Progressive Complexity:** Start simple, add features in phases
3. **Environment Isolation:** Separate workflows per account
4. **Manual Control for Prod:** Protected environments with reviewer approval
5. **Comprehensive Documentation:** Clear, visual, maintainable

### Principles:
- **Infrastructure as Code:** All changes via Terraform
- **Peer Review:** PRs required for all changes
- **Automated Testing:** Validation before deployment
- **Audit Trail:** All actions logged and traceable
- **Fail Fast:** Quick feedback on errors

---

## 📐 Phased Implementation Strategy

```
Phase 1: Foundation ✅ COMPLETE
├── GitHub OIDC Setup
├── Basic Terraform Workflow (Shared Account)
├── Manual Approval Gates
└── Documentation

Phase 2: Security & Quality (Future)
├── TFLint Integration
├── Checkov Security Scanning
├── TFSec Analysis
├── Enhanced PR Comments
└── Cost Estimation (Optional)

Phase 3: Multi-Environment ✅ COMPLETE
├── Dev Account Workflow (terraform-dev.yml)
├── Prod Account Workflow (terraform-prod.yml)
├── Protected Environments (prod-account)
├── Environment-Specific Approvals (auto for dev, manual for prod)
└── GitHub Flow + Semantic Branch Naming

Phase 4: Advanced Features (Future)
├── Drift Detection (Scheduled)
├── Automated PR Labeling
├── Notifications (Slack/Teams)
├── Terraform Docs Generation
├── Compliance Reporting
└── Advanced Automation
```

---

## 🏗️ Phase 1: Foundation Architecture

### Overview Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│ Developer Workflow                                               │
│                                                                  │
│ 1. Create feature branch                                        │
│ 2. Make Terraform changes                                       │
│ 3. Push & create PR to master                                   │
│ 4. Review automated plan                                        │
│ 5. Merge PR (if approved)                                       │
│ 6. Approve apply job (manual)                                   │
└──────────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────────┐
│ GitHub Actions Workflow: terraform-shared.yml                   │
│                                                                  │
│ Trigger: PR to master OR push to master OR manual               │
│                                                                  │
│ ┌────────────────────────────────────────────────────────────┐  │
│ │ Job 1: terraform-validate                                  │  │
│ │ ├── Checkout code                                          │  │
│ │ ├── Setup Terraform (v1.8+)                                │  │
│ │ ├── terraform fmt -check -recursive                        │  │
│ │ ├── terraform init (shared-account)                        │  │
│ │ └── terraform validate                                     │  │
│ └────────────────────────────────────────────────────────────┘  │
│                            ↓                                     │
│ ┌────────────────────────────────────────────────────────────┐  │
│ │ Job 2: terraform-plan                                      │  │
│ │ ├── Configure AWS Credentials (OIDC)                       │  │
│ │ ├── terraform init -backend-config=backend.conf            │  │
│ │ ├── terraform plan -out=tfplan                             │  │
│ │ ├── terraform show tfplan (for review)                     │  │
│ │ ├── Upload plan artifact                                   │  │
│ │ └── Comment plan summary on PR                             │  │
│ └────────────────────────────────────────────────────────────┘  │
│                            ↓                                     │
│ ┌────────────────────────────────────────────────────────────┐  │
│ │ Job 3: terraform-apply                                     │  │
│ │ Only on: push to master                                    │  │
│ │ Requires: Manual approval (infra team)                     │  │
│ │                                                            │  │
│ │ ├── Download plan artifact                                 │  │
│ │ ├── Configure AWS Credentials (OIDC)                       │  │
│ │ ├── terraform init                                         │  │
│ │ ├── terraform apply tfplan                                 │  │
│ │ └── Comment apply result                                   │  │
│ └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────────┐
│ AWS Infrastructure Updated                                       │
└──────────────────────────────────────────────────────────────────┘
```

---

## 🔐 GitHub OIDC Authentication Architecture

### OIDC Authentication Flow

```
┌───────────────────────────────────────────────────────────────────┐
│ GitHub Actions Runner                                             │
│                                                                   │
│ Repository: altanova-cloud/altanova-infrastructure                │
│ Branch: master                                                    │
│ Workflow: terraform-shared.yml                                    │
│                                                                   │
│ Step: Configure AWS Credentials                                   │
│   ↓                                                               │
│ Generate OIDC Token (JWT)                                         │
│   - iss: https://token.actions.githubusercontent.com              │
│   - sub: repo:altanova-cloud/altanova-infrastructure:ref:*        │
│   - aud: sts.amazonaws.com                                        │
└───────────────────────────────────────────────────────────────────┘
                          ↓
                          ↓ HTTPS Request
                          ↓ sts:AssumeRoleWithWebIdentity
                          ↓
┌───────────────────────────────────────────────────────────────────┐
│ AWS Shared Account (265245191272)                                │
│                                                                   │
│ ┌───────────────────────────────────────────────────────────┐   │
│ │ GitHub OIDC Provider                                      │   │
│ │ URL: token.actions.githubusercontent.com                  │   │
│ │ Audience: sts.amazonaws.com                               │   │
│ │ Thumbprint: 6938fd4d98bab03faadb97b34396831e3780aea1      │   │
│ └───────────────────────────────────────────────────────────┘   │
│                          ↓                                        │
│                   Validate Token                                  │
│                          ↓                                        │
│ ┌───────────────────────────────────────────────────────────┐   │
│ │ GitHubActionsRole                                         │   │
│ │ ARN: arn:aws:iam::265245191272:role/GitHubActionsRole     │   │
│ │                                                           │   │
│ │ Trust Policy:                                             │   │
│ │   - Federated: GitHub OIDC Provider                      │   │
│ │   - Condition: repo matches                              │   │
│ │                altanova-cloud/altanova-infrastructure     │   │
│ │                                                           │   │
│ │ Permissions (Phase 1):                                    │   │
│ │   - S3: altanova-tf-state-eu-central-1 (RW)              │   │
│ │   - DynamoDB: altanova-terraform-locks (RW)              │   │
│ │   - IAM: Shared Account resources                        │   │
│ │   - STS: AssumeRole to TerraformStateAccessRole          │   │
│ └───────────────────────────────────────────────────────────┘   │
│                          ↓                                        │
│                Return Temporary Credentials                       │
│                (Valid for 1 hour)                                 │
└───────────────────────────────────────────────────────────────────┘
                          ↓
┌───────────────────────────────────────────────────────────────────┐
│ GitHub Actions Runner                                             │
│                                                                   │
│ AWS_ACCESS_KEY_ID: ASIA...                                        │
│ AWS_SECRET_ACCESS_KEY: ...                                        │
│ AWS_SESSION_TOKEN: ...                                            │
│                                                                   │
│ ↓ Execute Terraform Commands                                      │
│                                                                   │
│ terraform init → Access S3 Backend                                │
│ terraform plan → Read/Write state                                 │
│ terraform apply → Update infrastructure                           │
└───────────────────────────────────────────────────────────────────┘
```

### Key Security Features:

1. **No Static Credentials:** OIDC tokens are short-lived (1 hour)
2. **Repository Scoped:** Only workflows from `altanova-cloud/altanova-infrastructure` can assume role
3. **Branch Protection:** Can restrict to specific branches (e.g., `ref:refs/heads/master`)
4. **Audit Trail:** All AssumeRole calls logged in CloudTrail
5. **Least Privilege:** Role permissions scoped to minimum required

---

## 📁 Repository Structure

```
altanova-infrastructure/
├── .github/
│   ├── workflows/
│   │   ├── terraform-shared.yml          ← Phase 1: Shared Account
│   │   ├── terraform-dev.yml             ← Phase 3: Dev Account (auto-apply)
│   │   └── terraform-prod.yml            ← Phase 3: Prod Account (manual approval)
│   │
│   └── CODEOWNERS                         ← Infra team ownership
│       # aws/environments/shared-account/ @altanova-cloud/infra-team
│
├── aws/
│   ├── modules/
│   │   ├── bootstrap/                     ← Existing (OIDC, State)
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   └── BOOTSTRAP_GUIDE.md
│   │   │
│   │   ├── deployment-role/               ← Existing (Cross-account roles)
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   │
│   │   └── github-oidc/                   ← NEW: GitHub OIDC module
│   │       ├── main.tf                    # OIDC provider + GitHubActionsRole
│   │       ├── variables.tf               # Repository, account IDs
│   │       ├── outputs.tf                 # Role ARN
│   │       └── README.md                  # Module documentation
│   │
│   └── environments/
│       ├── shared-account/
│       │   ├── main.tf                    ← UPDATE: Add github-oidc module
│       │   ├── variables.tf               ← Existing
│       │   ├── outputs.tf                 ← Existing
│       │   ├── backend.tf                 ← Existing
│       │   ├── backend.conf               ← Existing
│       │   └── terraform.auto.tfvars      ← UPDATE: GitHub repo config
│       │
│       ├── dev-app-account/               ← Existing (Phase 3)
│       │   ├── main.tf
│       │   ├── backend.conf
│       │   └── terraform.auto.tfvars
│       │
│       └── prod-app-account/              ← Existing (Phase 3)
│           ├── main.tf
│           ├── backend.conf
│           └── terraform.auto.tfvars
│
├── docs/
│   ├── ARCHITECTURE.md                    ← Existing
│   └── PIPELINE.md                        ← THIS FILE
│
├── CLAUDE.md                              ← UPDATE: Reference PIPELINE.md
└── README.md                              ← Existing
```

---

## 🔧 Phase 1: Workflow Details

### File: `.github/workflows/terraform-shared.yml`

#### Workflow Triggers:

```yaml
Trigger Conditions:
├── pull_request:
│   ├── branches: [master]
│   └── paths: [aws/environments/shared-account/**]
│
├── push:
│   ├── branches: [master]
│   └── paths: [aws/environments/shared-account/**]
│
└── workflow_dispatch:
    └── Manual trigger from GitHub UI
```

#### Jobs Flow:

```
┌────────────────────────────────────────────────────────────────┐
│ Trigger Event                                                  │
│ - PR to master                                                 │
│ - Push to master                                               │
│ - Manual dispatch                                              │
└────────────────────────────────────────────────────────────────┘
                          ↓
┌────────────────────────────────────────────────────────────────┐
│ Job: terraform-validate                                        │
│ Runs on: ubuntu-latest                                         │
│ Timeout: 10 minutes                                            │
│                                                                │
│ Steps:                                                         │
│ 1. Checkout repository                                         │
│    - uses: actions/checkout@v4                                 │
│                                                                │
│ 2. Setup Terraform                                             │
│    - uses: hashicorp/setup-terraform@v3                        │
│    - version: 1.8.x                                            │
│                                                                │
│ 3. Terraform Format Check                                      │
│    - terraform fmt -check -recursive                           │
│    - Exit code 1 if not formatted                              │
│                                                                │
│ 4. Terraform Init (validation only, no backend)                │
│    - terraform init -backend=false                             │
│    - Working dir: aws/environments/shared-account              │
│                                                                │
│ 5. Terraform Validate                                          │
│    - terraform validate                                        │
│    - Check syntax and configuration                            │
│                                                                │
│ Result: ✅ Pass = Continue | ❌ Fail = Stop workflow           │
└────────────────────────────────────────────────────────────────┘
                          ↓
┌────────────────────────────────────────────────────────────────┐
│ Job: terraform-plan                                            │
│ Runs on: ubuntu-latest                                         │
│ Timeout: 20 minutes                                            │
│ Needs: terraform-validate                                      │
│                                                                │
│ Steps:                                                         │
│ 1. Checkout repository                                         │
│    - uses: actions/checkout@v4                                 │
│                                                                │
│ 2. Configure AWS Credentials (OIDC)                            │
│    - uses: aws-actions/configure-aws-credentials@v4            │
│    - role-to-assume: ${{ vars.AWS_ROLE_ARN }}                 │
│    - aws-region: us-east-1                                     │
│    - session duration: 3600 seconds                            │
│                                                                │
│ 3. Setup Terraform                                             │
│    - uses: hashicorp/setup-terraform@v3                        │
│                                                                │
│ 4. Terraform Init (with backend)                               │
│    - terraform init -backend-config=backend.conf               │
│    - Initialize S3 backend                                     │
│    - Download state file                                       │
│                                                                │
│ 5. Terraform Plan                                              │
│    - terraform plan -out=tfplan -no-color                      │
│    - Generate execution plan                                   │
│    - Save to tfplan file                                       │
│                                                                │
│ 6. Show Plan (human readable)                                  │
│    - terraform show tfplan -no-color                           │
│    - Capture output                                            │
│                                                                │
│ 7. Upload Plan Artifact                                        │
│    - uses: actions/upload-artifact@v4                          │
│    - name: tfplan-shared-${{ github.sha }}                    │
│    - retention: 30 days                                        │
│                                                                │
│ 8. Comment Plan on PR (if PR event)                            │
│    - uses: actions/github-script@v7                            │
│    - Post plan summary as PR comment                           │
│                                                                │
│ Result: Plan available for review                              │
└────────────────────────────────────────────────────────────────┘
                          ↓
                     (Manual Review)
                          ↓
                    (PR Merged to master)
                          ↓
┌────────────────────────────────────────────────────────────────┐
│ Job: terraform-apply                                           │
│ Runs on: ubuntu-latest                                         │
│ Timeout: 30 minutes                                            │
│ Environment: shared-account (with protection rules)            │
│ Needs: terraform-plan                                          │
│ If: github.ref == 'refs/heads/master' && github.event_name == │
│     'push'                                                     │
│                                                                │
│ ⚠️  MANUAL APPROVAL REQUIRED (GitHub Environment)              │
│     - Requires approval from infra team reviewers              │
│     - Timeout: 4 hours max wait time                           │
│                                                                │
│ Steps:                                                         │
│ 1. Checkout repository                                         │
│    - uses: actions/checkout@v4                                 │
│                                                                │
│ 2. Download Plan Artifact                                      │
│    - uses: actions/download-artifact@v4                        │
│    - name: tfplan-shared-${{ github.sha }}                    │
│                                                                │
│ 3. Configure AWS Credentials (OIDC)                            │
│    - uses: aws-actions/configure-aws-credentials@v4            │
│    - role-to-assume: ${{ vars.AWS_ROLE_ARN }}                 │
│                                                                │
│ 4. Setup Terraform                                             │
│    - uses: hashicorp/setup-terraform@v3                        │
│                                                                │
│ 5. Terraform Init                                              │
│    - terraform init -backend-config=backend.conf               │
│                                                                │
│ 6. Terraform Apply                                             │
│    - terraform apply tfplan                                    │
│    - Execute the plan                                          │
│    - No additional approval needed (already in plan)           │
│                                                                │
│ 7. Comment Apply Result                                        │
│    - Post success/failure to original PR                       │
│                                                                │
│ Result: Infrastructure deployed to Shared Account              │
└────────────────────────────────────────────────────────────────┘
```

---

## 🛡️ Security & Best Practices

### OIDC Security

```
Security Layer 1: GitHub Repository Restriction
├── Trust policy restricts to: altanova-cloud/altanova-infrastructure
└── No other repositories can assume this role

Security Layer 2: Branch Protection (Optional - Phase 2)
├── Can restrict to: ref:refs/heads/master
└── Only master branch can deploy

Security Layer 3: AWS IAM Permissions
├── Least privilege principle
├── Scoped to specific resources
└── No * permissions in Phase 1

Security Layer 4: GitHub Environment Protection
├── Required reviewers (infra team)
├── Wait timer (optional)
└── Audit log of approvals

Security Layer 5: Terraform State Locking
├── DynamoDB prevents concurrent modifications
└── State consistency guaranteed
```

### Workflow Best Practices:

1. **Concurrency Control:**
   ```yaml
   concurrency:
     group: terraform-shared-${{ github.ref }}
     cancel-in-progress: false  # Don't cancel applies
   ```

2. **Timeout Protection:**
   - Validate: 10 minutes max
   - Plan: 20 minutes max
   - Apply: 30 minutes max

3. **Artifact Retention:**
   - Plans retained for 30 days
   - Enable audit and rollback

4. **Error Handling:**
   - Fail fast on validation errors
   - Continue-on-error: false (strict mode)

5. **State Management:**
   - Always use backend config
   - Never commit state files
   - Lock state during operations

---

## 👥 Approval & Review Process

### Phase 1: Shared Account Workflow

```
Developer Actions:
├── 1. Create feature branch from master
├── 2. Make Terraform changes
├── 3. Push branch → triggers plan job
├── 4. Review plan output in PR comment
├── 5. Request review from infra team
└── 6. Address feedback, update code

Infra Team Review:
├── 1. Review code changes (GitHub PR)
├── 2. Review terraform plan output
├── 3. Validate changes are safe
├── 4. Approve PR (GitHub review)
└── 5. Merge PR to master

Automated Deployment:
├── 1. Merge triggers apply job
├── 2. GitHub Environment blocks apply
├── 3. Notification sent to approvers
└── 4. Manual approval required

Infra Team Approval:
├── 1. Review GitHub Actions run
├── 2. Verify plan matches expectations
├── 3. Click "Review deployments"
└── 4. Approve → Apply executes

Result:
└── Infrastructure deployed to Shared Account
```

### GitHub Environment Configuration:

```yaml
Environment: shared-account
├── Protection Rules:
│   ├── Required reviewers: 1 person from infra team
│   ├── Reviewers:
│   │   ├── @infra-team-member-1
│   │   ├── @infra-team-member-2
│   │   └── @infra-team-member-3
│   ├── Wait timer: 0 minutes (immediate after approval)
│   └── Deployment branches: master only
│
└── Environment Secrets:
    └── AWS_ROLE_ARN: arn:aws:iam::265245191272:role/GitHubActionsRole
```

---

## 📊 Phase 2: Security & Quality Additions

### Tools to Add:

```
Security & Quality Pipeline:
├── 1. TFLint
│   ├── Purpose: Terraform best practices
│   ├── Config: .tflint.hcl
│   └── Fails on: errors, not warnings
│
├── 2. Checkov
│   ├── Purpose: Security scanning
│   ├── Framework: Terraform
│   ├── Config: .checkov.yaml (existing)
│   └── Skip known exceptions
│
├── 3. TFSec
│   ├── Purpose: Security best practices
│   ├── Config: .tfsec.yml (existing)
│   └── Check AWS resources
│
├── 4. Terraform Fmt
│   ├── Purpose: Code formatting
│   ├── Already in Phase 1
│   └── Enforced in validation job
│
└── 5. Infracost (Optional)
    ├── Purpose: Cost estimation
    ├── Comment cost diff on PR
    └── Requires Infracost API key
```

### Enhanced PR Comments:

Phase 2 will add rich PR comments:

```markdown
## Terraform Plan Summary

### 📊 Changes
- ✅ Resources to create: 2
- 🔄 Resources to update: 1
- ❌ Resources to destroy: 0

### 🔐 Security Scan Results
- Checkov: ✅ Passed (2 exceptions skipped)
- TFSec: ✅ No issues found
- TFLint: ✅ No errors

### 💰 Cost Impact (Infracost)
- Monthly cost change: +$15.00 USD
- New resources: $15.00 USD

### 📋 Plan Details
<details>
<summary>View Full Plan</summary>

```
[Full terraform plan output]
```

</details>
```

---

## 🌍 Phase 3: Multi-Environment Support ✅ IMPLEMENTED

### Workflow Structure:

```
.github/workflows/
├── terraform-shared.yml      ← Phase 1 (Shared Account) ✅
├── terraform-dev.yml         ← Phase 3 (Dev Account) ✅ IMPLEMENTED
└── terraform-prod.yml        ← Phase 3 (Prod Account) ✅ IMPLEMENTED
```

**Decision:** Separate workflow files (not matrix) for:
- Clear separation per account
- Independent triggers and paths
- Easy to understand and maintain
- Avoids OIDC/reusable workflow complexities

### Git Workflow: GitHub Flow

Based on startup best practices, we use **GitHub Flow** (simplified trunk-based):
- One main branch (`master`) + short-lived feature branches
- PR-based review ensures safety before infrastructure changes
- Simple and appropriate for small DevOps teams

### Branch Naming Convention

Semantic branch naming for clarity and automation:

```
<type>/<short-description>

Types:
├── feature/ or feat/  → New features
├── fix/ or bugfix/    → Bug fixes
├── hotfix/            → Critical production fixes
├── docs/              → Documentation changes
├── refactor/          → Code refactoring
└── chore/             → Maintenance tasks

Examples:
  feature/vpc-infrastructure
  feat/eks-blueprints
  fix/nat-gateway-config
  docs/pipeline-update
  chore/terraform-upgrade
```

### Environment-Specific Configuration:

```yaml
Dev Account Workflow (terraform-dev.yml):
├── Trigger: aws/environments/dev-app-account/** changes
├── Trigger: aws/modules/vpc/** changes (env-specific)
├── Trigger: aws/modules/deployment-role/** changes
├── Environment: None (auto-apply after merge)
├── Approval: NOT REQUIRED (fast iteration for dev)
├── Role Chain: GitHubActionsRole → DevDeployRole
├── Dev Role: arn:aws:iam::975050047325:role/DevDeployRole
└── Backend: dev-app-account/terraform.tfstate

Prod Account Workflow (terraform-prod.yml):
├── Trigger: aws/environments/prod-app-account/** changes
├── Trigger: aws/modules/vpc/** changes (env-specific)
├── Trigger: aws/modules/deployment-role/** changes
├── Environment: prod-account (PROTECTED)
├── Approval: REQUIRED (manual approval before apply)
├── Role Chain: GitHubActionsRole → ProdDeployRole
├── Prod Role: arn:aws:iam::624755517249:role/ProdDeployRole
└── Backend: prod-app-account/terraform.tfstate
```

### Cross-Account Role Chain (Phase 3):

```
GitHub OIDC Token
         │
         ▼
GitHubActionsRole (Shared: 265245191272)
         │
         ├──► Direct deploy to Shared Account
         │
         ├──► AssumeRole (role-chaining) ──► DevDeployRole (Dev: 975050047325)
         │                                         │
         │                                         ▼
         │                                    Deploy Dev Infrastructure
         │                                    (Auto-apply after merge)
         │
         └──► AssumeRole (role-chaining) ──► ProdDeployRole (Prod: 624755517249)
                                                   │
                                                   ▼
                                              Deploy Prod Infrastructure
                                              (Manual approval required)
```

### Dev vs Prod Workflow Comparison:

| Feature | Dev Account | Prod Account |
|---------|-------------|--------------|
| **Workflow File** | terraform-dev.yml | terraform-prod.yml |
| **Path Triggers** | dev-app-account/**, modules/vpc/**, modules/deployment-role/** | prod-app-account/**, modules/vpc/**, modules/deployment-role/** |
| **PR to master** | Validate + Plan | Validate + Plan |
| **Push to master** | Auto-Apply | Requires Manual Approval |
| **Environment Protection** | None | `prod-account` with reviewers |
| **Role Chain** | GitHubActionsRole → DevDeployRole | GitHubActionsRole → ProdDeployRole |
| **Concurrency Group** | terraform-dev-${{ github.ref }} | terraform-prod-${{ github.ref }} |

### GitHub Configuration Required (Phase 3):

```
Repository Variables (Settings → Secrets and variables → Actions → Variables):
└── AWS_ROLE_ARN = arn:aws:iam::265245191272:role/GitHubActionsRole (existing)

Environments (Settings → Environments):
├── shared-account      ← Phase 1 (existing)
│   └── Protection rules: Required reviewers
│
└── prod-account        ← Phase 3 (NEW)
    ├── Protection rules:
    │   ├── Required reviewers: 1-2 from DevOps team
    │   └── Deployment branches: master only
    └── No environment-specific variables (uses repo-level AWS_ROLE_ARN)

Note: dev-account environment NOT required (auto-apply without approval)
```

### Workflow Flow Diagrams:

#### Dev Account Flow (Auto-Apply):

```
┌────────────────────────────────────────────────────────────────┐
│ Developer creates PR with dev-app-account changes              │
└────────────────────────────────────────────────────────────────┘
                          ↓
┌────────────────────────────────────────────────────────────────┐
│ terraform-dev.yml triggers                                     │
│ Jobs: terraform-validate → terraform-plan                      │
│ Plan output commented on PR                                    │
└────────────────────────────────────────────────────────────────┘
                          ↓
┌────────────────────────────────────────────────────────────────┐
│ PR reviewed and merged to master                               │
└────────────────────────────────────────────────────────────────┘
                          ↓
┌────────────────────────────────────────────────────────────────┐
│ terraform-apply job runs automatically                         │
│ No manual approval required                                    │
│ Infrastructure deployed to Dev Account                         │
└────────────────────────────────────────────────────────────────┘
```

#### Prod Account Flow (Manual Approval):

```
┌────────────────────────────────────────────────────────────────┐
│ Developer creates PR with prod-app-account changes             │
└────────────────────────────────────────────────────────────────┘
                          ↓
┌────────────────────────────────────────────────────────────────┐
│ terraform-prod.yml triggers                                    │
│ Jobs: terraform-validate → terraform-plan                      │
│ Plan output commented on PR (marked as PRODUCTION)             │
└────────────────────────────────────────────────────────────────┘
                          ↓
┌────────────────────────────────────────────────────────────────┐
│ PR reviewed and merged to master                               │
└────────────────────────────────────────────────────────────────┘
                          ↓
┌────────────────────────────────────────────────────────────────┐
│ terraform-apply job PAUSES for manual approval                 │
│ ⚠️ Requires reviewer to approve in GitHub Actions              │
│ Navigate to Actions → Running workflow → Review deployments    │
└────────────────────────────────────────────────────────────────┘
                          ↓
┌────────────────────────────────────────────────────────────────┐
│ After approval: terraform apply executes                       │
│ Infrastructure deployed to Prod Account                        │
└────────────────────────────────────────────────────────────────┘
```

---

## 🚨 Drift Detection (Phase 3)

### Scheduled Drift Detection:

```yaml
Schedule:
├── Cron: 0 9 * * 1-5  # 9 AM UTC, weekdays
├── Action: terraform plan -detailed-exitcode
├── Detect: Changes not managed by Terraform
└── Alert: Create GitHub issue if drift detected

Drift Detection Flow:
┌────────────────────────────────────────┐
│ Scheduled Trigger (daily 9 AM)        │
└────────────────────────────────────────┘
              ↓
┌────────────────────────────────────────┐
│ Run terraform plan                     │
│ - Exit code 0: No changes              │
│ - Exit code 1: Error                   │
│ - Exit code 2: Drift detected          │
└────────────────────────────────────────┘
              ↓
┌────────────────────────────────────────┐
│ If drift detected:                     │
│ - Create GitHub Issue                  │
│ - Assign to infra team                 │
│ - Include drift details                │
│ - Label: drift-detection               │
└────────────────────────────────────────┘
```

---

## 🔧 Troubleshooting Guide

### Common Issues:

#### 1. OIDC Authentication Fails

**Symptoms:**
```
Error: Failed to assume role
Error: Not authorized to perform sts:AssumeRoleWithWebIdentity
```

**Solutions:**
- Verify OIDC provider exists in AWS
- Check trust policy in GitHubActionsRole
- Verify repository name matches exactly
- Check GitHub Actions permissions (Settings → Actions → General → Workflow permissions)

#### 2. Terraform Init Fails

**Symptoms:**
```
Error: Failed to get existing workspaces
Error: Access Denied (S3 bucket)
```

**Solutions:**
- Verify backend.conf is correct
- Check S3 bucket permissions
- Verify TerraformStateAccessRole trust
- Check backend.conf path

#### 3. State Locking Issues

**Symptoms:**
```
Error: Error acquiring the state lock
Error: ConditionalCheckFailedException
```

**Solutions:**
- Check DynamoDB table exists
- Verify no other runs in progress
- Manually release lock if stuck:
  ```bash
  terraform force-unlock <LOCK_ID>
  ```

#### 4. Plan Artifact Not Found

**Symptoms:**
```
Error: Unable to download artifact
Warning: Artifact not found
```

**Solutions:**
- Verify plan job completed successfully
- Check artifact name matches
- Ensure apply job runs on same workflow run

#### 5. GitHub Environment Not Protecting

**Symptoms:**
- Apply runs without approval
- No reviewers requested

**Solutions:**
- Verify environment exists in Settings → Environments
- Check protection rules configured
- Verify workflow specifies environment correctly
- Check branch matches deployment branch rule

---

## 📚 Required GitHub Repository Configuration

### 1. Repository Variables:

```
Settings → Secrets and variables → Actions → Variables tab → New repository variable

Phase 1:
└── AWS_ROLE_ARN
    └── arn:aws:iam::265245191272:role/GitHubActionsRole
```

**Note:** Use variables (not secrets) for role ARNs because:
- Role ARNs are not sensitive (visible in AWS Console, CloudTrail)
- They don't grant access without OIDC token
- Variables are visible in logs, making debugging easier
- This is the recommended approach per GitHub documentation

### 2. Repository Environments:

```
Settings → Environments → New environment

Environment: shared-account
├── Protection rules:
│   ├── Required reviewers: 1
│   ├── Reviewers: @infra-team
│   └── Deployment branches: master
└── Environment variables:
    └── (No environment-specific variables needed)

Phase 3:
Environment: dev-account
├── Protection rules: (Optional)
└── Variables: AWS_ROLE_ARN (Dev role)

Environment: prod-account
├── Protection rules:
│   ├── Required reviewers: 2
│   ├── Reviewers: @infra-team-leads
│   └── Wait timer: 5 minutes
└── Variables: AWS_ROLE_ARN (Prod role)
```

### 2. Repository Secrets:

```
Settings → Secrets and variables → Actions → Secrets tab

No secrets required for Phase 1!

Future phases may add:
- INFRACOST_API_KEY (for cost estimation)
- SLACK_WEBHOOK_URL (for notifications)
```

### 3. Branch Protection (Recommended):

```
Settings → Branches → Add branch protection rule

Branch name pattern: master

Protection rules:
├── ✅ Require pull request reviews before merging
│   └── Required approvals: 1
├── ✅ Require status checks to pass before merging
│   ├── terraform-validate
│   └── terraform-plan
├── ✅ Require conversation resolution before merging
├── ✅ Do not allow bypassing the above settings
└── ✅ Restrict who can push to matching branches
    └── Infra team only
```

### 4. GitHub Actions Permissions:

```
Settings → Actions → General

Workflow permissions:
└── ◉ Read and write permissions
    └── ✅ Allow GitHub Actions to create and approve pull requests
```

### 5. CODEOWNERS File:

```
.github/CODEOWNERS

# Infrastructure team owns all Terraform code
aws/ @altanova-cloud/infra-team
.github/workflows/ @altanova-cloud/infra-team
docs/ @altanova-cloud/infra-team
```

---

## 📈 Success Metrics

### Phase 1 Success Criteria:

- ✅ GitHub OIDC authentication works
- ✅ Terraform validate passes on every PR
- ✅ Terraform plan generates and uploads artifact
- ✅ Plan output commented on PRs
- ✅ Manual approval required before apply
- ✅ Apply succeeds on merge to master
- ✅ No static AWS credentials in repository
- ✅ Infra team can approve/reject deployments
- ✅ Documentation is comprehensive

### Key Performance Indicators:

```
Deployment Metrics:
├── Time to plan: < 5 minutes
├── Time to apply: < 10 minutes
├── PR feedback time: < 2 minutes
└── Deployment frequency: On-demand

Quality Metrics:
├── Failed validations: Track and reduce
├── Failed plans: Track root causes
├── Failed applies: Should be near zero
└── Drift detected: Track and remediate

Security Metrics:
├── No static credentials: 100%
├── All changes via PR: 100%
├── Manual approval for prod: 100%
└── Security scans passing: > 95%
```

---

## 🗓️ Implementation Timeline

### Week 1: Phase 1 Foundation

```
Day 1-2: Setup
├── Create github-oidc Terraform module
├── Deploy GitHub OIDC provider to AWS
├── Test OIDC authentication manually
└── Create GitHubActionsRole with permissions

Day 3-4: Workflow Development
├── Create terraform-shared.yml workflow
├── Configure repository secrets
├── Create shared-account environment
└── Test validate and plan jobs

Day 5: Testing & Documentation
├── Test end-to-end workflow
├── Finalize PIPELINE.md
├── Update CLAUDE.md
└── Team training session
```

### Week 2: Phase 2 Security & Quality

```
Day 1-2: Security Tools
├── Add TFLint integration
├── Configure Checkov scanning
├── Add TFSec analysis
└── Test security scans

Day 3-4: Enhanced Features
├── Add cost estimation (Infracost)
├── Enhance PR comments
├── Add status badges
└── Improve error handling

Day 5: Documentation & Review
├── Update PIPELINE.md
├── Create security runbook
└── Team review and feedback
```

### Week 3-4: Phase 3 Multi-Environment

```
Week 3: Dev Environment
├── Create terraform-dev.yml
├── Configure dev environment
├── Test dev deployments
└── Deploy sample infrastructure

Week 4: Prod Environment
├── Create terraform-prod.yml
├── Configure prod protected environment
├── Setup prod reviewers
├── Test prod approval flow
├── Add drift detection
└── Documentation updates
```

---

## 🎓 Team Training & Onboarding

### For Infrastructure Team:

**Required Knowledge:**
- ✅ GitHub Actions basics
- ✅ Terraform fundamentals
- ✅ AWS IAM and OIDC
- ✅ CI/CD concepts

**Training Topics:**
1. How to review Terraform plans in PRs
2. When to approve/reject deployments
3. How to troubleshoot failed workflows
4. Manual intervention procedures
5. Rollback procedures

### Common Workflows:

#### Deploying a Change:
```bash
# 1. Create feature branch
git checkout -b feature/add-ecr-repository

# 2. Make Terraform changes
cd aws/environments/shared-account
# Edit main.tf, variables.tf, etc.

# 3. Validate locally (recommended)
terraform fmt -recursive
terraform validate

# 4. Commit and push
git add .
git commit -m "Add ECR repository for app-service"
git push origin feature/add-ecr-repository

# 5. Create PR on GitHub
# 6. Review automated plan in PR comments
# 7. Request review from infra team
# 8. Address feedback
# 9. Merge PR
# 10. Approve apply job when requested
```

#### Reviewing a Deployment:
```
1. Navigate to PR
2. Review code changes (Files changed tab)
3. Review terraform plan output (comment)
4. Check for:
   - Resource additions/deletions
   - Security implications
   - Cost impact
   - Compliance requirements
5. Approve or request changes
6. After merge, approve deployment:
   - Navigate to Actions tab
   - Click on running workflow
   - Click "Review deployments"
   - Select environment
   - Approve or Reject with comment
```

---

## 📖 References & Resources

### GitHub Actions Documentation:
- [OIDC with AWS](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [Workflow Syntax](https://docs.github.com/en/actions/reference/workflow-syntax-for-github-actions)
- [Environment Protection](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)

### Terraform Documentation:
- [S3 Backend](https://www.terraform.io/docs/language/settings/backends/s3.html)
- [AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

### Security Tools:
- [TFLint](https://github.com/terraform-linters/tflint)
- [Checkov](https://www.checkov.io/)
- [TFSec](https://aquasecurity.github.io/tfsec/)
- [Infracost](https://www.infracost.io/)

### Related Documentation:
- [ARCHITECTURE.md](./ARCHITECTURE.md) - AWS multi-account architecture
- [CLAUDE.md](../CLAUDE.md) - AI assistant guidance
- [Bootstrap Guide](../aws/modules/bootstrap/BOOTSTRAP_GUIDE.md)

---

## 🔄 Document Maintenance

**This document must be updated when:**
- ✅ New workflow phases are implemented
- ✅ Pipeline structure changes
- ✅ New security tools added
- ✅ Approval process changes
- ✅ New environments added
- ✅ Best practices evolve

**Update Process:**
1. Make changes to PIPELINE.md
2. Update version/date at bottom
3. Notify team of changes
4. Update CLAUDE.md if AI assistant guidance needed

**Document Owner:** Infrastructure Team
**Last Updated:** 2025-12-05
**Version:** 1.1.0 (Phase 3 Multi-Environment Implementation)
**Next Review:** After Phase 4 implementation

---

## ✅ Approval Checklist

Before proceeding with implementation, confirm:

- [ ] Plan reviewed and understood by team
- [ ] GitHub repository permissions confirmed
- [ ] AWS account access verified
- [ ] Infra team members identified (3 people for reviewers)
- [ ] Timeline is acceptable
- [ ] Security requirements met
- [ ] Branch name corrected to `master` (not main)
- [ ] All questions addressed

**Approved by:**
**Date:**
**Implementation Start Date:**

---

**End of PIPELINE.md**
