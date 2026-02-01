# =============================================================================
# EKS Cluster Module Outputs
# =============================================================================

# -----------------------------------------------------------------------------
# Cluster Outputs
# -----------------------------------------------------------------------------
output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "Endpoint for EKS cluster API server"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data for the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_version" {
  description = "Kubernetes version of the cluster"
  value       = module.eks.cluster_version
}

output "cluster_id" {
  description = "ID of the EKS cluster"
  value       = module.eks.cluster_id
}

# -----------------------------------------------------------------------------
# Security Group Outputs
# -----------------------------------------------------------------------------
output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_primary_security_group_id" {
  description = "Primary security group ID of the EKS cluster"
  value       = module.eks.cluster_primary_security_group_id
}

output "node_security_group_id" {
  description = "Security group ID attached to the EKS nodes"
  value       = module.eks.node_security_group_id
}

# -----------------------------------------------------------------------------
# OIDC Provider Outputs
# -----------------------------------------------------------------------------
output "oidc_provider_arn" {
  description = "ARN of the OIDC provider"
  value       = module.eks.oidc_provider_arn
}

output "oidc_provider" {
  description = "OIDC provider URL without https:// prefix"
  value       = module.eks.oidc_provider
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for the cluster"
  value       = module.eks.cluster_oidc_issuer_url
}

# -----------------------------------------------------------------------------
# Node Group Outputs
# -----------------------------------------------------------------------------
output "eks_managed_node_groups" {
  description = "Map of EKS managed node groups"
  value       = module.eks.eks_managed_node_groups
}

output "eks_managed_node_groups_autoscaling_group_names" {
  description = "List of the autoscaling group names"
  value       = module.eks.eks_managed_node_groups_autoscaling_group_names
}

# -----------------------------------------------------------------------------
# Karpenter Outputs
# -----------------------------------------------------------------------------
output "karpenter_iam_role_arn" {
  description = "ARN of the Karpenter IAM role"
  value       = module.karpenter.iam_role_arn
}

output "karpenter_iam_role_name" {
  description = "Name of the Karpenter IAM role"
  value       = module.karpenter.iam_role_name
}

output "karpenter_node_iam_role_arn" {
  description = "ARN of the Karpenter node IAM role"
  value       = module.karpenter.node_iam_role_arn
}

output "karpenter_node_iam_role_name" {
  description = "Name of the Karpenter node IAM role"
  value       = module.karpenter.node_iam_role_name
}

output "karpenter_queue_name" {
  description = "Name of the Karpenter SQS queue for spot interruption"
  value       = module.karpenter.queue_name
}

output "karpenter_queue_arn" {
  description = "ARN of the Karpenter SQS queue"
  value       = module.karpenter.queue_arn
}

# -----------------------------------------------------------------------------
# Connection Information (for kubectl)
# -----------------------------------------------------------------------------
output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks --region ${var.region} update-kubeconfig --name ${module.eks.cluster_name}"
}
