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

  # DB subnet numbering (2 or 3 depending on AZ count)
  db_cidr_numbers = var.availability_zone_c != null ? [20, 21, 22] : [20, 21]
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
  public_subnets  = cidrsubnets(var.vpc_cidr, 8, 1, 2, 3)
  private_subnets = cidrsubnets(var.vpc_cidr, 8, 10, 11, 12)

  database_subnets = (
    var.enable_database_subnets ?
      cidrsubnets(var.vpc_cidr, 8, local.db_cidr_numbers...) :
      []
  )

  # NAT
  enable_nat_gateway     = true
  one_nat_gateway_per_az = false
  single_nat_gateway     = true

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
