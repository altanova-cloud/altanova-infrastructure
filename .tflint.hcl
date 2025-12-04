# TFLint Configuration
# Phase 2: Security scanning integration
#
# Documentation: https://github.com/terraform-linters/tflint/blob/master/docs/user-guide/config.md

# =========================================
# TFLint Core Configuration
# =========================================
config {
  # Module inspection (set to true to inspect child modules)
  module = false

  # Force all rules to produce errors (can override per-rule)
  force = false
}

# =========================================
# AWS Plugin Configuration
# =========================================
plugin "aws" {
  enabled = true
  version = "0.31.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# =========================================
# Terraform Plugin (Built-in rules)
# =========================================
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# =========================================
# Rule Overrides
# =========================================

# Enforce naming conventions
rule "terraform_naming_convention" {
  enabled = true
  format  = "snake_case"
}

# Require Terraform version constraint
rule "terraform_required_version" {
  enabled = true
}

# Require provider version constraints
rule "terraform_required_providers" {
  enabled = true
}

# Warn on deprecated syntax
rule "terraform_deprecated_index" {
  enabled = true
}

# Warn on deprecated interpolation
rule "terraform_deprecated_interpolation" {
  enabled = true
}

# Comment documentation
rule "terraform_comment_syntax" {
  enabled = true
}

# Standard module structure
rule "terraform_standard_module_structure" {
  enabled = true
}

# Unused declarations
rule "terraform_unused_declarations" {
  enabled = true
}

# =========================================
# AWS-Specific Rules
# =========================================

# Ensure valid instance types
rule "aws_instance_invalid_type" {
  enabled = true
}

# Ensure valid AMI IDs format
rule "aws_instance_invalid_ami" {
  enabled = true
}

# S3 bucket naming
rule "aws_s3_bucket_invalid_name" {
  enabled = true
}

# IAM policy document validation
rule "aws_iam_policy_document_gov_friendly_arns" {
  enabled = false  # Not using GovCloud
}

# =========================================
# Disabled Rules (with justification)
# =========================================

# Disabled: We use snake_case variables, not description enforcement
rule "terraform_documented_variables" {
  enabled = false
}

# Disabled: Module sources use relative paths
rule "terraform_module_pinned_source" {
  enabled = false
}
