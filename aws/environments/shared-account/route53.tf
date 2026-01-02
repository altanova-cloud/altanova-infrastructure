# Shared Account - Route53 Hosted Zone
# Centralized DNS management for AltanovaLLM platform
#
# Domain is registered externally at one.com
# After creating this hosted zone, configure NS records at the registrar
#
# Structure:
#   altanova.cloud (hosted zone - shared account)
#   ├── dev.altanova.cloud  (delegated to Dev account if needed)
#   └── prod.altanova.cloud (delegated to Prod account if needed)

# -----------------------------------------------------------------------------
# Route53 Hosted Zone
# -----------------------------------------------------------------------------
resource "aws_route53_zone" "main" {
  name    = var.domain_name
  comment = "Managed by Terraform - AltanovaLLM platform"

  tags = {
    Environment = "shared"
    ManagedBy   = "Terraform"
    Project     = "AltaNova"
    Purpose     = "DNS Management"
  }
}

# -----------------------------------------------------------------------------
# Dev Environment Subdomain Zone (Optional - for delegation)
# Uncomment if you want to delegate dev.domain.com to the dev account
# -----------------------------------------------------------------------------
# resource "aws_route53_zone" "dev" {
#   name    = "dev.${var.domain_name}"
#   comment = "Dev environment subdomain - Managed by Terraform"
#
#   tags = {
#     Environment = "dev"
#     ManagedBy   = "Terraform"
#     Project     = "AltaNova"
#   }
# }
#
# resource "aws_route53_record" "dev_ns" {
#   zone_id = aws_route53_zone.main.zone_id
#   name    = "dev.${var.domain_name}"
#   type    = "NS"
#   ttl     = 300
#   records = aws_route53_zone.dev.name_servers
# }

# -----------------------------------------------------------------------------
# IAM Policy for Cross-Account DNS Management
# Allow Dev/Prod accounts to create records in the shared hosted zone
# -----------------------------------------------------------------------------
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

# Attach policy to GitHub Actions role for External DNS and cert validation
resource "aws_iam_role_policy_attachment" "github_actions_route53" {
  role       = module.github_oidc.role_name
  policy_arn = aws_iam_policy.route53_manage_records.arn
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------
output "route53_zone_id" {
  description = "Route53 hosted zone ID"
  value       = aws_route53_zone.main.zone_id
}

output "route53_zone_name" {
  description = "Route53 hosted zone name"
  value       = aws_route53_zone.main.name
}

output "route53_name_servers" {
  description = "Route53 name servers - Configure these at your domain registrar (one.com)"
  value       = aws_route53_zone.main.name_servers
}

output "route53_zone_arn" {
  description = "Route53 hosted zone ARN"
  value       = aws_route53_zone.main.arn
}
