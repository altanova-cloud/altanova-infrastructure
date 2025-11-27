# VPC Module Variables
# Based on AWS Architecture Recommendation (10.x.0.0/16)
# Dev: 10.0.0.0/16, Prod: 10.1.0.0/16

variable "environment" {
  description = "Environment name (dev, prod, shared-services)"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC (use 10.0.0.0/16 for dev, 10.1.0.0/16 for prod)"
  type        = string
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "availability_zone_a" {
  description = "First availability zone"
  type        = string
}

variable "availability_zone_b" {
  description = "Second availability zone"
  type        = string
}

variable "availability_zone_c" {
  description = "Third availability zone (optional, for prod HA)"
  type        = string
  default     = null
}

# Public Subnets (for ALB, NAT Gateway)
variable "public_subnet_cidr_zone_a" {
  description = "CIDR for public subnet in zone A (default: x.x.1.0/24)"
  type        = string
  default     = null
}

variable "public_subnet_cidr_zone_b" {
  description = "CIDR for public subnet in zone B (default: x.x.2.0/24)"
  type        = string
  default     = null
}

variable "public_subnet_cidr_zone_c" {
  description = "CIDR for public subnet in zone C (default: x.x.3.0/24)"
  type        = string
  default     = null
}

# Private Subnets (for EKS nodes and pods)
variable "private_subnet_cidr_zone_a" {
  description = "CIDR for private subnet in zone A (default: x.x.10.0/24)"
  type        = string
  default     = null
}

variable "private_subnet_cidr_zone_b" {
  description = "CIDR for private subnet in zone B (default: x.x.11.0/24)"
  type        = string
  default     = null
}

variable "private_subnet_cidr_zone_c" {
  description = "CIDR for private subnet in zone C (default: x.x.12.0/24)"
  type        = string
  default     = null
}

# Database Subnets (for RDS, ElastiCache)
variable "database_subnet_cidr_zone_a" {
  description = "CIDR for database subnet in zone A (default: x.x.20.0/24)"
  type        = string
  default     = null
}

variable "database_subnet_cidr_zone_b" {
  description = "CIDR for database subnet in zone B (default: x.x.21.0/24)"
  type        = string
  default     = null
}

variable "database_subnet_cidr_zone_c" {
  description = "CIDR for database subnet in zone C (default: x.x.22.0/24)"
  type        = string
  default     = null
}

variable "enable_nat_gateway_zone_b" {
  description = "Enable second NAT gateway for HA (recommended for prod)"
  type        = bool
  default     = false
}

variable "enable_flow_logs" {
  description = "Enable VPC flow logs"
  type        = bool
  default     = true
}

variable "enable_database_subnets" {
  description = "Create database subnets and subnet group"
  type        = bool
  default     = false
}

variable "flow_logs_retention_days" {
  description = "Retention period for flow logs in days"
  type        = number
  default     = 30
}

variable "enable_database_subnets" {
  description = "Enable database subnets for RDS and ElastiCache."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}
