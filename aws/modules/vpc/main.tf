# VPC Module Configuration
# This module provisions a VPC with public, private, and optional database subnets.
# It supports optional Zone C and integrates with EKS, RDS, and CloudWatch.

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
  # Extract second octet from VPC CIDR (e.g., "10.0.0.0/16" -> "0", "10.1.0.0/16" -> "1")
  vpc_second_octet = split(".", var.vpc_cidr)[1]

  # Auto-calculate subnet CIDRs if not provided
  # Public subnets: 10.x.1.0/24, 10.x.2.0/24, 10.x.3.0/24
  # Private subnets: 10.x.10.0/24, 10.x.11.0/24, 10.x.12.0/24
  # Database subnets: 10.x.20.0/24, 10.x.21.0/24, 10.x.22.0/24

  public_subnet_cidr_a = coalesce(var.public_subnet_cidr_zone_a, "10.${local.vpc_second_octet}.1.0/24")
  public_subnet_cidr_b = coalesce(var.public_subnet_cidr_zone_b, "10.${local.vpc_second_octet}.2.0/24")
  public_subnet_cidr_c = coalesce(var.public_subnet_cidr_zone_c, "10.${local.vpc_second_octet}.3.0/24")

  private_subnet_cidr_a = coalesce(var.private_subnet_cidr_zone_a, "10.${local.vpc_second_octet}.10.0/24")
  private_subnet_cidr_b = coalesce(var.private_subnet_cidr_zone_b, "10.${local.vpc_second_octet}.11.0/24")
  private_subnet_cidr_c = coalesce(var.private_subnet_cidr_zone_c, "10.${local.vpc_second_octet}.12.0/24")

  database_subnet_cidr_a = coalesce(var.database_subnet_cidr_zone_a, "10.${local.vpc_second_octet}.20.0/24")
  database_subnet_cidr_b = coalesce(var.database_subnet_cidr_zone_b, "10.${local.vpc_second_octet}.21.0/24")
  database_subnet_cidr_c = coalesce(var.database_subnet_cidr_zone_c, "10.${local.vpc_second_octet}.22.0/24")

  # Determine if zone C is enabled
  enable_zone_c = var.availability_zone_c != null

  common_tags = merge(
    var.tags,
    {
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
      "Provisioner"                               = "Created By Terraform"
      "Environment"                               = var.environment
    }
  )
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.environment}-${var.cluster_name}"
  cidr = var.vpc_cidr

  azs             = var.availability_zone_c != null ? [var.availability_zone_a, var.availability_zone_b, var.availability_zone_c] : [var.availability_zone_a, var.availability_zone_b]
  public_subnets  = var.availability_zone_c != null ? [
    coalesce(var.public_subnet_cidr_zone_a, cidrsubnet(var.vpc_cidr, 8, 1)),
    coalesce(var.public_subnet_cidr_zone_b, cidrsubnet(var.vpc_cidr, 8, 2)),
    coalesce(var.public_subnet_cidr_zone_c, cidrsubnet(var.vpc_cidr, 8, 3))
  ] : [
    coalesce(var.public_subnet_cidr_zone_a, cidrsubnet(var.vpc_cidr, 8, 1)),
    coalesce(var.public_subnet_cidr_zone_b, cidrsubnet(var.vpc_cidr, 8, 2))
  ]

  private_subnets = var.availability_zone_c != null ? [
    coalesce(var.private_subnet_cidr_zone_a, cidrsubnet(var.vpc_cidr, 8, 10)),
    coalesce(var.private_subnet_cidr_zone_b, cidrsubnet(var.vpc_cidr, 8, 11)),
    coalesce(var.private_subnet_cidr_zone_c, cidrsubnet(var.vpc_cidr, 8, 12))
  ] : [
    coalesce(var.private_subnet_cidr_zone_a, cidrsubnet(var.vpc_cidr, 8, 10)),
    coalesce(var.private_subnet_cidr_zone_b, cidrsubnet(var.vpc_cidr, 8, 11))
  ]

  database_subnets                   = var.enable_database_subnets ? (var.availability_zone_c != null ? [
    coalesce(var.database_subnet_cidr_zone_a, cidrsubnet(var.vpc_cidr, 8, 20)),
    coalesce(var.database_subnet_cidr_zone_b, cidrsubnet(var.vpc_cidr, 8, 21)),
    coalesce(var.database_subnet_cidr_zone_c, cidrsubnet(var.vpc_cidr, 8, 22))
  ] : [
    coalesce(var.database_subnet_cidr_zone_a, cidrsubnet(var.vpc_cidr, 8, 20)),
    coalesce(var.database_subnet_cidr_zone_b, cidrsubnet(var.vpc_cidr, 8, 21))
  ]) : null
  create_database_subnet_group       = var.enable_database_subnets
  create_database_subnet_route_table = var.enable_database_subnets

  enable_nat_gateway     = true
  single_nat_gateway     = var.enable_nat_gateway_zone_b == false
  one_nat_gateway_per_az = var.enable_nat_gateway_zone_b

  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = merge(
    var.tags,
    {
      "kubernetes.io/role/elb" = "1"
      Tier                      = "Public"
    }
  )

  private_subnet_tags = merge(
    var.tags,
    {
      "kubernetes.io/role/internal-elb" = "1"
      Tier                               = "Private"
      "karpenter.sh/discovery"          = var.cluster_name
    }
  )

  enable_flow_log                     = var.enable_flow_logs
  flow_log_destination_type           = "cloud-watch-logs"
  create_flow_log_cloudwatch_iam_role = true
  

  tags = merge(var.tags, {
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    Provisioner                                 = "Created By Terraform"
    Environment                                 = var.environment
  })
}

