# Dev Environment - EKS Cluster with Karpenter
# Architecture: System nodes (managed) + Application nodes (Karpenter-managed)
#
# System Nodes: 2x t3.small (on-demand) with CriticalAddonsOnly taint
#   - Runs: Karpenter controller, CoreDNS, AWS LB Controller, system add-ons
#
# Application Nodes: Dynamically provisioned by Karpenter
#   - Runs: All application workloads
#   - Uses SPOT instances with on-demand fallback

locals {
  cluster_name    = "${local.project_name}-${local.environment}-${local.region_code}-eks"
  cluster_version = "1.31"

  # Tags for Karpenter auto-discovery
  eks_tags = merge(local.common_tags, {
    "karpenter.sh/discovery" = local.cluster_name
  })
}

# -----------------------------------------------------------------------------
# EKS Cluster
# -----------------------------------------------------------------------------
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.cluster_name
  cluster_version = local.cluster_version

  # Cluster endpoint access - Private only (secure)
  cluster_endpoint_public_access  = false
  cluster_endpoint_private_access = true

  # VPC Configuration
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Control plane subnets (uses all subnets for HA)
  control_plane_subnet_ids = module.vpc.private_subnets

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
    karpenter-system = {
      name           = "${local.cluster_name}-system"
      instance_types = ["t3.small"]
      capacity_type  = "ON_DEMAND"

      min_size     = 0
      max_size     = 1
      desired_size = 1

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
            volume_size           = 50
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

      tags = merge(local.eks_tags, {
        NodeType = "system"
      })
    }
  }

  # Enable cluster creator admin permissions
  enable_cluster_creator_admin_permissions = true

  # Access entries for additional admins (optional)
  access_entries = {
    # Add GitHub Actions role for CI/CD access
    github-actions = {
      principal_arn     = var.github_actions_role_arn
      kubernetes_groups = []
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  tags = local.eks_tags
}

# -----------------------------------------------------------------------------
# Karpenter Module (IAM, SQS for spot interruption handling)
# -----------------------------------------------------------------------------
module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 20.0"

  cluster_name = module.eks.cluster_name

  # Enable IRSA for Karpenter
  enable_irsa            = true
  irsa_oidc_provider_arn = module.eks.oidc_provider_arn

  # Karpenter node IAM role
  node_iam_role_use_name_prefix = false
  node_iam_role_name            = "${local.cluster_name}-karpenter-node"

  # Enable spot termination handling
  enable_spot_termination = true

  tags = local.eks_tags
}

# -----------------------------------------------------------------------------
# Tag subnets and security groups for Karpenter discovery
# -----------------------------------------------------------------------------
resource "aws_ec2_tag" "private_subnet_karpenter" {
  for_each    = toset(module.vpc.private_subnets)
  resource_id = each.value
  key         = "karpenter.sh/discovery"
  value       = local.cluster_name
}

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
