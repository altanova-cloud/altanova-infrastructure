# VPC Module Outputs

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = [aws_subnet.public_zone_a.id, aws_subnet.public_zone_b.id]
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = [aws_subnet.private_zone_a.id, aws_subnet.private_zone_b.id]
}

output "public_subnet_zone_a_id" {
  description = "ID of public subnet in zone A"
  value       = aws_subnet.public_zone_a.id
}

output "public_subnet_zone_b_id" {
  description = "ID of public subnet in zone B"
  value       = aws_subnet.public_zone_b.id
}

output "private_subnet_zone_a_id" {
  description = "ID of private subnet in zone A"
  value       = aws_subnet.private_zone_a.id
}

output "private_subnet_zone_b_id" {
  description = "ID of private subnet in zone B"
  value       = aws_subnet.private_zone_b.id
}

output "nat_gateway_zone_a_id" {
  description = "ID of NAT gateway in zone A"
  value       = aws_nat_gateway.zone_a.id
}

output "nat_gateway_zone_b_id" {
  description = "ID of NAT gateway in zone B (if enabled)"
  value       = var.enable_nat_gateway_zone_b ? aws_nat_gateway.zone_b[0].id : null
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "availability_zones" {
  description = "List of availability zones used"
  value       = [var.availability_zone_a, var.availability_zone_b]
}
