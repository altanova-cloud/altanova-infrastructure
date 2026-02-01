# =============================================================================
# EKS Cluster Module Variables
# =============================================================================

# -----------------------------------------------------------------------------
# Core Configuration
# -----------------------------------------------------------------------------
variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "altanova"
}

variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Environment must be either 'dev' or 'prod'."
  }
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "region_code" {
  description = "Short region code for naming (e.g., euw1)"
  type        = string
  default     = "euw1"
}

# -----------------------------------------------------------------------------
# VPC Configuration (from shared VPC)
# -----------------------------------------------------------------------------
variable "vpc_id" {
  description = "VPC ID from shared VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for EKS nodes"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for ALB"
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# EKS Cluster Configuration
# -----------------------------------------------------------------------------
variable "cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.31"
}

variable "cluster_endpoint_public_access" {
  description = "Enable public access to cluster endpoint"
  type        = bool
  default     = false
}

variable "access_entries" {
  description = "Map of access entries for EKS"
  type        = any
  default     = {}
}

# -----------------------------------------------------------------------------
# System Node Group Configuration
# -----------------------------------------------------------------------------
variable "system_node_instance_types" {
  description = "Instance types for system node group"
  type        = list(string)
  default     = ["t3.small"]
}

variable "system_node_min_size" {
  description = "Minimum size for system node group"
  type        = number
  default     = 0
}

variable "system_node_max_size" {
  description = "Maximum size for system node group"
  type        = number
  default     = 2
}

variable "system_node_desired_size" {
  description = "Desired size for system node group"
  type        = number
  default     = 1
}

variable "system_node_disk_size" {
  description = "Disk size for system nodes in GB"
  type        = number
  default     = 50
}

# -----------------------------------------------------------------------------
# Karpenter Configuration
# -----------------------------------------------------------------------------
variable "karpenter_version" {
  description = "Karpenter Helm chart version"
  type        = string
  default     = "1.0.8"
}

variable "karpenter_replicas" {
  description = "Number of Karpenter controller replicas"
  type        = number
  default     = 2
}

# -----------------------------------------------------------------------------
# General NodePool Configuration
# -----------------------------------------------------------------------------
variable "default_node_disk_size" {
  description = "Default disk size for Karpenter nodes in GB"
  type        = number
  default     = 50
}

variable "general_pool_capacity_types" {
  description = "Capacity types for general NodePool (spot, on-demand)"
  type        = list(string)
  default     = ["spot", "on-demand"]
}

variable "general_pool_instance_categories" {
  description = "Instance categories for general NodePool"
  type        = list(string)
  default     = ["t", "m", "c"]
}

variable "general_pool_instance_sizes" {
  description = "Instance sizes for general NodePool"
  type        = list(string)
  default     = ["small", "medium", "large"]
}

variable "general_pool_cpu_limit" {
  description = "CPU limit for general NodePool"
  type        = number
  default     = 50
}

variable "general_pool_memory_limit" {
  description = "Memory limit for general NodePool"
  type        = string
  default     = "100Gi"
}

variable "consolidation_delay" {
  description = "Delay before consolidating underutilized nodes"
  type        = string
  default     = "1m"
}

variable "node_expire_after" {
  description = "Duration after which nodes are replaced"
  type        = string
  default     = "720h"
}

# -----------------------------------------------------------------------------
# GPU NodePool Configuration
# -----------------------------------------------------------------------------
variable "enable_gpu_nodes" {
  description = "Enable GPU NodePool for inference workloads"
  type        = bool
  default     = true
}

variable "gpu_node_disk_size" {
  description = "Disk size for GPU nodes in GB"
  type        = number
  default     = 200
}

variable "gpu_pool_capacity_types" {
  description = "Capacity types for GPU NodePool"
  type        = list(string)
  default     = ["spot", "on-demand"]
}

variable "gpu_instance_types" {
  description = "GPU instance types for inference"
  type        = list(string)
  default     = ["g4dn.xlarge", "g4dn.2xlarge"]
}

variable "gpu_pool_cpu_limit" {
  description = "CPU limit for GPU NodePool"
  type        = number
  default     = 32
}

variable "gpu_pool_memory_limit" {
  description = "Memory limit for GPU NodePool"
  type        = string
  default     = "128Gi"
}

variable "gpu_pool_gpu_limit" {
  description = "GPU limit for GPU NodePool"
  type        = number
  default     = 4
}

variable "gpu_consolidation_delay" {
  description = "Delay before consolidating GPU nodes (longer to avoid thrashing)"
  type        = string
  default     = "5m"
}

# -----------------------------------------------------------------------------
# Tags
# -----------------------------------------------------------------------------
variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
