# Prod Environment - Outputs

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

# -----------------------------------------------------------------------------
# Subnets
# -----------------------------------------------------------------------------
output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnets
}

output "database_subnet_ids" {
  description = "List of database subnet IDs"
  value       = module.vpc.database_subnets
}

output "database_subnet_group_name" {
  description = "Name of the database subnet group"
  value       = module.vpc.database_subnet_group_name
}

# -----------------------------------------------------------------------------
# Gateways
# -----------------------------------------------------------------------------
output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = module.vpc.igw_id
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = module.vpc.natgw_ids
}

output "nat_public_ips" {
  description = "List of NAT Gateway public IPs"
  value       = module.vpc.nat_public_ips
}

# -----------------------------------------------------------------------------
# Availability Zones
# -----------------------------------------------------------------------------
output "availability_zones" {
  description = "List of availability zones"
  value       = module.vpc.azs
}

# -----------------------------------------------------------------------------
# Security Groups
# -----------------------------------------------------------------------------
output "default_security_group_id" {
  description = "ID of the default security group (locked down)"
  value       = module.vpc.default_security_group_id
}

# -----------------------------------------------------------------------------
# IAM
# -----------------------------------------------------------------------------
output "deploy_role_arn" {
  description = "ARN of the deployment role"
  value       = module.deployment_role.role_arn
}

output "deploy_role_name" {
  description = "Name of the deployment role"
  value       = module.deployment_role.role_name
}
