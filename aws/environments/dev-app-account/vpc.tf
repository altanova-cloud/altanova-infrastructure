# Dev Environment - VPC Configuration

module "vpc" {
  source = "../../modules/vpc"

  environment         = "dev"
  cluster_name        = "altanova"
  vpc_cidr            = "10.0.0.0/16"
  availability_zone_a = "eu-west-1a"
  availability_zone_b = "eu-west-1b"

  # Subnet CIDRs will be auto-calculated:
  # Public: 10.0.1.0/24, 10.0.2.0/24
  # Private: 10.0.10.0/24, 10.0.11.0/24
  # Database: 10.0.20.0/24, 10.0.21.0/24

  # Cost optimization - single NAT gateway
  enable_nat_gateway_zone_b = false

  # Enable VPC Flow Logs for security
  enable_flow_logs         = true
  flow_logs_retention_days = 7 # Shorter retention for dev

  tags = {
    Environment = "dev"
    ManagedBy   = "Terraform"
    Project     = "AltaNova"
  }
}
