output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr
}

output "public_subnet_ids" {
  description = "IDs of all public subnets"
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "IDs of all private subnets (for EKS)"
  value       = module.vpc.private_subnets
}

output "database_subnet_ids" {
  description = "IDs of all database subnets (for RDS, ElastiCache)"
  value       = var.enable_database_subnets ? module.vpc.database_subnets : []
}

output "db_subnet_group_name" {
  description = "Name of the DB subnet group"
  value       = var.enable_database_subnets ? module.vpc.database_subnet_group_name : null
}

output "public_subnet_zone_a_id" {
  description = "ID of public subnet in zone A"
  value       = module.vpc.public_subnets[0]
}

output "public_subnet_zone_b_id" {
  description = "ID of public subnet in zone B"
  value       = module.vpc.public_subnets[1]
}

output "public_subnet_zone_c_id" {
  description = "ID of public subnet in zone C (if enabled)"
  value       = var.availability_zone_c != null ? module.vpc.public_subnets[2] : null
}

output "private_subnet_zone_a_id" {
  description = "ID of private subnet in zone A"
  value       = module.vpc.private_subnets[0]
}

output "private_subnet_zone_b_id" {
  description = "ID of private subnet in zone B"
  value       = module.vpc.private_subnets[1]
}

output "private_subnet_zone_c_id" {
  description = "ID of private subnet in zone C (if enabled)"
  value       = var.availability_zone_c != null ? module.vpc.private_subnets[2] : null
}

output "nat_gateway_zone_a_id" {
  description = "ID of NAT gateway in zone A"
  value       = module.vpc.nat_gateway_ids[0]
}

output "nat_gateway_zone_b_id" {
  description = "ID of NAT gateway in zone B (if enabled)"
  value       = var.enable_nat_gateway_zone_b ? module.vpc.nat_gateway_ids[1] : null
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = module.vpc.igw_id
}

output "availability_zones" {
  description = "List of availability zones used"
  value       = var.availability_zone_c != null ? [
    var.availability_zone_a,
    var.availability_zone_b,
    var.availability_zone_c
  ] : [
    var.availability_zone_a,
    var.availability_zone_b
  ]
}
