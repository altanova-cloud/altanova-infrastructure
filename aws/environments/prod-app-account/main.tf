# Prod Environment - Main Infrastructure
# VPC with subnets, NAT gateway, and routing

locals {
  environment  = "prod"
  project_name = "altanova"
  region_code  = "euw1"

  common_tags = {
    Environment = local.environment
    Project     = "AltaNova"
    ManagedBy   = "Terraform"
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.project_name}-${local.environment}-${local.region_code}-vpc"
  cidr = "10.1.0.0/16"

  azs              = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  public_subnets   = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
  private_subnets  = ["10.1.10.0/24", "10.1.11.0/24", "10.1.12.0/24"]
  database_subnets = ["10.1.20.0/24", "10.1.21.0/24", "10.1.22.0/24"]

  # NAT Gateway - single for now, set one_nat_gateway_per_az=true for HA
  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  # DNS
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Database subnet group
  create_database_subnet_group = true

  # VPC Flow Logs
  enable_flow_log                      = true
  flow_log_destination_type            = "cloud-watch-logs"
  create_flow_log_cloudwatch_iam_role  = true
  create_flow_log_cloudwatch_log_group = true

  # Subnet names
  public_subnet_names   = ["${local.project_name}-${local.environment}-${local.region_code}-public-a", "${local.project_name}-${local.environment}-${local.region_code}-public-b", "${local.project_name}-${local.environment}-${local.region_code}-public-c"]
  private_subnet_names  = ["${local.project_name}-${local.environment}-${local.region_code}-private-a", "${local.project_name}-${local.environment}-${local.region_code}-private-b", "${local.project_name}-${local.environment}-${local.region_code}-private-c"]
  database_subnet_names = ["${local.project_name}-${local.environment}-${local.region_code}-database-a", "${local.project_name}-${local.environment}-${local.region_code}-database-b", "${local.project_name}-${local.environment}-${local.region_code}-database-c"]

  # Resource naming
  igw_tags = {
    Name = "${local.project_name}-${local.environment}-${local.region_code}-igw"
  }

  nat_gateway_tags = {
    Name = "${local.project_name}-${local.environment}-${local.region_code}-nat"
  }

  nat_eip_tags = {
    Name = "${local.project_name}-${local.environment}-${local.region_code}-nat-eip"
  }

  public_route_table_tags = {
    Name = "${local.project_name}-${local.environment}-${local.region_code}-rtb-public"
  }

  private_route_table_tags = {
    Name = "${local.project_name}-${local.environment}-${local.region_code}-rtb-private"
  }

  database_route_table_tags = {
    Name = "${local.project_name}-${local.environment}-${local.region_code}-rtb-database"
  }

  # Subnet tags for EKS discovery
  public_subnet_tags = {
    Tier                                                                                          = "Public"
    "kubernetes.io/role/elb"                                                                      = "1"
    "kubernetes.io/cluster/${local.project_name}-${local.environment}-${local.region_code}-eks" = "shared"
  }

  private_subnet_tags = {
    Tier                                                                                          = "Private"
    "kubernetes.io/role/internal-elb"                                                             = "1"
    "kubernetes.io/cluster/${local.project_name}-${local.environment}-${local.region_code}-eks" = "shared"
  }

  database_subnet_tags = {
    Tier = "Database"
  }

  tags = local.common_tags
}
