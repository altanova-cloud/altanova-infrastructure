# =============================================================================
# EKS Cluster Module - Reusable for Dev and Prod
# =============================================================================
#
# This module creates an EKS cluster with:
#   - System node group (for Karpenter and critical add-ons)
#   - Karpenter IAM setup (SQS for spot interruption handling)
#   - EKS add-ons (CoreDNS, kube-proxy, vpc-cni, pod-identity-agent)
#   - IRSA (IAM Roles for Service Accounts)
#
# Architecture:
#   - System Nodes: Managed node group with CriticalAddonsOnly taint
#   - Application Nodes: Dynamically provisioned by Karpenter
#
# Usage:
#   - Deploy this module with environment-specific variables
#   - dev.tfvars: smaller instances, spot-first
#   - prod.tfvars: larger instances, on-demand fallback
# =============================================================================

locals {
  cluster_name = "${var.project_name}-${var.environment}-${var.region_code}-eks"

  common_tags = merge(var.tags, {
    Environment              = var.environment
    Project                  = var.project_name
    ManagedBy                = "Terraform"
    "karpenter.sh/discovery" = local.cluster_name
  })
}

# =============================================================================
# EKS Cluster
# =============================================================================
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version

  # Cluster endpoint access
  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_endpoint_private_access = true

  # VPC Configuration (from shared VPC)
  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  # Control plane subnets
  control_plane_subnet_ids = var.private_subnet_ids

  # Cluster addons
  cluster_addons = {
    coredns = {
      most_recent = true
      configuration_values = jsonencode({
        tolerations = [
          {
            key      = "CriticalAddonsOnly"
            operator = "Exists"
            effect   = "NoSchedule"
          }
        ]
      })
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent    = true
      before_compute = true
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
    eks-pod-identity-agent = {
      most_recent = true
    }
  }

  # Enable IRSA (IAM Roles for Service Accounts)
  enable_irsa = true

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
  }

  # ---------------------------------------------------------------------------
  # System Node Group (for Karpenter and critical add-ons)
  # ---------------------------------------------------------------------------
  eks_managed_node_groups = {
    system = {
      name           = "system"
      instance_types = var.system_node_instance_types
      capacity_type  = "ON_DEMAND"

      min_size     = var.system_node_min_size
      max_size     = var.system_node_max_size
      desired_size = var.system_node_desired_size

      # System node labels
      labels = {
        workload = "system"
        role     = "karpenter"
      }

      # Taint to prevent application pods from scheduling here
      taints = {
        CriticalAddonsOnly = {
          key    = "CriticalAddonsOnly"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }

      # Use latest Amazon Linux 2023 EKS-optimized AMI
      ami_type = "AL2023_x86_64_STANDARD"

      # Disk configuration
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = var.system_node_disk_size
            volume_type           = "gp3"
            iops                  = 3000
            throughput            = 125
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      # Instance metadata options (security hardening)
      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required" # IMDSv2
        http_put_response_hop_limit = 1
      }

      tags = merge(local.common_tags, {
        NodeType = "system"
      })
    }
  }

  # Enable cluster creator admin permissions
  enable_cluster_creator_admin_permissions = true

  # Access entries for additional admins
  access_entries = var.access_entries

  tags = local.common_tags
}

# =============================================================================
# Karpenter Module (IAM, SQS for spot interruption handling)
# =============================================================================
module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 20.0"

  cluster_name = module.eks.cluster_name

  # Enable IRSA for Karpenter
  enable_irsa            = true
  irsa_oidc_provider_arn = module.eks.oidc_provider_arn

  # Karpenter node IAM role
  node_iam_role_use_name_prefix = false
  node_iam_role_name            = "${var.environment}-karpenter-node"

  # Enable spot termination handling
  enable_spot_termination = true

  tags = local.common_tags
}

# =============================================================================
# Tag Security Groups for Karpenter Discovery
# =============================================================================
resource "aws_ec2_tag" "cluster_security_group_karpenter" {
  resource_id = module.eks.cluster_primary_security_group_id
  key         = "karpenter.sh/discovery"
  value       = local.cluster_name
}

resource "aws_ec2_tag" "node_security_group_karpenter" {
  resource_id = module.eks.node_security_group_id
  key         = "karpenter.sh/discovery"
  value       = local.cluster_name
}
