# VPC Module Outputs

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

# Public Subnets
output "public_subnet_ids" {
  description = "IDs of all public subnets"
  value       = local.enable_zone_c ? [
    aws_subnet.public_zone_a.id,
    aws_subnet.public_zone_b.id,
    aws_subnet.public_zone_c[0].id
  ] : [
    aws_subnet.public_zone_a.id,
    aws_subnet.public_zone_b.id
  ]
}

# Private Subnets
output "private_subnet_ids" {
  description = "IDs of all private subnets (for EKS)"
  value       = local.enable_zone_c ? [
    aws_subnet.private_zone_a.id,
    aws_subnet.private_zone_b.id,
    aws_subnet.private_zone_c[0].id
  ] : [
    aws_subnet.private_zone_a.id,
    aws_subnet.private_zone_b.id
  ]
}

# Database Subnets
output "database_subnet_ids" {
  description = "IDs of all database subnets (for RDS, ElastiCache)"
  value       = local.enable_zone_c ? [
    aws_subnet.database_zone_a.id,
    aws_subnet.database_zone_b.id,
    aws_subnet.database_zone_c[0].id
  ] : [
    aws_subnet.database_zone_a.id,
    aws_subnet.database_zone_b.id
  ]
}

output "db_subnet_group_name" {
  description = "Name of the DB subnet group"
  value       = aws_db_subnet_group.main.name
}

# Individual Subnet IDs
output "public_subnet_zone_a_id" {
  description = "ID of public subnet in zone A"
  value       = aws_subnet.public_zone_a.id
}

output "public_subnet_zone_b_id" {
  description = "ID of public subnet in zone B"
  value       = aws_subnet.public_zone_b.id
}

output "public_subnet_zone_c_id" {
  description = "ID of public subnet in zone C (if enabled)"
  value       = local.enable_zone_c ? aws_subnet.public_zone_c[0].id : null
}

output "private_subnet_zone_a_id" {
  description = "ID of private subnet in zone A"
  value       = aws_subnet.private_zone_a.id
}

output "private_subnet_zone_b_id" {
  description = "ID of private subnet in zone B"
  value       = aws_subnet.private_zone_b.id
}

output "private_subnet_zone_c_id" {
  description = "ID of private subnet in zone C (if enabled)"
  value       = local.enable_zone_c ? aws_subnet.private_zone_c[0].id : null
}

# NAT Gateways
output "nat_gateway_zone_a_id" {
  description = "ID of NAT gateway in zone A"
  value       = aws_nat_gateway.zone_a.id
}

output "nat_gateway_zone_b_id" {
  description = "ID of NAT gateway in zone B (if enabled)"
  value       = var.enable_nat_gateway_zone_b ? aws_nat_gateway.zone_b[0].id : null
}

# Internet Gateway
output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

# Availability Zones
output "availability_zones" {
  description = "List of availability zones used"
  value       = local.enable_zone_c ? [
    var.availability_zone_a,
    var.availability_zone_b,
    var.availability_zone_c
  ] : [
    var.availability_zone_a,
    var.availability_zone_b
  ]
}
