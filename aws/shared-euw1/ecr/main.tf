# =============================================================================
# ECR - Shared Account (eu-west-1)
# =============================================================================
# State: shared-euw1-ecr
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

  tags = {
    Purpose = "Container Registry"
    Service = each.value
  }
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
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep last 10 untagged images"
        selection = {
          tagStatus   = "untagged"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = { type = "expire" }
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
        action = { type = "expire" }
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
