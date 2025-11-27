# VPC Module - Reusable Network Foundation
# Based on existing infrastructure subnet design (172.16.0.0/16)

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
  common_tags = merge(
    var.tags,
    {
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
      "Provisioner"                                = "Created By Terraform"
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
  cidr_block              = var.public_subnet_cidr_zone_a
  availability_zone       = var.availability_zone_a
  map_public_ip_on_launch = true

  tags = merge(
    local.common_tags,
    {
      Name                     = "${var.environment}-public-${var.availability_zone_a}"
      "kubernetes.io/role/elb" = "1"
    }
  )
}

# Public Subnet - Zone B
resource "aws_subnet" "public_zone_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr_zone_b
  availability_zone       = var.availability_zone_b
  map_public_ip_on_launch = true

  tags = merge(
    local.common_tags,
    {
      Name                     = "${var.environment}-public-${var.availability_zone_b}"
      "kubernetes.io/role/elb" = "1"
    }
  )
}

# Private Subnet - Zone A
resource "aws_subnet" "private_zone_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr_zone_a
  availability_zone = var.availability_zone_a

  tags = merge(
    local.common_tags,
    {
      Name                              = "${var.environment}-private-${var.availability_zone_a}"
      "kubernetes.io/role/internal-elb" = "1"
    }
  )
}

# Private Subnet - Zone B
resource "aws_subnet" "private_zone_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr_zone_b
  availability_zone = var.availability_zone_b

  tags = merge(
    local.common_tags,
    {
      Name                              = "${var.environment}-private-${var.availability_zone_b}"
      "kubernetes.io/role/internal-elb" = "1"
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
