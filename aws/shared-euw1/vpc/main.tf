# =============================================================================
# VPC - Shared Account (eu-west-1)
# =============================================================================
# State: shared-euw1-vpc
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

locals {
  environment = "shared"
  region      = "eu-west-1"
  region_code = "euw1"

  # Account IDs
  shared_account_id = "265245191272"
  dev_account_id    = "975050047325"
  prod_account_id   = "624755517249"

  # VPC Configuration
  project_name       = "altanova"
  vpc_cidr           = "10.0.0.0/16"
  single_nat_gateway = true
}

provider "aws" {
  region = local.region

  default_tags {
    tags = {
      Environment = local.environment
      Region      = local.region
      ManagedBy   = "Terraform"
      Project     = "AltaNova"
    }
  }
}

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
  }
}

# =============================================================================
# Outputs
# =============================================================================
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

output "prod_public_subnet_ids" {
  description = "Prod public subnet IDs"
  value       = module.vpc.prod_public_subnet_ids
}

output "prod_private_subnet_ids" {
  description = "Prod private subnet IDs"
  value       = module.vpc.prod_private_subnet_ids
}

output "nat_public_ips" {
  description = "NAT Gateway public IPs"
  value       = module.vpc.nat_public_ips
}

output "ram_resource_share_arn" {
  description = "RAM resource share ARN"
  value       = module.vpc.ram_resource_share_arn
}
