# Data Sources
data "aws_caller_identity" "current" {}

# S3 Bucket for Terraform State
resource "aws_s3_bucket" "terraform_state" {
  bucket = var.bucket_name

  # Prevent accidental deletion of this S3 bucket
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "enabled" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "default" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "terraform_locks" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

# Cross-Account IAM Role for Terraform State Access
resource "aws_iam_role" "terraform_state_access" {
  name = "TerraformStateAccessRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::${var.dev_account_id}:root",
            "arn:aws:iam::${var.prod_account_id}:root",
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/GitLabRunnerRole"
          ]
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "terraform_state_access_policy" {
  name = "TerraformStateAccessPolicy"
  role = aws_iam_role.terraform_state_access.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject" # Needed for state manipulation if necessary
        ]
        Resource = [
          aws_s3_bucket.terraform_state.arn,
          "${aws_s3_bucket.terraform_state.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = aws_dynamodb_table.terraform_locks.arn
      }
    ]
  })
}

# GitLab OIDC Provider
resource "aws_iam_openid_connect_provider" "gitlab" {
  url = var.gitlab_url

  client_id_list = [
    "https://gitlab.com", # Default audience for GitLab.com
  ]

  thumbprint_list = [
    "9e99a48a9960b14926bb7f3b02e22da2b0ab7280" # GitLab.com thumbprint (verify if using self-hosted)
  ]
}

# IAM Role for GitLab Runner
resource "aws_iam_role" "gitlab_runner" {
  name = "GitLabRunnerRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.gitlab.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringLike = {
            "${replace(var.gitlab_url, "https://", "")}:sub" : "project_path:${var.gitlab_project_path}:ref_type:branch:ref:*"
          }
        }
      }
    ]
  })
}

# Policy to assume roles in other accounts
resource "aws_iam_role_policy" "gitlab_runner_assume_role" {
  name = "AssumeDeploymentRoles"
  role = aws_iam_role.gitlab_runner.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Resource = [
          "arn:aws:iam::${var.dev_account_id}:role/DevDeployRole",
          "arn:aws:iam::${var.prod_account_id}:role/ProdDeployRole"
        ]
      }
    ]
  })
}

# Scoped permissions for Shared Account deployments
resource "aws_iam_role_policy" "gitlab_runner_shared" {
  name = "SharedAccountDeployment"
  role = aws_iam_role.gitlab_runner.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:*",
          "dynamodb:*",
          "iam:*",
          "sts:*"
        ]
        Resource = "*"
      }
    ]
  })
}