# VPC


# Internet Gateway


# Public Subnet - Zone A


# Public Subnet - Zone B


# Public Subnet - Zone C (optional)


# Private Subnet - Zone A (for EKS nodes and pods)


# Private Subnet - Zone B (for EKS nodes and pods)


# Private Subnet - Zone C (optional, for EKS nodes and pods)


# Database Subnet - Zone A (for RDS, ElastiCache)


# Database Subnet - Zone B (for RDS, ElastiCache)


# Database Subnet - Zone C (optional, for RDS, ElastiCache)


# Elastic IP for NAT Gateway Zone A


# NAT Gateway Zone A


# Elastic IP for NAT Gateway Zone B (optional for HA)


# NAT Gateway Zone B (optional for HA)


# Public Route Table


# Public Route to Internet Gateway


# Public Route Table Association - Zone A


# Public Route Table Association - Zone B


# Public Route Table Association - Zone C (optional)


# Private Route Table - Zone A


# Private Route to NAT Gateway - Zone A


# Private Route Table Association - Zone A


# Private Route Table - Zone B


# Private Route to NAT Gateway - Zone B


# Private Route Table Association - Zone B


# Private Route Table - Zone C (optional)


# Private Route to NAT Gateway - Zone C


# Private Route Table Association - Zone C


# Database Subnet Group (for RDS)


# VPC Flow Logs (optional)


# CloudWatch Log Group for Flow Logs


# IAM Role for Flow Logs


# IAM Policy for Flow Logs



# Public Subnet - Zone C (optional)


# Private Subnet - Zone A (for EKS nodes and pods)


# Private Subnet - Zone B (for EKS nodes and pods)


# Private Subnet - Zone C (optional, for EKS nodes and pods)


# Database Subnet - Zone A (for RDS, ElastiCache)


# Database Subnet - Zone B (for RDS, ElastiCache)


# Database Subnet - Zone C (optional, for RDS, ElastiCache)


# Elastic IP for NAT Gateway Zone A
resource "aws_eip" "nat_zone_a" {
  domain = "vpc"

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-nat-eip-${var.availability_zone_a}"
    }
  )

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateway Zone A
resource "aws_nat_gateway" "zone_a" {
  allocation_id = aws_eip.nat_zone_a.id
  subnet_id     = aws_subnet.public_zone_a.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-nat-${var.availability_zone_a}"
    }
  )

  depends_on = [aws_internet_gateway.main]
}

# Elastic IP for NAT Gateway Zone B (optional for HA)
resource "aws_eip" "nat_zone_b" {
  count  = var.enable_nat_gateway_zone_b ? 1 : 0
  domain = "vpc"

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-nat-eip-${var.availability_zone_b}"
    }
  )

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateway Zone B (optional for HA)
resource "aws_nat_gateway" "zone_b" {
  count         = var.enable_nat_gateway_zone_b ? 1 : 0
  allocation_id = aws_eip.nat_zone_b[0].id
  subnet_id     = aws_subnet.public_zone_b.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-nat-${var.availability_zone_b}"
    }
  )

  depends_on = [aws_internet_gateway.main]
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-public-rt"
    }
  )
}

# Public Route to Internet Gateway
resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

