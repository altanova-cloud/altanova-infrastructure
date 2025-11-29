# VPC Module - Configures network infrastructure for EKS clusters
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  # Automatic list of AZs (compact removes nulls)
  azs = compact([
    var.availability_zone_a,
    var.availability_zone_b,
    var.availability_zone_c
  ])
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.environment}-${var.cluster_name}"
  cidr = var.vpc_cidr

  azs = local.azs

  # -----------------------------
  # Subnets (simple, predictable)
  # -----------------------------
  # For a /16 VPC, adding 8 bits gives /24 subnets
  # Using netnum to control the third octet: 10.x.netnum.0/24
  public_subnets = [
    for i in range(length(local.azs)) : cidrsubnet(var.vpc_cidr, 8, i + 1)
  ]
  
  private_subnets = [
    for i in range(length(local.azs)) : cidrsubnet(var.vpc_cidr, 8, i + 10)
  ]

  database_subnets = (
    var.enable_database_subnets ?
      [for i in range(length(local.azs)) : cidrsubnet(var.vpc_cidr, 8, i + 20)] :
      []
  )

  # NAT
  enable_nat_gateway     = true
  single_nat_gateway     = var.single_nat_gateway
  one_nat_gateway_per_az = !var.single_nat_gateway

  # VPC DNS
  enable_dns_hostnames = true

  enable_dns_support   = true

  # Flow logs
  enable_flow_log                       = var.enable_flow_logs
  flow_log_destination_type             = "cloud-watch-logs"
  create_flow_log_cloudwatch_iam_role   = true

  # Tags for Kubernetes + structure
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
    Tier = "Public"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    "karpenter.sh/discovery"          = var.cluster_name
    Tier                               = "Private"
  }

  tags = merge(
    var.tags,
    {
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
      Environment                                  = var.environment
      Provisioner                                  = "Terraform"
    }
  )
}
