# Dev Environment - VPC Configuration

module "vpc" {
  source = "../../modules/vpc"

  environment         = "dev"
  vpc_cidr            = "10.0.0.0/16"
  availability_zone_a = "eu-west-1a"
  availability_zone_b = "eu-west-1b"

  # Subnet CIDRs will be auto-calculated:
  # Public: 10.0.1.0/24, 10.0.2.0/24
  # Private: 10.0.10.0/24, 10.0.11.0/24
  # Database: 10.0.20.0/24, 10.0.21.0/24

  # Enable VPC Flow Logs for security
  # Note: Module uses single NAT gateway by default for cost optimization
  enable_flow_logs = true

  # Database subnets disabled for now (no RDS/ElastiCache planned)
  # Set to true when needed
  enable_database_subnets = false

  tags = {
    Environment = "dev"
    ManagedBy   = "Terraform"
    Project     = "AltaNova"
  }
}