# Public Route Table Association - Zone A
resource "aws_route_table_association" "public_zone_a" {
  subnet_id      = aws_subnet.public_zone_a.id
  route_table_id = aws_route_table.public.id
}

# Public Route Table Association - Zone B
resource "aws_route_table_association" "public_zone_b" {
  subnet_id      = aws_subnet.public_zone_b.id
  route_table_id = aws_route_table.public.id
}

# Public Route Table Association - Zone C (optional)
resource "aws_route_table_association" "public_zone_c" {
  count          = local.enable_zone_c ? 1 : 0
  subnet_id      = aws_subnet.public_zone_c[0].id
  route_table_id = aws_route_table.public.id
}

# Private Route Table - Zone A
resource "aws_route_table" "private_zone_a" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-private-rt-${var.availability_zone_a}"
    }
  )
}

# Private Route to NAT Gateway - Zone A
resource "aws_route" "private_nat_gateway_zone_a" {
  route_table_id         = aws_route_table.private_zone_a.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.zone_a.id
}

# Private Route Table Association - Zone A
resource "aws_route_table_association" "private_zone_a" {
  subnet_id      = aws_subnet.private_zone_a.id
  route_table_id = aws_route_table.private_zone_a.id
}

# Private Route Table - Zone B
resource "aws_route_table" "private_zone_b" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-private-rt-${var.availability_zone_b}"
    }
  )
}

# Private Route to NAT Gateway - Zone B
resource "aws_route" "private_nat_gateway_zone_b" {
  route_table_id         = aws_route_table.private_zone_b.id
  destination_cidr_block = "0.0.0.0/0"
  # Use Zone B NAT if enabled, otherwise use Zone A NAT
  nat_gateway_id = var.enable_nat_gateway_zone_b ? aws_nat_gateway.zone_b[0].id : aws_nat_gateway.zone_a.id
}

# Private Route Table Association - Zone B
resource "aws_route_table_association" "private_zone_b" {
  subnet_id      = aws_subnet.private_zone_b.id
  route_table_id = aws_route_table.private_zone_b.id
}

# Private Route Table - Zone C (optional)
resource "aws_route_table" "private_zone_c" {
  count  = local.enable_zone_c ? 1 : 0
  vpc_id = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-private-rt-${var.availability_zone_c}"
    }
  )
}

# Private Route to NAT Gateway - Zone C
resource "aws_route" "private_nat_gateway_zone_c" {
  count                  = local.enable_zone_c ? 1 : 0
  route_table_id         = aws_route_table.private_zone_c[0].id
  destination_cidr_block = "0.0.0.0/0"
  # Use Zone C NAT if enabled, otherwise use Zone A NAT
  nat_gateway_id = var.enable_nat_gateway_zone_b ? aws_nat_gateway.zone_b[0].id : aws_nat_gateway.zone_a.id
}

# Private Route Table Association - Zone C
resource "aws_route_table_association" "private_zone_c" {
  count          = local.enable_zone_c ? 1 : 0
  subnet_id      = aws_subnet.private_zone_c[0].id
  route_table_id = aws_route_table.private_zone_c[0].id
}

# Database Subnet Group (for RDS)
resource "aws_db_subnet_group" "main" {
  name = "${var.environment}-${var.cluster_name}-db-subnet-group"
  subnet_ids = local.enable_zone_c ? [
    aws_subnet.database_zone_a.id,
    aws_subnet.database_zone_b.id,
    aws_subnet.database_zone_c[0].id
    ] : [
    aws_subnet.database_zone_a.id,
    aws_subnet.database_zone_b.id
  ]

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-db-subnet-group"
    }
  )
}

# VPC Flow Logs (optional)
resource "aws_flow_log" "main" {
  count = var.enable_flow_logs ? 1 : 0

  iam_role_arn    = aws_iam_role.flow_logs[0].arn
  log_destination = aws_cloudwatch_log_group.flow_logs[0].arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-flow-logs"
    }
  )
}

# CloudWatch Log Group for Flow Logs
resource "aws_cloudwatch_log_group" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name              = "/aws/vpc/${var.environment}-${var.cluster_name}"
  retention_in_days = var.flow_logs_retention_days

  tags = local.common_tags
}

# IAM Role for Flow Logs
resource "aws_iam_role" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${var.environment}-${var.cluster_name}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

# IAM Policy for Flow Logs
resource "aws_iam_role_policy" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${var.environment}-${var.cluster_name}-vpc-flow-logs-policy"
  role = aws_iam_role.flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}
