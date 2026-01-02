# Shared Account - ECR Repositories
# Container registries for AltanovaLLM platform services
#
# Repositories:
#   - control-plane: API Gateway and orchestration
#   - inference-service: AI model inference workloads
#   - tenant-console: Multi-tenant management UI
#   - audit-logger: Security audit logging service
#
# Cross-account access allows Dev and Prod EKS clusters to pull images

locals {
  project_name = "altanova"

  # ECR repositories to create
  ecr_repositories = [
    "control-plane",
    "inference-service",
    "tenant-console",
    "audit-logger"
  ]

  # Common tags for ECR resources
  ecr_tags = {
    Environment = "shared"
    ManagedBy   = "Terraform"
    Project     = "AltaNova"
    Purpose     = "Container Registry"
  }
}

# -----------------------------------------------------------------------------
# ECR Repositories
# -----------------------------------------------------------------------------
resource "aws_ecr_repository" "services" {
  for_each = toset(local.ecr_repositories)

  name                 = "${local.project_name}/${each.value}"
  image_tag_mutability = "IMMUTABLE" # Prevent tag overwrites for security

  # Enable image scanning on push
  image_scanning_configuration {
    scan_on_push = true
  }

  # Encryption with AWS managed key (cost-effective for dev/prod)
  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(local.ecr_tags, {
    Service = each.value
  })
}

# -----------------------------------------------------------------------------
# ECR Lifecycle Policy - Cleanup old images
# -----------------------------------------------------------------------------
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
        description  = "Keep last 10 untagged images (for rollback)"
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

# -----------------------------------------------------------------------------
# ECR Repository Policy - Cross-Account Access
# Allow Dev and Prod accounts to pull images
# -----------------------------------------------------------------------------
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
            "arn:aws:iam::${var.dev_account_id}:root",
            "arn:aws:iam::${var.prod_account_id}:root"
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
      },
      {
        Sid    = "AllowGitHubActionsPush"
        Effect = "Allow"
        Principal = {
          AWS = module.github_oidc.role_arn
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:DescribeImages",
          "ecr:ListImages"
        ]
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# IAM Policy for GitHub Actions to push to ECR
# Attached to GitHubActionsRole
# -----------------------------------------------------------------------------
resource "aws_iam_role_policy" "ecr_push" {
  name = "ECRPush"
  role = module.github_oidc.role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAuth"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECRPush"
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:DescribeImages",
          "ecr:ListImages"
        ]
        Resource = [for repo in aws_ecr_repository.services : repo.arn]
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------
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
  value       = aws_ecr_repository.services["control-plane"].registry_id
}
