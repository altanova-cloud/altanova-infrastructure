# =============================================================================
# AWS Resource Access Manager (RAM) - Subnet Sharing
# =============================================================================
#
# Shares private and database subnets with Dev and Prod accounts so they can
# deploy EKS clusters and RDS instances in the shared VPC.
#
# Key Points:
#   - Only private and database subnets are shared (not public)
#   - Public subnets stay in Shared Account (for ALB, NAT Gateway)
#   - RAM sharing is automatic within AWS Organization
# =============================================================================

# =============================================================================
# RAM Resource Share
# =============================================================================
resource "aws_ram_resource_share" "network" {
  name                      = "${var.project_name}-shared-network"
  allow_external_principals = false # Only share within Organization

  tags = merge(var.tags, {
    Name      = "${var.project_name}-shared-network"
    ManagedBy = "Terraform"
    Purpose   = "VPC Subnet Sharing"
  })
}

# =============================================================================
# RAM Principal Associations (Dev and Prod Accounts)
# =============================================================================
resource "aws_ram_principal_association" "dev" {
  count              = var.dev_account_id != "" ? 1 : 0
  resource_share_arn = aws_ram_resource_share.network.arn
  principal          = var.dev_account_id
}

resource "aws_ram_principal_association" "prod" {
  count              = var.prod_account_id != "" ? 1 : 0
  resource_share_arn = aws_ram_resource_share.network.arn
  principal          = var.prod_account_id
}

# =============================================================================
# RAM Resource Associations - Dev Private Subnets
# =============================================================================
resource "aws_ram_resource_association" "dev_private_subnets" {
  count              = 2
  resource_share_arn = aws_ram_resource_share.network.arn
  resource_arn       = "arn:aws:ec2:${var.region}:${var.shared_account_id}:subnet/${module.vpc.private_subnets[count.index]}"
}

# =============================================================================
# RAM Resource Associations - Dev Database Subnets
# =============================================================================
resource "aws_ram_resource_association" "dev_database_subnets" {
  count              = 2
  resource_share_arn = aws_ram_resource_share.network.arn
  resource_arn       = "arn:aws:ec2:${var.region}:${var.shared_account_id}:subnet/${module.vpc.database_subnets[count.index]}"
}

# =============================================================================
# RAM Resource Associations - Prod Private Subnets
# =============================================================================
resource "aws_ram_resource_association" "prod_private_subnets" {
  count              = 2
  resource_share_arn = aws_ram_resource_share.network.arn
  resource_arn       = "arn:aws:ec2:${var.region}:${var.shared_account_id}:subnet/${module.vpc.private_subnets[count.index + 2]}"
}

# =============================================================================
# RAM Resource Associations - Prod Database Subnets
# =============================================================================
resource "aws_ram_resource_association" "prod_database_subnets" {
  count              = 2
  resource_share_arn = aws_ram_resource_share.network.arn
  resource_arn       = "arn:aws:ec2:${var.region}:${var.shared_account_id}:subnet/${module.vpc.database_subnets[count.index + 2]}"
}

# =============================================================================
# RAM Resource Associations - Dev Public Subnets (for ALB in shared subnets)
# =============================================================================
resource "aws_ram_resource_association" "dev_public_subnets" {
  count              = 2
  resource_share_arn = aws_ram_resource_share.network.arn
  resource_arn       = "arn:aws:ec2:${var.region}:${var.shared_account_id}:subnet/${module.vpc.public_subnets[count.index]}"
}

# =============================================================================
# RAM Resource Associations - Prod Public Subnets (for ALB in shared subnets)
# =============================================================================
resource "aws_ram_resource_association" "prod_public_subnets" {
  count              = 2
  resource_share_arn = aws_ram_resource_share.network.arn
  resource_arn       = "arn:aws:ec2:${var.region}:${var.shared_account_id}:subnet/${module.vpc.public_subnets[count.index + 2]}"
}
