resource "aws_iam_role" "deployment" {
  name = "${title(var.environment)}DeployRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = var.github_actions_role_arn
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })

  tags = {
    Name        = "${title(var.environment)}DeployRole"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Purpose     = "GitHub Actions deployment role"
  }
}

# Deployment permissions - scoped to common infrastructure resources
resource "aws_iam_role_policy" "deployment" {
  name = "${title(var.environment)}DeploymentPolicy"
  role = aws_iam_role.deployment.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # EC2 and VPC permissions
      {
        Effect = "Allow"
        Action = [
          "ec2:*",
          "elasticloadbalancing:*"
        ]
        Resource = "*"
      },
      # EKS permissions
      {
        Effect = "Allow"
        Action = [
          "eks:*"
        ]
        Resource = "*"
      },
      # RDS permissions
      {
        Effect = "Allow"
        Action = [
          "rds:*"
        ]
        Resource = "*"
      },
      # Secrets Manager permissions
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:CreateSecret",
          "secretsmanager:DeleteSecret",
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecret",
          "secretsmanager:TagResource",
          "secretsmanager:UntagResource",
          "secretsmanager:ListSecrets"
        ]
        Resource = "*"
      },
      # S3 permissions (excluding state bucket)
      {
        Effect = "Allow"
        Action = [
          "s3:*"
        ]
        Resource = "*"
      },
      # DynamoDB permissions
      {
        Effect = "Allow"
        Action = [
          "dynamodb:*"
        ]
        Resource = "*"
      },
      # Lambda permissions
      {
        Effect = "Allow"
        Action = [
          "lambda:*"
        ]
        Resource = "*"
      },
      # CloudWatch and Logs
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:*",
          "logs:*"
        ]
        Resource = "*"
      },
      # IAM permissions (limited)
      {
        Effect = "Allow"
        Action = [
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:ListPolicyVersions",
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:CreatePolicyVersion",
          "iam:DeletePolicyVersion",
          "iam:PassRole"
        ]
        Resource = "*"
      },
      # STS - Allow assuming state access role
      {
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = var.state_access_role_arn
      },
      # Tags
      {
        Effect = "Allow"
        Action = [
          "tag:GetResources",
          "tag:TagResources",
          "tag:UntagResources"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach additional policies if provided
resource "aws_iam_role_policy_attachment" "additional" {
  count      = length(var.additional_policies)
  role       = aws_iam_role.deployment.name
  policy_arn = var.additional_policies[count.index]
}
