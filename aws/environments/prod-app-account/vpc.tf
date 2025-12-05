# Production Environment - VPC Configuration

module "vpc" {
  source = "../../modules/vpc"

  environment         = "prod"
  vpc_cidr            = "10.1.0.0/16" # Prod uses 10.1.x.x
  availability_zone_a = "eu-west-1a"
  availability_zone_b = "eu-west-1b"
  availability_zone_c = "eu-west-1c" # 3 AZs for production HA

  # Subnet CIDRs will be auto-calculated:
  # Public: 10.1.1.0/24, 10.1.2.0/24, 10.1.3.0/24
  # Private: 10.1.10.0/24, 10.1.11.0/24, 10.1.12.0/24
  # Database: 10.1.20.0/24, 10.1.21.0/24, 10.1.22.0/24

  # Enable VPC Flow Logs for security and compliance
  enable_flow_logs = true

  # Database subnets disabled for now (no RDS/ElastiCache planned)
  # Set to true when needed
  enable_database_subnets = false

  # Single NAT for cost savings (no app deployed yet)
  # Set to false for HA when production workloads are running
  single_nat_gateway = true

  tags = {
    Environment = "prod"
    ManagedBy   = "Terraform"
    Project     = "AltaNova"
  }
}
