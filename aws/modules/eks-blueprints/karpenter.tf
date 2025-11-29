# Karpenter NodePool and EC2NodeClass Resources
# These are deployed via Terraform after Karpenter is installed

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
      amiFamily = "AL2023" # Amazon Linux 2023 - AWS recommended for EKS
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
          volumeSize          = "20Gi"
          volumeType          = "gp3"
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

# General Purpose NodePool
resource "kubernetes_manifest" "karpenter_node_pool" {
  count = var.enable_karpenter ? 1 : 0

  manifest = {
    apiVersion = "karpenter.sh/v1beta1"
    kind       = "NodePool"
    metadata = {
      name = "general-purpose"
    }
    spec = {
      template = {
        metadata = {
          labels = {
            workload    = "general"
            environment = var.environment
            managed-by  = "karpenter"
          }
        }
        spec = {
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
              values   = ["t", "c", "m", "r"] # General purpose, compute, memory optimized
            },
            {
              key      = "karpenter.k8s.aws/instance-generation"
              operator = "Gt"
              values   = ["2"] # Only use instance types newer than generation 2
            }
          ]
          nodeClassRef = {
            name = "default"
          }
        }
      }
      limits = {
        cpu    = var.environment == "prod" ? "200" : "100"
        memory = var.environment == "prod" ? "400Gi" : "200Gi"
      }
      disruption = {
        consolidationPolicy = "WhenUnderutilized"
        consolidateAfter    = var.environment == "prod" ? "60s" : "30s"
        budgets = [{
          nodes = var.environment == "prod" ? "5%" : "10%"
          reasons = [
            "Underutilized",
            "Empty"
          ]
        }]
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
