# =============================================================================
# VPC Module Variables
# =============================================================================

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "altanova"
}

variable "region" {
  description = "AWS region for the VPC"
  type        = string
  default     = "eu-west-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway for cost optimization"
  type        = bool
  default     = true
}

variable "shared_account_id" {
  description = "AWS Account ID of the Shared Account (where VPC is created)"
  type        = string
}

variable "dev_account_id" {
  description = "AWS Account ID for the Dev environment"
  type        = string
  default     = ""
}

variable "prod_account_id" {
  description = "AWS Account ID for the Prod environment"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
