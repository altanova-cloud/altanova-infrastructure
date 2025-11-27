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

  # Node groups - cost-optimized for dev
  node_groups = {
    general = {
      instance_types = ["t3.medium"]
      min_size       = 2
      max_size       = 4
      desired_size   = 2

      labels = {
        workload    = "general"
        environment = "dev"
      }

      tags = {
        Name = "altanova-dev-general"
      }
    }
  }

  # Core add-ons (always enabled)
  enable_aws_load_balancer_controller = true
  enable_metrics_server               = true
  enable_cluster_autoscaler           = true
  enable_gateway_api                  = true  # Modern networking

  # Optional add-ons (disabled for now, enable when needed)
  enable_aws_for_fluentbit     = false  # Enable when you need logging
  enable_argocd                = false  # Enable when ready for GitOps
  enable_kube_prometheus_stack = false  # Enable when you need monitoring

  # CloudWatch logging
  cluster_enabled_log_types = ["api", "audit", "authenticator"]

  tags = {
    Environment = "dev"
    ManagedBy   = "Terraform"
    Project     = "AltaNova"
  }

  depends_on = [module.vpc]
}
