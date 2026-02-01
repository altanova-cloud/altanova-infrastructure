# =============================================================================
# ECR - Workspace-based Container Registries
# =============================================================================
#
# Uses Terraform workspaces for environment + region separation.
#
# Workspace naming: shared-{region_code}
#   - shared-euw1  (Shared in eu-west-1)
#   - shared-eus2  (Shared in eu-south-2 Spain)
#   - shared-use1  (Shared in us-east-1)
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

  # Account IDs
  dev_account_id  = "975050047325"
  prod_account_id = "624755517249"

  # ECR Configuration
  project_name = "altanova"
  ecr_repositories = [
    "control-plane",
    "inference-service",
    "tenant-console",
    "audit-logger"
  ]

  ecr_tags = {
    Purpose = "Container Registry"
  }
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
# ECR Repositories
# =============================================================================
resource "aws_ecr_repository" "services" {
  for_each = toset(local.ecr_repositories)

  name                 = "${local.project_name}/${each.value}"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(local.ecr_tags, {
    Service = each.value
  })
}

# =============================================================================
# ECR Lifecycle Policy
# =============================================================================
resource "aws_ecr_lifecycle_policy" "services" {
  for_each   = aws_ecr_repository.services
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 30 tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "release"]
          countType     = "imageCountMoreThan"
          countNumber   = 30
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep last 10 untagged images"
        selection = {
          tagStatus   = "untagged"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 3
        description  = "Delete images older than 90 days"
        selection = {
          tagStatus   = "any"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 90
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# =============================================================================
# ECR Repository Policy - Cross-Account Access
# =============================================================================
resource "aws_ecr_repository_policy" "cross_account_pull" {
  for_each   = aws_ecr_repository.services
  repository = each.value.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCrossAccountPull"
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::${local.dev_account_id}:root",
            "arn:aws:iam::${local.prod_account_id}:root"
          ]
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:DescribeRepositories",
          "ecr:DescribeImages",
          "ecr:ListImages"
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

output "ecr_repository_urls" {
  description = "Map of ECR repository URLs"
  value       = { for k, v in aws_ecr_repository.services : k => v.repository_url }
}

output "ecr_repository_arns" {
  description = "Map of ECR repository ARNs"
  value       = { for k, v in aws_ecr_repository.services : k => v.arn }
}

output "ecr_registry_id" {
  description = "ECR registry ID (AWS account ID)"
  value       = values(aws_ecr_repository.services)[0].registry_id
}
