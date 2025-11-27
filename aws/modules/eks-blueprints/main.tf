# EKS Blueprints Module
# Wrapper around AWS EKS Blueprints for standardized cluster deployment

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.9"
    }
  }
}

# EKS Cluster using AWS EKS Blueprints
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  # Network configuration
  vpc_id                   = var.vpc_id
  subnet_ids               = var.private_subnet_ids
  control_plane_subnet_ids = var.private_subnet_ids

  # Cluster endpoint access
  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_endpoint_private_access = true

  # Cluster addons
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  # Enable IRSA (IAM Roles for Service Accounts)
  enable_irsa = true

  # Managed node groups
  eks_managed_node_groups = var.node_groups

  # Cluster security group rules
  cluster_security_group_additional_rules = {
    ingress_nodes_ephemeral_ports_tcp = {
      description                = "Nodes on ephemeral ports"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "ingress"
      source_node_security_group = true
    }
  }

  # Node security group rules
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    
    ingress_cluster_all = {
      description                   = "Cluster to node all ports/protocols"
      protocol                      = "-1"
      from_port                     = 0
      to_port                       = 0
      type                          = "ingress"
      source_cluster_security_group = true
    }
    
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

  # Cluster encryption
  cluster_encryption_config = var.enable_cluster_encryption ? {
    resources        = ["secrets"]
    provider_key_arn = var.kms_key_arn
  } : {}

  # CloudWatch logging
  cluster_enabled_log_types = var.cluster_enabled_log_types

  tags = merge(
    var.tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Cluster     = var.cluster_name
    }
  )
}

# EKS Blueprints Add-ons
module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.16"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  # Core add-ons
  enable_aws_load_balancer_controller = var.enable_aws_load_balancer_controller
  enable_metrics_server               = var.enable_metrics_server
  enable_cluster_autoscaler           = var.enable_cluster_autoscaler

  # Storage
  enable_aws_ebs_csi_driver = true
  enable_aws_efs_csi_driver = var.enable_aws_efs_csi_driver

  # Ingress - Modern approach with Gateway API
  # AWS Load Balancer Controller supports both Ingress and Gateway API
  enable_aws_load_balancer_controller = var.enable_aws_load_balancer_controller
  aws_load_balancer_controller = var.enable_aws_load_balancer_controller ? {
    enable_service_monitor = true
    # Enable Gateway API support
    set = [
      {
        name  = "enableServiceMutatorWebhook"
        value = "false"
      }
    ]
  } : {}

  # Gateway API CRDs (if enabled)
  # Note: Gateway API is the successor to Ingress
  enable_aws_gateway_api_controller = var.enable_gateway_api


  # Logging
  enable_aws_for_fluentbit = var.enable_aws_for_fluentbit
  aws_for_fluentbit = var.enable_aws_for_fluentbit ? {
    values = [templatefile("${path.module}/helm-values/aws-for-fluentbit-values.yaml", {
      cluster_name = var.cluster_name
      region       = data.aws_region.current.name
    })]
  } : {}

  # GitOps
  enable_argocd = var.enable_argocd
  argocd = var.enable_argocd ? {
    values = [file("${path.module}/helm-values/argocd-values.yaml")]
  } : {}

  # Monitoring (optional)
  enable_kube_prometheus_stack = var.enable_kube_prometheus_stack
  kube_prometheus_stack = var.enable_kube_prometheus_stack ? {
    values = [file("${path.module}/helm-values/kube-prometheus-stack-values.yaml")]
  } : {}

  tags = var.tags
}

# Data sources
data "aws_region" "current" {}

data "aws_caller_identity" "current" {}
