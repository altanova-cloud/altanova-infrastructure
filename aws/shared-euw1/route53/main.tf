# =============================================================================
# Route53 - Shared Account (eu-west-1)
# =============================================================================
# State: shared-euw1-route53
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

locals {
  environment = "shared"
  region      = "eu-west-1"
  domain_name = "altanova.cloud"
}

provider "aws" {
  region = local.region

  default_tags {
    tags = {
      Environment = local.environment
      Region      = local.region
      ManagedBy   = "Terraform"
      Project     = "AltaNova"
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
