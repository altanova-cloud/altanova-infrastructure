# Dev Environment - VPC Configuration

module "vpc" {
  source = "../../modules/vpc"

  environment        = "dev"
  cluster_name       = "altanova"
  vpc_cidr           = "10.0.0.0/16"
  availability_zone_a = "eu-west-1a"
  availability_zone_b = "eu-west-1b"

  # Subnet CIDRs (matching your existing design)
  public_subnet_cidr_zone_a  = "172.16.0.0/24"
  public_subnet_cidr_zone_b  = "172.16.1.0/24"
  private_subnet_cidr_zone_a = "172.16.2.0/24"
  private_subnet_cidr_zone_b = "172.16.3.0/24"

  # Cost optimization for dev - single NAT gateway
  enable_nat_gateway_zone_b = false

  # Enable VPC Flow Logs for security
  enable_flow_logs          = true
  flow_logs_retention_days  = 7  # Shorter retention for dev

  tags = {
    Environment = "dev"
    ManagedBy   = "Terraform"
    Project     = "AltaNova"
  }
}
