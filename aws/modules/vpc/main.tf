# =============================================================================
# Shared VPC Module - Network Hub with AWS RAM Subnet Sharing
# =============================================================================
#
# This module creates a single VPC in the Shared Account that serves as the
# network hub for all environments (Dev, Prod). Subnets are shared to
# Dev/Prod accounts via AWS Resource Access Manager (RAM).
#
# Architecture:
#   - Single VPC: 10.0.0.0/16 (65,536 IPs)
#   - Single NAT Gateway (cost-optimized)
#   - 2 AZs: eu-west-1a, eu-west-1b
#   - Environment-specific subnets shared via RAM
#
# CIDR Allocation:
#   DEV:  Public (10.0.0-1.0/24), Private (10.0.16-32.0/20), DB (10.0.128-129.0/24)
#   PROD: Public (10.0.4-5.0/24), Private (10.0.48-64.0/20), DB (10.0.132-133.0/24)
#   Reserved: 10.0.192.0/18 (future use)
# =============================================================================

locals {
  project_name = var.project_name
  region_code  = "euw1"

  # Availability Zones
  azs = ["${var.region}a", "${var.region}b"]

  # Common tags for all resources
  common_tags = merge(var.tags, {
    Module    = "vpc"
    ManagedBy = "Terraform"
    Project   = var.project_name
  })

  # CIDR allocations per environment (as specified in the plan)
  # Dev environment subnets
  dev_public_subnets   = ["10.0.0.0/24", "10.0.1.0/24"]
  dev_private_subnets  = ["10.0.16.0/20", "10.0.32.0/20"]
  dev_database_subnets = ["10.0.128.0/24", "10.0.129.0/24"]

  # Prod environment subnets
  prod_public_subnets   = ["10.0.4.0/24", "10.0.5.0/24"]
  prod_private_subnets  = ["10.0.48.0/20", "10.0.64.0/20"]
  prod_database_subnets = ["10.0.132.0/24", "10.0.133.0/24"]

  # Combined subnets for VPC module
  all_public_subnets   = concat(local.dev_public_subnets, local.prod_public_subnets)
  all_private_subnets  = concat(local.dev_private_subnets, local.prod_private_subnets)
  all_database_subnets = concat(local.dev_database_subnets, local.prod_database_subnets)
}

# =============================================================================
# VPC - Using terraform-aws-modules/vpc/aws
# =============================================================================
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.project_name}-shared-${local.region_code}-vpc"
  cidr = var.vpc_cidr

  azs = local.azs

  # All subnets (Dev + Prod) in order: dev-a, dev-b, prod-a, prod-b
  public_subnets   = local.all_public_subnets
  private_subnets  = local.all_private_subnets
  database_subnets = local.all_database_subnets

  # NAT Gateway - Single for cost optimization
  enable_nat_gateway     = true
  single_nat_gateway     = var.single_nat_gateway
  one_nat_gateway_per_az = !var.single_nat_gateway

  # DNS
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Database subnet group
  create_database_subnet_group       = true
  create_database_subnet_route_table = true

  # VPC Flow Logs
  enable_flow_log                      = true
  flow_log_destination_type            = "cloud-watch-logs"
  create_flow_log_cloudwatch_iam_role  = true
  create_flow_log_cloudwatch_log_group = true
  flow_log_max_aggregation_interval    = 60

  # Resource naming
  igw_tags = {
    Name = "${local.project_name}-shared-${local.region_code}-igw"
  }

  nat_gateway_tags = {
    Name = "${local.project_name}-shared-${local.region_code}-nat"
  }

  nat_eip_tags = {
    Name = "${local.project_name}-shared-${local.region_code}-nat-eip"
  }

  public_route_table_tags = {
    Name = "${local.project_name}-shared-${local.region_code}-rtb-public"
  }

  private_route_table_tags = {
    Name = "${local.project_name}-shared-${local.region_code}-rtb-private"
  }

  database_route_table_tags = {
    Name = "${local.project_name}-shared-${local.region_code}-rtb-database"
  }

  # Subnet naming (order: dev-a, dev-b, prod-a, prod-b)
  public_subnet_names = [
    "${local.project_name}-dev-${local.region_code}-public-a",
    "${local.project_name}-dev-${local.region_code}-public-b",
    "${local.project_name}-prod-${local.region_code}-public-a",
    "${local.project_name}-prod-${local.region_code}-public-b"
  ]

  private_subnet_names = [
    "${local.project_name}-dev-${local.region_code}-private-a",
    "${local.project_name}-dev-${local.region_code}-private-b",
    "${local.project_name}-prod-${local.region_code}-private-a",
    "${local.project_name}-prod-${local.region_code}-private-b"
  ]

  database_subnet_names = [
    "${local.project_name}-dev-${local.region_code}-database-a",
    "${local.project_name}-dev-${local.region_code}-database-b",
    "${local.project_name}-prod-${local.region_code}-database-a",
    "${local.project_name}-prod-${local.region_code}-database-b"
  ]

  # Tags for all subnets
  public_subnet_tags = {
    Tier = "Public"
  }

  private_subnet_tags = {
    Tier = "Private"
  }

  database_subnet_tags = {
    Tier = "Database"
  }

  tags = local.common_tags
}

