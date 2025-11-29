# Karpenter NodePool and EC2NodeClass Resources
# These are deployed via Terraform after Karpenter is installed

locals {
  # Default NodePool configuration if none provided
  default_node_pools = {
    general-purpose = {
      labels = {
        workload    = "general"
        environment = var.environment
        managed-by  = "karpenter"
      }
      requirements = [
        {
          key      = "karpenter.sh/capacity-type"
          operator = "In"
          values   = var.environment == "prod" ? ["on-demand"] : ["spot", "on-demand"]
        },
        {
          key      = "kubernetes.io/arch"
          operator = "In"
          values   = ["amd64"]
        },
        {
          key      = "topology.kubernetes.io/zone"
          operator = "In"
          values   = data.aws_availability_zones.available.names
        },
        {
          key      = "karpenter.k8s.aws/instance-category"
          operator = "In"
          values   = ["t", "c", "m", "r"]
        },
        {
          key      = "karpenter.k8s.aws/instance-generation"
          operator = "Gt"
          values   = ["2"]
        }
      ]
      limits = {
        cpu    = var.environment == "prod" ? "200" : "100"
        memory = var.environment == "prod" ? "400Gi" : "200Gi"
      }
      taints = []
    }
  }

  # Use provided pools or fallback to default
  node_pools = length(var.karpenter_node_pools) > 0 ? var.karpenter_node_pools : local.default_node_pools

  # Node Class defaults
  node_class_defaults = {
    ami_family  = "AL2023"
    volume_size = "20Gi"
    volume_type = "gp3"
  }
  
  node_class_config = merge(local.node_class_defaults, var.karpenter_node_class_config)
}

# Default EC2NodeClass for Karpenter
resource "kubernetes_manifest" "karpenter_node_class" {
  count = var.enable_karpenter ? 1 : 0

  manifest = {
    apiVersion = "karpenter.k8s.aws/v1beta1"
    kind       = "EC2NodeClass"
    metadata = {
      name = "default"
    }
    spec = {
      amiFamily = local.node_class_config.ami_family
      role      = module.eks_blueprints_addons.karpenter.node_iam_role_name

      subnetSelectorTerms = [{
        tags = {
          "karpenter.sh/discovery" = var.cluster_name
        }
      }]

      securityGroupSelectorTerms = [{
        tags = {
          "karpenter.sh/discovery" = var.cluster_name
        }
      }]

      blockDeviceMappings = [{
        deviceName = "/dev/xvda"
        ebs = {
          volumeSize          = local.node_class_config.volume_size
          volumeType          = local.node_class_config.volume_type
          encrypted           = true
          deleteOnTermination = true
        }
      }]

      metadataOptions = {
        httpEndpoint            = "enabled"
        httpProtocolIPv6        = "disabled"
        httpPutResponseHopLimit = 2
        httpTokens              = "required"
      }

      tags = merge(
        var.tags,
        {
          "karpenter.sh/discovery" = var.cluster_name
        }
      )
    }
  }

  depends_on = [module.eks_blueprints_addons]
}

# Karpenter NodePools
resource "kubernetes_manifest" "karpenter_node_pool" {
  for_each = var.enable_karpenter ? local.node_pools : {}

  manifest = {
    apiVersion = "karpenter.sh/v1beta1"
    kind       = "NodePool"
    metadata = {
      name = each.key
    }
    spec = {
      template = {
        metadata = {
          labels = try(each.value.labels, {
            workload    = each.key
            environment = var.environment
            managed-by  = "karpenter"
          })
        }
        spec = {
          requirements = each.value.requirements
          nodeClassRef = {
            name = "default"
          }
          taints = try(each.value.taints, [])
        }
      }
      limits = try(each.value.limits, {
        cpu    = "100"
        memory = "200Gi"
      })
      disruption = {
        consolidationPolicy = try(each.value.disruption.consolidationPolicy, "WhenUnderutilized")
        consolidateAfter    = try(each.value.disruption.consolidateAfter, "30s")
        budgets = try(each.value.disruption.budgets, [{
          nodes = "10%"
        }])
      }
    }
  }

  depends_on = [
    module.eks_blueprints_addons,
    kubernetes_manifest.karpenter_node_class
  ]
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}
