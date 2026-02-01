# =============================================================================
# Route53 - Workspace-based DNS Management
# =============================================================================
#
# Uses Terraform workspaces for environment + region separation.
#
# Workspace naming: shared-{region_code}
#   - shared-euw1  (Shared in eu-west-1)
#   - shared-eus2  (Shared in eu-south-2 Spain)
#   - shared-use1  (Shared in us-east-1)
#
# Note: Route53 is a global service but we use region for consistency.
#
# Usage:
#   terraform workspace new shared-euw1
#   terraform workspace select shared-euw1
#   terraform plan
# =============================================================================

terraform {
  required_version = ">= 1.8"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "http" {}
}

# =============================================================================
# Workspace Configuration
# =============================================================================
locals {
  # Parse workspace: "shared-euw1" -> env="shared", region_code="euw1"
  workspace_parts = split("-", terraform.workspace)
  environment     = local.workspace_parts[0]
  region_code     = local.workspace_parts[1]

  # Region mapping
  region_map = {
    euw1 = "eu-west-1"
    euw2 = "eu-west-2"
    eus2 = "eu-south-2" # Spain
    use1 = "us-east-1"
    use2 = "us-east-2"
  }
  region = local.region_map[local.region_code]

  # DNS Configuration
  domain_name = "altanova.cloud"
}

# =============================================================================
# Provider
# =============================================================================
provider "aws" {
  region = local.region

  default_tags {
    tags = {
      Environment = local.environment
      Region      = local.region
      ManagedBy   = "Terraform"
      Project     = "AltaNova"
      Workspace   = terraform.workspace
    }
  }
}

# =============================================================================
# Route53 Hosted Zone
# =============================================================================
resource "aws_route53_zone" "main" {
  name    = local.domain_name
  comment = "Managed by Terraform - AltanovaLLM platform"

  tags = {
    Purpose = "DNS Management"
  }
}

# =============================================================================
# IAM Policy for Cross-Account DNS Management
# =============================================================================
resource "aws_iam_policy" "route53_manage_records" {
  name        = "Route53ManageRecords"
  description = "Allow managing Route53 records in the shared hosted zone"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListHostedZones"
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:GetHostedZone",
          "route53:ListResourceRecordSets"
        ]
        Resource = "*"
      },
      {
        Sid    = "ManageRecords"
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:GetChange"
        ]
        Resource = [
          aws_route53_zone.main.arn,
          "arn:aws:route53:::change/*"
        ]
      }
    ]
  })
}

# =============================================================================
# Outputs
# =============================================================================
output "workspace" {
  description = "Current workspace"
  value       = terraform.workspace
}

output "environment" {
  description = "Environment"
  value       = local.environment
}

output "region" {
  description = "AWS Region"
  value       = local.region
}

output "route53_zone_id" {
  description = "Route53 hosted zone ID"
  value       = aws_route53_zone.main.zone_id
}

output "route53_zone_name" {
  description = "Route53 hosted zone name"
  value       = aws_route53_zone.main.name
}

output "route53_name_servers" {
  description = "Route53 name servers - Configure these at your domain registrar"
  value       = aws_route53_zone.main.name_servers
}

output "route53_zone_arn" {
  description = "Route53 hosted zone ARN"
  value       = aws_route53_zone.main.arn
}

output "route53_manage_policy_arn" {
  description = "ARN of the Route53 management policy"
  value       = aws_iam_policy.route53_manage_records.arn
}