# =============================================================================
# Environment-Specific Subnet Tags
# =============================================================================
# Add environment tags to subnets for identification and EKS discovery

# Dev Public Subnets (indices 0, 1)
resource "aws_ec2_tag" "dev_public_env" {
  count       = 2
  resource_id = module.vpc.public_subnets[count.index]
  key         = "Environment"
  value       = "dev"
}

resource "aws_ec2_tag" "dev_public_eks" {
  count       = 2
  resource_id = module.vpc.public_subnets[count.index]
  key         = "kubernetes.io/role/elb"
  value       = "1"
}

resource "aws_ec2_tag" "dev_public_eks_cluster" {
  count       = 2
  resource_id = module.vpc.public_subnets[count.index]
  key         = "kubernetes.io/cluster/${local.project_name}-dev-${local.region_code}-eks"
  value       = "shared"
}

# Dev Private Subnets (indices 0, 1)
resource "aws_ec2_tag" "dev_private_env" {
  count       = 2
  resource_id = module.vpc.private_subnets[count.index]
  key         = "Environment"
  value       = "dev"
}

resource "aws_ec2_tag" "dev_private_eks" {
  count       = 2
  resource_id = module.vpc.private_subnets[count.index]
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
}

resource "aws_ec2_tag" "dev_private_eks_cluster" {
  count       = 2
  resource_id = module.vpc.private_subnets[count.index]
  key         = "kubernetes.io/cluster/${local.project_name}-dev-${local.region_code}-eks"
  value       = "shared"
}

resource "aws_ec2_tag" "dev_private_karpenter" {
  count       = 2
  resource_id = module.vpc.private_subnets[count.index]
  key         = "karpenter.sh/discovery"
  value       = "${local.project_name}-dev-${local.region_code}-eks"
}

# Dev Database Subnets (indices 0, 1)
resource "aws_ec2_tag" "dev_database_env" {
  count       = 2
  resource_id = module.vpc.database_subnets[count.index]
  key         = "Environment"
  value       = "dev"
}

# Prod Public Subnets (indices 2, 3)
resource "aws_ec2_tag" "prod_public_env" {
  count       = 2
  resource_id = module.vpc.public_subnets[count.index + 2]
  key         = "Environment"
  value       = "prod"
}

resource "aws_ec2_tag" "prod_public_eks" {
  count       = 2
  resource_id = module.vpc.public_subnets[count.index + 2]
  key         = "kubernetes.io/role/elb"
  value       = "1"
}

resource "aws_ec2_tag" "prod_public_eks_cluster" {
  count       = 2
  resource_id = module.vpc.public_subnets[count.index + 2]
  key         = "kubernetes.io/cluster/${local.project_name}-prod-${local.region_code}-eks"
  value       = "shared"
}

# Prod Private Subnets (indices 2, 3)
resource "aws_ec2_tag" "prod_private_env" {
  count       = 2
  resource_id = module.vpc.private_subnets[count.index + 2]
  key         = "Environment"
  value       = "prod"
}

resource "aws_ec2_tag" "prod_private_eks" {
  count       = 2
  resource_id = module.vpc.private_subnets[count.index + 2]
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
}

resource "aws_ec2_tag" "prod_private_eks_cluster" {
  count       = 2
  resource_id = module.vpc.private_subnets[count.index + 2]
  key         = "kubernetes.io/cluster/${local.project_name}-prod-${local.region_code}-eks"
  value       = "shared"
}

resource "aws_ec2_tag" "prod_private_karpenter" {
  count       = 2
  resource_id = module.vpc.private_subnets[count.index + 2]
  key         = "karpenter.sh/discovery"
  value       = "${local.project_name}-prod-${local.region_code}-eks"
}

# Prod Database Subnets (indices 2, 3)
resource "aws_ec2_tag" "prod_database_env" {
  count       = 2
  resource_id = module.vpc.database_subnets[count.index + 2]
  key         = "Environment"
  value       = "prod"
}
