# VPC Module Variables
# Based on existing infrastructure design (172.16.0.0/16)

variable "environment" {
  description = "Environment name (dev, prod, shared-services)"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "172.16.0.0/16"
}

variable "availability_zone_a" {
  description = "First availability zone"
  type        = string
}

variable "availability_zone_b" {
  description = "Second availability zone"
  type        = string
}

variable "public_subnet_cidr_zone_a" {
  description = "CIDR for public subnet in zone A"
  type        = string
  default     = "172.16.0.0/24"
}

variable "public_subnet_cidr_zone_b" {
  description = "CIDR for public subnet in zone B"
  type        = string
  default     = "172.16.1.0/24"
}

variable "private_subnet_cidr_zone_a" {
  description = "CIDR for private subnet in zone A"
  type        = string
  default     = "172.16.2.0/24"
}

variable "private_subnet_cidr_zone_b" {
  description = "CIDR for private subnet in zone B"
  type        = string
  default     = "172.16.3.0/24"
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

variable "flow_logs_retention_days" {
  description = "Retention period for flow logs in days"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}
