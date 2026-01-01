# Dev Environment - Outputs

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
  description = "ID of the default security group"
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

# -----------------------------------------------------------------------------
# RDS PostgreSQL
# -----------------------------------------------------------------------------
output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = module.rds.db_instance_endpoint
}

output "rds_address" {
  description = "RDS PostgreSQL address (hostname)"
  value       = module.rds.db_instance_address
}

output "rds_port" {
  description = "RDS PostgreSQL port"
  value       = module.rds.db_instance_port
}

output "rds_database_name" {
  description = "RDS PostgreSQL database name"
  value       = module.rds.db_instance_name
}

output "rds_security_group_id" {
  description = "Security group ID for RDS"
  value       = aws_security_group.rds.id
}

output "rds_secret_arn" {
  description = "ARN of Secrets Manager secret containing DB credentials"
  value       = aws_secretsmanager_secret.db_password.arn
  sensitive   = true
}

# -----------------------------------------------------------------------------
# EKS Cluster
# -----------------------------------------------------------------------------
output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_version" {
  description = "EKS cluster Kubernetes version"
  value       = module.eks.cluster_version
}

output "eks_cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks.cluster_arn
}

output "eks_cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data for cluster authentication"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "eks_oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA"
  value       = module.eks.oidc_provider_arn
}

output "eks_cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "eks_node_security_group_id" {
  description = "Security group ID attached to EKS nodes"
  value       = module.eks.node_security_group_id
}

# -----------------------------------------------------------------------------
# Karpenter
# -----------------------------------------------------------------------------
output "karpenter_iam_role_arn" {
  description = "Karpenter controller IAM role ARN"
  value       = module.karpenter.iam_role_arn
}

output "karpenter_node_iam_role_arn" {
  description = "Karpenter node IAM role ARN"
  value       = module.karpenter.node_iam_role_arn
}

output "karpenter_node_iam_role_name" {
  description = "Karpenter node IAM role name"
  value       = module.karpenter.node_iam_role_name
}

output "karpenter_queue_name" {
  description = "Karpenter SQS queue name for spot interruption handling"
  value       = module.karpenter.queue_name
}

# -----------------------------------------------------------------------------
# Kubeconfig Command
# -----------------------------------------------------------------------------
output "kubeconfig_command" {
  description = "Command to update kubeconfig for kubectl access"
  value       = "aws eks update-kubeconfig --region eu-west-1 --name ${module.eks.cluster_name}"
}

# -----------------------------------------------------------------------------
# ACM Certificate
# -----------------------------------------------------------------------------
output "acm_certificate_arn" {
  description = "ARN of the wildcard ACM certificate"
  value       = aws_acm_certificate.wildcard.arn
}

output "acm_certificate_domain" {
  description = "Domain name covered by the certificate"
  value       = aws_acm_certificate.wildcard.domain_name
}
