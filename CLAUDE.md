# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Multi-account AWS infrastructure management using Terraform. Three AWS accounts: Shared (state management, OIDC), Dev, and Prod. Uses OIDC federation for secure CI/CD authentication without static credentials.

**Note:** GitHub Actions CI/CD pipeline is implemented. See `docs/PIPELINE.md` for complete documentation.

## Development Commands

```bash
# Initialize Terraform (with backend)
cd aws/environments/dev-app-account
terraform init -backend-config=backend.conf

# Validate and format
terraform validate
terraform fmt -check -recursive

# Lint
tflint --chdir=aws/environments/dev-app-account --recursive

# Security scanning
checkov -d aws/ --framework terraform
tfsec aws/ --config-file .tfsec.yml

# Plan and apply
terraform plan
terraform apply

# Docker-based (alternative)
docker-compose run terraform init
```

# Project Instructions

- The main architecture documentation is in `ARCHITECTURE.md` located at ./docs/ARCHITECTURE.md
- The CI/CD pipeline documentation is in `PIPELINE.md` located at ./docs/PIPELINE.md
- Always read `aws_architect.md` before making architectural decisions
- When making changes to the codebase structure, update `ARCHITECTURE.md` following its existing format, patterns, and diagrams
- When making changes to the CI/CD pipeline, update `PIPELINE.md` following its existing format, patterns, and diagrams
- ASK before modify the diagram syntax or structure in `ARCHITECTURE.md` or `PIPELINE.md` - only update content within the existing format
- Use tree and descriptive diagram whenever needed
- Do not use CLAUDE.md for architecture or pipeline documentation

## Architecture

### Directory Structure
- `aws/modules/` - Reusable Terraform modules (bootstrap, deployment-role, github-oidc, vpc)
- `aws/environments/` - Environment configs (shared-account, dev-app-account, prod-app-account)
- `docs/` - Architecture and pipeline documentation
- `.github/workflows/` - GitHub Actions CI/CD workflows

### Module Patterns
Each environment folder contains:
- `main.tf` - Module instantiation
- `variables.tf` / `outputs.tf` - Inputs and outputs
- `backend.tf` + `backend.conf` - State backend (partial config pattern)
- `terraform.auto.tfvars` - Auto-loaded defaults

### Cross-Account Access
- **GitHub Actions:** GitHubActionsRole (Shared) → Uses OIDC for authentication
- **GitLab (Legacy):** GitLabRunnerRole (Shared) → DevDeployRole/ProdDeployRole (App Accounts)
- **State Access:** TerraformStateAccessRole (Shared) for cross-account state access

### State Management
- S3 bucket: `altanova-tf-state-eu-central-1`
- DynamoDB lock table: `altanova-terraform-locks`
- Region: us-east-1

## Key Documentation

- `docs/ARCHITECTURE.md` - Multi-account AWS architecture design
- `docs/PIPELINE.md` - GitHub Actions CI/CD pipeline documentation (MUST READ before pipeline changes)
- `BOOTCAMP.md` - Comprehensive architecture overview
- `aws/modules/bootstrap/BOOTSTRAP_GUIDE.md` - One-time state setup
- Environment READMEs in `aws/environments/*/`

## Terraform Conventions

- Required version: >= 1.8, AWS provider ~> 5.0
- Variable naming: snake_case
- Locals for computed/dynamic values
- No hardcoded values - everything parameterized
- Security exclusions in `.checkov.yaml` and `.tfsec.yml` have documented justifications

## CI/CD Pipeline

### GitHub Actions Workflows
- `.github/workflows/terraform-shared.yml` - Shared Account deployment
- Main branch: `master` (not main)
- OIDC authentication: No static AWS credentials

### Workflow Triggers
- Pull requests to `master` → Validate + Plan
- Push to `master` → Apply (with manual approval via GitHub Environment)
- Manual dispatch → Plan or Apply

### Required GitHub Configuration
1. **Repository Secret:** `AWS_ROLE_ARN` = `arn:aws:iam::265245191272:role/GitHubActionsRole`
2. **Environment:** `shared-account` with protection rules and reviewers
3. **Branch Protection:** Recommended on `master` branch

### Pipeline Phases
- **Phase 1 (Current):** Basic workflow with manual approvals
- **Phase 2 (Future):** Security scanning (TFLint, Checkov, TFSec)
- **Phase 3 (Future):** Multi-environment (Dev, Prod workflows)
- **Phase 4 (Future):** Advanced automation features

See `docs/PIPELINE.md` for complete details on architecture, workflows, and troubleshooting.