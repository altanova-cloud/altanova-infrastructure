# EKS Blueprints Module Variables

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.32"
}

variable "environment" {
  description = "Environment name (dev, prod, shared-services)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where EKS cluster will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for EKS nodes"
  type        = list(string)
}

variable "cluster_endpoint_public_access" {
  description = "Enable public API server endpoint"
  type        = bool
  default     = true
}

variable "node_groups" {
  description = "Map of EKS managed node group definitions"
  type        = any
  default     = {}
}

variable "enable_cluster_encryption" {
  description = "Enable cluster encryption with KMS"
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "KMS key ARN for cluster encryption"
  type        = string
  default     = null
}

variable "cluster_enabled_log_types" {
  description = "List of control plane logging types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

# Add-ons configuration
variable "enable_aws_load_balancer_controller" {
  description = "Enable AWS Load Balancer Controller"
  type        = bool
  default     = true
}

variable "enable_metrics_server" {
  description = "Enable Metrics Server"
  type        = bool
  default     = true
}

variable "enable_cluster_autoscaler" {
  description = "Enable Cluster Autoscaler"
  type        = bool
  default     = true
}

variable "enable_aws_efs_csi_driver" {
  description = "Enable AWS EFS CSI Driver"
  type        = bool
  default     = false
}

variable "enable_gateway_api" {
  description = "Enable Kubernetes Gateway API (successor to Ingress)"
  type        = bool
  default     = true
}

variable "enable_aws_for_fluentbit" {
  description = "Enable AWS for Fluent Bit (logging)"
  type        = bool
  default     = false
}

variable "enable_argocd" {
  description = "Enable ArgoCD for GitOps"
  type        = bool
  default     = false
}

variable "enable_kube_prometheus_stack" {
  description = "Enable Kube Prometheus Stack (monitoring)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}
