# =============================================================================
# VPC - Workspace-based Shared Network Hub
# =============================================================================
#
# Uses Terraform workspaces for environment + region separation.
#
# Workspace naming: shared-{region_code}
#   - shared-euw1  (Shared in eu-west-1)
#   - shared-eus2  (Shared in eu-south-2 Spain)
#   - shared-use1  (Shared in us-east-1)
#
# Usage:
#   terraform workspace new shared-euw1
#   terraform workspace select shared-euw1
#   terraform plan
# =============================================================================

terraform {
  required_version = ">= 1.8"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "http" {}
}

# =============================================================================
# Workspace Configuration
# =============================================================================
locals {
  # Parse workspace: "shared-euw1" -> env="shared", region_code="euw1"
  workspace_parts = split("-", terraform.workspace)
  environment     = local.workspace_parts[0]
  region_code     = local.workspace_parts[1]

  # Region mapping
  region_map = {
    euw1 = "eu-west-1"
    euw2 = "eu-west-2"
    eus2 = "eu-south-2" # Spain
    use1 = "us-east-1"
    use2 = "us-east-2"
  }
  region = local.region_map[local.region_code]

  # Account IDs
  shared_account_id = "265245191272"
  dev_account_id    = "975050047325"
  prod_account_id   = "624755517249"

  # VPC Configuration
  project_name       = "altanova"
  vpc_cidr           = "10.0.0.0/16"
  single_nat_gateway = true
}

# =============================================================================
# Provider
# =============================================================================
provider "aws" {
  region = local.region

  default_tags {
    tags = {
      Environment = local.environment
      Region      = local.region
      ManagedBy   = "Terraform"
      Project     = "AltaNova"
      Workspace   = terraform.workspace
    }
  }
}

# =============================================================================
# VPC Module
# =============================================================================
module "vpc" {
  source = "../../modules/vpc"

  project_name       = local.project_name
  region             = local.region
  vpc_cidr           = local.vpc_cidr
  single_nat_gateway = local.single_nat_gateway

  shared_account_id = local.shared_account_id
  dev_account_id    = local.dev_account_id
  prod_account_id   = local.prod_account_id

  tags = {
    Environment = local.environment
    Workspace   = terraform.workspace
  }
}

# =============================================================================
# Outputs
# =============================================================================
output "workspace" {
  description = "Current workspace"
  value       = terraform.workspace
}

output "environment" {
  description = "Environment"
  value       = local.environment
}

output "region" {
  description = "AWS Region"
  value       = local.region
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "VPC CIDR block"
  value       = module.vpc.vpc_cidr_block
}

output "dev_public_subnet_ids" {
  description = "Dev public subnet IDs"
  value       = module.vpc.dev_public_subnet_ids
}

output "dev_private_subnet_ids" {
  description = "Dev private subnet IDs"
  value       = module.vpc.dev_private_subnet_ids
}

output "dev_database_subnet_ids" {
  description = "Dev database subnet IDs"
  value       = module.vpc.dev_database_subnet_ids
}

output "prod_public_subnet_ids" {
  description = "Prod public subnet IDs"
  value       = module.vpc.prod_public_subnet_ids
}

output "prod_private_subnet_ids" {
  description = "Prod private subnet IDs"
  value       = module.vpc.prod_private_subnet_ids
}

output "prod_database_subnet_ids" {
  description = "Prod database subnet IDs"
  value       = module.vpc.prod_database_subnet_ids
}

output "database_subnet_group_name" {
  description = "Database subnet group name"
  value       = module.vpc.database_subnet_group_name
}

output "nat_public_ips" {
  description = "NAT Gateway public IPs"
  value       = module.vpc.nat_public_ips
}

output "ram_resource_share_arn" {
  description = "RAM resource share ARN"
  value       = module.vpc.ram_resource_share_arn
}
