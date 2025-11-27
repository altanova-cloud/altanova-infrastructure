# Production Environment - VPC Configuration

module "vpc" {
  source = "../../modules/vpc"

  environment         = "prod"
  cluster_name        = "altanova"
  vpc_cidr            = "10.1.0.0/16" # Prod uses 10.1.x.x
  availability_zone_a = "eu-west-1a"
  availability_zone_b = "eu-west-1b"
  availability_zone_c = "eu-west-1c" # 3 AZs for production HA

  # Subnet CIDRs will be auto-calculated:
  # Public: 10.1.1.0/24, 10.1.2.0/24, 10.1.3.0/24
  # Private: 10.1.10.0/24, 10.1.11.0/24, 10.1.12.0/24
  # Database: 10.1.20.0/24, 10.1.21.0/24, 10.1.22.0/24

  # Cost optimization - single NAT gateway (can enable more if needed)
  enable_nat_gateway_zone_b = false

  # Enable database subnets and subnet group for RDS/ElastiCache
  enable_database_subnets = true

  # Enable VPC Flow Logs for security and compliance
  enable_flow_logs         = true
  flow_logs_retention_days = 30 # Longer retention for prod

  tags = {
    Environment = "prod"
    ManagedBy   = "Terraform"
    Project     = "AltaNova"
  }
}
