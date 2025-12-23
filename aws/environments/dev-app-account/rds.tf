# Dev Environment - RDS PostgreSQL
# Free tier configuration for development and learning

locals {
  db_name     = "altanova"
  db_username = "dbadmin"
  db_port     = 5432
}

# Random password for RDS master user
resource "random_password" "db_password" {
  length  = 32
  special = true
  # Exclude problematic characters for database passwords
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Store password in AWS Secrets Manager
resource "aws_secretsmanager_secret" "db_password" {
  name_prefix             = "${local.project_name}-${local.environment}-db-password-"
  description             = "RDS PostgreSQL master password for ${local.environment} environment"
  recovery_window_in_days = 7

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-db-password"
    }
  )
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    username = local.db_username
    password = random_password.db_password.result
    engine   = "postgres"
    host     = module.rds.db_instance_address
    port     = local.db_port
    dbname   = local.db_name
  })
}

# Security group for RDS
resource "aws_security_group" "rds" {
  name_prefix = "${local.project_name}-${local.environment}-rds-"
  description = "Security group for RDS PostgreSQL database"
  vpc_id      = module.vpc.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-${local.region_code}-rds-sg"
    }
  )
}

# Allow inbound PostgreSQL from VPC (private subnets where EKS nodes will be)
resource "aws_vpc_security_group_ingress_rule" "rds_from_vpc" {
  security_group_id = aws_security_group.rds.id
  description       = "PostgreSQL access from VPC"

  from_port   = local.db_port
  to_port     = local.db_port
  ip_protocol = "tcp"
  cidr_ipv4   = module.vpc.vpc_cidr_block
}

# Outbound - allow all (standard for RDS)
resource "aws_vpc_security_group_egress_rule" "rds_outbound" {
  security_group_id = aws_security_group.rds.id
  description       = "Allow all outbound traffic"

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
}

# RDS PostgreSQL using official AWS module
module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  # Database identification
  identifier = "${local.project_name}-${local.environment}-${local.region_code}-postgres"

  # Engine configuration
  engine               = "postgres"
  engine_version       = "18.1"
  family               = "postgres18"
  major_engine_version = "18"
  instance_class       = "db.t3.micro" # Free tier eligible

  # Storage - Free tier: 20GB
  allocated_storage     = 20
  max_allocated_storage = 0 # Disable autoscaling for free tier
  storage_type          = "gp3"
  storage_encrypted     = true

  # Database configuration
  db_name  = local.db_name
  username = local.db_username
  password = random_password.db_password.result
  port     = local.db_port

  # Network configuration - Using the database subnet group from VPC module
  db_subnet_group_name   = module.vpc.database_subnet_group_name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  # High Availability - Disabled for dev/free tier
  multi_az = false

  # Maintenance and backup
  backup_retention_period = 7
  backup_window           = "03:00-04:00"         # 3-4 AM UTC
  maintenance_window      = "mon:04:00-mon:05:00" # Monday 4-5 AM UTC
  skip_final_snapshot     = true                  # Dev environment - skip final snapshot

  # Deletion protection - Disabled for dev
  deletion_protection = false

  # Monitoring
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  create_cloudwatch_log_group     = true
  monitoring_interval             = 60 # Enhanced monitoring every 60 seconds
  monitoring_role_name            = "${local.project_name}-${local.environment}-rds-monitoring-role"
  create_monitoring_role          = true

  # Performance Insights - Free tier: 7 days retention
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  # Parameter group
  parameters = [
    {
      name  = "log_connections"
      value = "receipt,authentication,authorization"
    },
    {
      name  = "log_disconnections"
      value = "1"
    },
    {
      name  = "log_duration"
      value = "1"
    }
  ]

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-${local.region_code}-postgres"
    }
  )
}
