variable "environment" {
  type        = string
  description = "Environment name"
}

variable "cluster_name" {
  type        = string
  description = "EKS cluster name"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "availability_zone_a" {
  type = string
}

variable "availability_zone_b" {
  type = string
}

variable "availability_zone_c" {
  type    = string
  default = null
}

variable "enable_database_subnets" {
  type    = bool
  default = false
}

variable "enable_flow_logs" {
  type    = bool
  default = true
}

variable "single_nat_gateway" {
  description = "Provision a single NAT Gateway (true) or one per AZ (false). Use true for dev/cost-saving, false for prod/HA."
  type        = bool
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}