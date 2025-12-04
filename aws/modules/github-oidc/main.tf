terraform {
  required_version = ">= 1.8"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Data source to get current AWS account ID
data "aws_caller_identity" "current" {}

# Data source to get current AWS region
data "aws_region" "current" {}

# Construct the subject claim for GitHub OIDC
locals {
  # If branch restriction is specified, use it; otherwise allow all refs
  subject_claim = var.restrict_to_branch != "" ? "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/${var.restrict_to_branch}" : "repo:${var.github_org}/${var.github_repo}:*"
}

# IAM Role for GitHub Actions with OIDC trust
resource "aws_iam_role" "github_actions" {
  name               = var.role_name
  description        = "Role for GitHub Actions to deploy infrastructure via OIDC"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

  tags = merge(
    var.tags,
    {
      Name        = var.role_name
      ManagedBy   = "Terraform"
      Purpose     = "GitHub Actions OIDC"
      Repository  = "${var.github_org}/${var.github_repo}"
    }
  )
}

# Trust policy for GitHub OIDC
data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com", "sigv4.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [local.subject_claim]
    }
  }
}

# IAM Policy for Terraform state management
resource "aws_iam_policy" "terraform_state_access" {
  name        = "${var.role_name}-TerraformStateAccess"
  description = "Policy for GitHub Actions to access Terraform state"
  policy      = data.aws_iam_policy_document.terraform_state_access.json

  tags = merge(
    var.tags,
    {
      Name      = "${var.role_name}-TerraformStateAccess"
      ManagedBy = "Terraform"
    }
  )
}

# Policy document for Terraform state access
data "aws_iam_policy_document" "terraform_state_access" {
  # S3 bucket access for state files
  statement {
    sid    = "TerraformStateS3Access"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketVersioning",
      "s3:GetBucketLocation",
      "s3:GetBucketPolicy",
      "s3:GetBucketTagging",
      "s3:GetBucketPublicAccessBlock",
      "s3:GetBucketAcl",
      "s3:GetBucketCORS",
      "s3:GetBucketWebsite",
      "s3:GetBucketLogging",
      "s3:GetBucketRequestPayment",
      "s3:GetBucketObjectLockConfiguration",
      "s3:GetEncryptionConfiguration",
      "s3:GetLifecycleConfiguration",
      "s3:GetReplicationConfiguration",
      "s3:GetAccelerateConfiguration"
    ]
    resources = [var.state_bucket_arn]
  }

  statement {
    sid    = "TerraformStateS3ObjectAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetObjectTagging",
      "s3:GetObjectVersionTagging",
      "s3:PutObject",
      "s3:PutObjectTagging",
      "s3:DeleteObject",
      "s3:DeleteObjectVersion"
    ]
    resources = ["${var.state_bucket_arn}/*"]
  }

  # DynamoDB table access for state locking
  statement {
    sid    = "TerraformStateLockAccess"
    effect = "Allow"
    actions = [
      "dynamodb:DescribeTable",
      "dynamodb:DescribeContinuousBackups",
      "dynamodb:DescribeTimeToLive",
      "dynamodb:ListTagsOfResource",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem"
    ]
    resources = [var.dynamodb_table_arn]
  }

  # AssumeRole to TerraformStateAccessRole (for cross-account state access)
  statement {
    sid    = "AssumeStateAccessRole"
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]
    resources = [var.state_access_role_arn]
  }
}

# IAM Policy for Shared Account infrastructure management
resource "aws_iam_policy" "shared_account_access" {
  name        = "${var.role_name}-SharedAccountAccess"
  description = "Policy for GitHub Actions to manage Shared Account infrastructure"
  policy      = data.aws_iam_policy_document.shared_account_access.json

  tags = merge(
    var.tags,
    {
      Name      = "${var.role_name}-SharedAccountAccess"
      ManagedBy = "Terraform"
    }
  )
}

# Policy document for Shared Account infrastructure
data "aws_iam_policy_document" "shared_account_access" {
  # IAM permissions for managing OIDC and roles
  statement {
    sid    = "IAMManagement"
    effect = "Allow"
    actions = [
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:ListPolicyVersions",
      "iam:GetOpenIDConnectProvider",
      "iam:ListOpenIDConnectProviders"
    ]
    resources = ["*"]
  }

  # IAM permissions for updating managed resources
  statement {
    sid    = "IAMUpdateManagedResources"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:UpdateRole",
      "iam:DeleteRole",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:CreatePolicy",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicy",
      "iam:DeletePolicyVersion",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:TagPolicy",
      "iam:UntagPolicy"
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/GitHub*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/GitHub*"
    ]
  }

  # ECR permissions (Phase 2 - Shared Services)
  statement {
    sid    = "ECRManagement"
    effect = "Allow"
    actions = [
      "ecr:DescribeRepositories",
      "ecr:ListTagsForResource",
      "ecr:GetRepositoryPolicy",
      "ecr:GetLifecyclePolicy",
      "ecr:CreateRepository",
      "ecr:DeleteRepository",
      "ecr:PutImageTagMutability",
      "ecr:PutImageScanningConfiguration",
      "ecr:PutLifecyclePolicy",
      "ecr:SetRepositoryPolicy",
      "ecr:TagResource",
      "ecr:UntagResource"
    ]
    resources = ["*"]
  }

  # Secrets Manager (Phase 2 - Shared Services)
  statement {
    sid    = "SecretsManagerManagement"
    effect = "Allow"
    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:ListSecrets",
      "secretsmanager:ListSecretVersionIds",
      "secretsmanager:CreateSecret",
      "secretsmanager:DeleteSecret",
      "secretsmanager:UpdateSecret",
      "secretsmanager:PutResourcePolicy",
      "secretsmanager:TagResource",
      "secretsmanager:UntagResource"
    ]
    resources = ["*"]
  }
}

# Attach policies to the role
resource "aws_iam_role_policy_attachment" "terraform_state_access" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.terraform_state_access.arn
}

resource "aws_iam_role_policy_attachment" "shared_account_access" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.shared_account_access.arn
}

# Attach any additional policies
resource "aws_iam_role_policy_attachment" "additional" {
  count      = length(var.additional_policy_arns)
  role       = aws_iam_role.github_actions.name
  policy_arn = var.additional_policy_arns[count.index]
}
