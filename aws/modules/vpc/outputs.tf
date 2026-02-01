# =============================================================================
# VPC Module Outputs
# =============================================================================

# -----------------------------------------------------------------------------
# VPC Outputs
# -----------------------------------------------------------------------------
output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "vpc_arn" {
  description = "The ARN of the VPC"
  value       = module.vpc.vpc_arn
}

# -----------------------------------------------------------------------------
# All Subnets (for reference)
# -----------------------------------------------------------------------------
output "public_subnets" {
  description = "List of all public subnet IDs"
  value       = module.vpc.public_subnets
}

output "private_subnets" {
  description = "List of all private subnet IDs"
  value       = module.vpc.private_subnets
}

output "database_subnets" {
  description = "List of all database subnet IDs"
  value       = module.vpc.database_subnets
}

# -----------------------------------------------------------------------------
# Dev Environment Subnets
# -----------------------------------------------------------------------------
output "dev_public_subnet_ids" {
  description = "Dev environment public subnet IDs"
  value       = slice(module.vpc.public_subnets, 0, 2)
}

output "dev_private_subnet_ids" {
  description = "Dev environment private subnet IDs"
  value       = slice(module.vpc.private_subnets, 0, 2)
}

output "dev_database_subnet_ids" {
  description = "Dev environment database subnet IDs"
  value       = slice(module.vpc.database_subnets, 0, 2)
}

# -----------------------------------------------------------------------------
# Prod Environment Subnets
# -----------------------------------------------------------------------------
output "prod_public_subnet_ids" {
  description = "Prod environment public subnet IDs"
  value       = slice(module.vpc.public_subnets, 2, 4)
}

output "prod_private_subnet_ids" {
  description = "Prod environment private subnet IDs"
  value       = slice(module.vpc.private_subnets, 2, 4)
}

output "prod_database_subnet_ids" {
  description = "Prod environment database subnet IDs"
  value       = slice(module.vpc.database_subnets, 2, 4)
}

# -----------------------------------------------------------------------------
# Subnet ARNs for RAM Sharing
# -----------------------------------------------------------------------------
output "dev_private_subnet_arns" {
  description = "Dev environment private subnet ARNs"
  value = [
    for id in slice(module.vpc.private_subnets, 0, 2) :
    "arn:aws:ec2:${var.region}:${var.shared_account_id}:subnet/${id}"
  ]
}

output "dev_database_subnet_arns" {
  description = "Dev environment database subnet ARNs"
  value = [
    for id in slice(module.vpc.database_subnets, 0, 2) :
    "arn:aws:ec2:${var.region}:${var.shared_account_id}:subnet/${id}"
  ]
}

output "prod_private_subnet_arns" {
  description = "Prod environment private subnet ARNs"
  value = [
    for id in slice(module.vpc.private_subnets, 2, 4) :
    "arn:aws:ec2:${var.region}:${var.shared_account_id}:subnet/${id}"
  ]
}

output "prod_database_subnet_arns" {
  description = "Prod environment database subnet ARNs"
  value = [
    for id in slice(module.vpc.database_subnets, 2, 4) :
    "arn:aws:ec2:${var.region}:${var.shared_account_id}:subnet/${id}"
  ]
}

# -----------------------------------------------------------------------------
# Database Subnet Group
# -----------------------------------------------------------------------------
output "database_subnet_group_name" {
  description = "Name of the database subnet group"
  value       = module.vpc.database_subnet_group_name
}

output "database_subnet_group_id" {
  description = "ID of the database subnet group"
  value       = module.vpc.database_subnet_group
}

# -----------------------------------------------------------------------------
# NAT Gateway
# -----------------------------------------------------------------------------
output "nat_public_ips" {
  description = "List of public Elastic IPs created for NAT Gateway"
  value       = module.vpc.nat_public_ips
}

output "natgw_ids" {
  description = "List of NAT Gateway IDs"
  value       = module.vpc.natgw_ids
}

# -----------------------------------------------------------------------------
# Internet Gateway
# -----------------------------------------------------------------------------
output "igw_id" {
  description = "Internet Gateway ID"
  value       = module.vpc.igw_id
}

output "igw_arn" {
  description = "Internet Gateway ARN"
  value       = module.vpc.igw_arn
}

# -----------------------------------------------------------------------------
# Route Tables
# -----------------------------------------------------------------------------
output "public_route_table_ids" {
  description = "List of public route table IDs"
  value       = module.vpc.public_route_table_ids
}

output "private_route_table_ids" {
  description = "List of private route table IDs"
  value       = module.vpc.private_route_table_ids
}

output "database_route_table_ids" {
  description = "List of database route table IDs"
  value       = module.vpc.database_route_table_ids
}

# -----------------------------------------------------------------------------
# Availability Zones
# -----------------------------------------------------------------------------
output "azs" {
  description = "Availability zones used"
  value       = module.vpc.azs
}

# -----------------------------------------------------------------------------
# RAM Resource Share
# -----------------------------------------------------------------------------
output "ram_resource_share_arn" {
  description = "ARN of the RAM resource share"
  value       = aws_ram_resource_share.network.arn
}

output "ram_resource_share_id" {
  description = "ID of the RAM resource share"
  value       = aws_ram_resource_share.network.id
}
