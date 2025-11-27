# VPC Module - Reusable Network Foundation
# Based on AWS Architecture Recommendation (10.x.0.0/16)
# Supports 3-tier architecture: Public, Private, Database subnets

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
  
  public_subnet_cidr_a  = coalesce(var.public_subnet_cidr_zone_a, "10.${local.vpc_second_octet}.1.0/24")
  public_subnet_cidr_b  = coalesce(var.public_subnet_cidr_zone_b, "10.${local.vpc_second_octet}.2.0/24")
  public_subnet_cidr_c  = coalesce(var.public_subnet_cidr_zone_c, "10.${local.vpc_second_octet}.3.0/24")
  
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
      "Provisioner"                                = "Created By Terraform"
      "Environment"                                = var.environment
    }
  )
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-${var.cluster_name}"
    }
  )
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-igw"
    }
  )
}

# Public Subnet - Zone A
resource "aws_subnet" "public_zone_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_subnet_cidr_a
  availability_zone       = var.availability_zone_a
  map_public_ip_on_launch = true

  tags = merge(
    local.common_tags,
    {
      Name                     = "${var.environment}-public-${var.availability_zone_a}"
      "kubernetes.io/role/elb" = "1"
      "Tier"                   = "Public"
    }
  )
}

# Public Subnet - Zone B
resource "aws_subnet" "public_zone_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_subnet_cidr_b
  availability_zone       = var.availability_zone_b
  map_public_ip_on_launch = true

  tags = merge(
    local.common_tags,
    {
      Name                     = "${var.environment}-public-${var.availability_zone_b}"
      "kubernetes.io/role/elb" = "1"
      "Tier"                   = "Public"
    }
  )
}

# Public Subnet - Zone C (optional)
resource "aws_subnet" "public_zone_c" {
  count                   = local.enable_zone_c ? 1 : 0
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_subnet_cidr_c
  availability_zone       = var.availability_zone_c
  map_public_ip_on_launch = true

  tags = merge(
    local.common_tags,
    {
      Name                     = "${var.environment}-public-${var.availability_zone_c}"
      "kubernetes.io/role/elb" = "1"
      "Tier"                   = "Public"
    }
  )
}

# Private Subnet - Zone A (for EKS nodes and pods)
resource "aws_subnet" "private_zone_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_subnet_cidr_a
  availability_zone = var.availability_zone_a

  tags = merge(
    local.common_tags,
    {
      Name                              = "${var.environment}-private-${var.availability_zone_a}"
      "kubernetes.io/role/internal-elb" = "1"
      "Tier"                            = "Private"
    }
  )
}

# Private Subnet - Zone B (for EKS nodes and pods)
resource "aws_subnet" "private_zone_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_subnet_cidr_b
  availability_zone = var.availability_zone_b

  tags = merge(
    local.common_tags,
    {
      Name                              = "${var.environment}-private-${var.availability_zone_b}"
      "kubernetes.io/role/internal-elb" = "1"
      "Tier"                            = "Private"
    }
  )
}

# Private Subnet - Zone C (optional, for EKS nodes and pods)
resource "aws_subnet" "private_zone_c" {
  count             = local.enable_zone_c ? 1 : 0
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_subnet_cidr_c
  availability_zone = var.availability_zone_c

  tags = merge(
    local.common_tags,
    {
      Name                              = "${var.environment}-private-${var.availability_zone_c}"
      "kubernetes.io/role/internal-elb" = "1"
      "Tier"                            = "Private"
    }
  )
}

# Database Subnet - Zone A (for RDS, ElastiCache)
resource "aws_subnet" "database_zone_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.database_subnet_cidr_a
  availability_zone = var.availability_zone_a

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-database-${var.availability_zone_a}"
      "Tier" = "Database"
    }
  )
}

# Database Subnet - Zone B (for RDS, ElastiCache)
resource "aws_subnet" "database_zone_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.database_subnet_cidr_b
  availability_zone = var.availability_zone_b

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-database-${var.availability_zone_b}"
      "Tier" = "Database"
    }
  )
}

# Database Subnet - Zone C (optional, for RDS, ElastiCache)
resource "aws_subnet" "database_zone_c" {
  count             = local.enable_zone_c ? 1 : 0
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.database_subnet_cidr_c
  availability_zone = var.availability_zone_c

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-database-${var.availability_zone_c}"
      "Tier" = "Database"
    }
  )
}

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
  name       = "${var.environment}-${var.cluster_name}-db-subnet-group"
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
