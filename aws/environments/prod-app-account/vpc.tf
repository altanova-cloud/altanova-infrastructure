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

  # Enable database subnets and subnet group for RDS/ElastiCache
  # Database subnets are created by default when using this module

  # Enable VPC Flow Logs for security and compliance
  enable_flow_logs = true

  # High Availability: Use one NAT Gateway per AZ for production
  single_nat_gateway = false

  tags = {
    Environment = "prod"
    ManagedBy   = "Terraform"
    Project     = "AltaNova"
  }
}
