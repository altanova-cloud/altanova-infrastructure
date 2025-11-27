# Dev Environment - EKS Cluster Configuration

module "eks" {
  source = "../../modules/eks-blueprints"

  cluster_name    = "altanova-dev"
  cluster_version = "1.32"
  environment     = "dev"

  # Network configuration
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  # Public endpoint for easier access in dev
  cluster_endpoint_public_access = true

  # Minimal node group ONLY for Karpenter controller and system components
  # Karpenter will manage all application workload nodes
  node_groups = {
    karpenter-system = {
      instance_types = ["t3.small"]  # Small instances for system components
      capacity_type  = "ON_DEMAND"   # On-demand for stability
      min_size       = 1             # Single node sufficient for dev
      max_size       = 1
      desired_size   = 1

      labels = {
        workload    = "system"
        environment = "dev"
      }

      # No taints - system components need to schedule here
      # Karpenter will create separate nodes for application workloads

      tags = {
        Name = "altanova-dev-system"
      }
    }
  }

  # Core add-ons
  enable_aws_load_balancer_controller = true
  enable_metrics_server               = true
  enable_gateway_api                  = true # Modern networking

  # Autoscaling - Use Karpenter for better cost optimization
  enable_karpenter          = true  # Intelligent node provisioning (up to 60% cost savings)
  enable_cluster_autoscaler = false # Disabled in favor of Karpenter

  # Optional add-ons (disabled for now, enable when needed)
  enable_aws_for_fluentbit     = false # Enable when you need logging
  enable_argocd                = false # Enable when ready for GitOps
  enable_kube_prometheus_stack = false # Enable when you need monitoring

  # CloudWatch logging
  cluster_enabled_log_types = ["api", "audit", "authenticator"]

  tags = {
    Environment = "dev"
    ManagedBy   = "Terraform"
    Project     = "AltaNova"
  }

  # Pass AWS provider for Karpenter ECR access
  providers = {
    aws.virginia = aws.virginia
  }

  depends_on = [module.vpc]
}
