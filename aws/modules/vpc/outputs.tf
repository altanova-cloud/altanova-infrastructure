output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnets
}

output "private_subnet_ids" {
  value = module.vpc.private_subnets
}

output "database_subnet_ids" {
  value = var.enable_database_subnets ? module.vpc.database_subnets : []
}

output "nat_gateway_ids" {
  value = module.vpc.natgw_ids
}

output "availability_zones" {
  value = local.azs
}
