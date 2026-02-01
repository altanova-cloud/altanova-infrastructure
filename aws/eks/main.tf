# =============================================================================
# EKS - Workspace-based Deployment
# =============================================================================
#
# Uses Terraform workspaces for environment + region separation.
#
# Workspace naming: {env}-{region_code}
#   - dev-euw1   (Dev in eu-west-1)
#   - prod-euw1  (Prod in eu-west-1)
#   - dev-use1   (Dev in us-east-1, future)
#
# Usage:
#   terraform workspace new dev-euw1
#   terraform workspace select dev-euw1
#   terraform plan
# =============================================================================

terraform {
  required_version = ">= 1.8"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.0"
    }
  }

  backend "http" {}
}

# =============================================================================
# Workspace Configuration
# =============================================================================
locals {
  # Parse workspace: "dev-euw1" -> env="dev", region_code="euw1"
  workspace_parts = split("-", terraform.workspace)
  environment     = local.workspace_parts[0]
  region_code     = local.workspace_parts[1]

  # Region mapping
  region_map = {
    euw1 = "eu-west-1"
    euw2 = "eu-west-2"
    eus2 = "eu-south-2" # Spain
    use1 = "us-east-1"
    use2 = "us-east-2"
  }
  region = local.region_map[local.region_code]

  # Account IDs
  account_map = {
    dev  = "975050047325"
    prod = "624755517249"
  }
  account_id = local.account_map[local.environment]

  # IAM Roles
  role_map = {
    dev  = "arn:aws:iam::975050047325:role/DevDeployRole"
    prod = "arn:aws:iam::624755517249:role/ProdDeployRole"
  }

  # ---------------------------------------------------------------------------
  # Environment-specific Configuration
  # ---------------------------------------------------------------------------
  env_config = {
    dev = {
      # System nodes
      system_node_instance_types = ["t3.small"]
      system_node_min_size       = 0
      system_node_max_size       = 2
      system_node_desired_size   = 1
      system_node_disk_size      = 50

      # General pool
      default_node_disk_size           = 50
      general_pool_capacity_types      = ["spot", "on-demand"]
      general_pool_instance_categories = ["t", "m", "c"]
      general_pool_instance_sizes      = ["small", "medium", "large"]
      general_pool_cpu_limit           = 50
      general_pool_memory_limit        = "100Gi"
      consolidation_delay              = "1m"

      # GPU pool
      enable_gpu_nodes        = true
      gpu_node_disk_size      = 200
      gpu_pool_capacity_types = ["spot", "on-demand"]
      gpu_instance_types      = ["g4dn.xlarge", "g4dn.2xlarge"]
      gpu_pool_cpu_limit      = 32
      gpu_pool_memory_limit   = "128Gi"
      gpu_pool_gpu_limit      = 4
      gpu_consolidation_delay = "5m"
    }

    prod = {
      # System nodes (larger for prod)
      system_node_instance_types = ["t3.medium"]
      system_node_min_size       = 1
      system_node_max_size       = 3
      system_node_desired_size   = 2
      system_node_disk_size      = 100

      # General pool (reliability-focused)
      default_node_disk_size           = 100
      general_pool_capacity_types      = ["on-demand", "spot"]
      general_pool_instance_categories = ["m", "c", "r"]
      general_pool_instance_sizes      = ["medium", "large", "xlarge"]
      general_pool_cpu_limit           = 200
      general_pool_memory_limit        = "400Gi"
      consolidation_delay              = "10m"

      # GPU pool (larger limits)
      enable_gpu_nodes        = true
      gpu_node_disk_size      = 500
      gpu_pool_capacity_types = ["on-demand", "spot"]
      gpu_instance_types      = ["g4dn.xlarge", "g4dn.2xlarge", "g4dn.4xlarge"]
      gpu_pool_cpu_limit      = 64
      gpu_pool_memory_limit   = "256Gi"
      gpu_pool_gpu_limit      = 8
      gpu_consolidation_delay = "15m"
    }
  }

  # Current environment config
  config = local.env_config[local.environment]

  # ---------------------------------------------------------------------------
  # VPC Configuration (from shared VPC)
  # Update these after deploying shared/vpc
  # ---------------------------------------------------------------------------
  vpc_config = {
    "dev-euw1" = {
      vpc_id             = "REPLACE_WITH_VPC_ID"
      private_subnet_ids = ["REPLACE_DEV_PRIVATE_A", "REPLACE_DEV_PRIVATE_B"]
      public_subnet_ids  = ["REPLACE_DEV_PUBLIC_A", "REPLACE_DEV_PUBLIC_B"]
    }
    "prod-euw1" = {
      vpc_id             = "REPLACE_WITH_VPC_ID"
      private_subnet_ids = ["REPLACE_PROD_PRIVATE_A", "REPLACE_PROD_PRIVATE_B"]
      public_subnet_ids  = ["REPLACE_PROD_PUBLIC_A", "REPLACE_PROD_PUBLIC_B"]
    }
  }

  vpc = local.vpc_config[terraform.workspace]
}

# =============================================================================
# Providers
# =============================================================================
provider "aws" {
  region = local.region

  default_tags {
    tags = {
      Environment = local.environment
      Region      = local.region
      ManagedBy   = "Terraform"
      Project     = "AltaNova"
      Workspace   = terraform.workspace
    }
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", local.region]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", local.region]
    }
  }
}

provider "kubectl" {
  apply_retry_count      = 5
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", local.region]
  }
}

# =============================================================================
# EKS Cluster Module
# =============================================================================
module "eks" {
  source = "../modules/eks-cluster"

  project_name = "altanova"
  environment  = local.environment
  region       = local.region
  region_code  = local.region_code

  # VPC configuration
  vpc_id             = local.vpc.vpc_id
  private_subnet_ids = local.vpc.private_subnet_ids
  public_subnet_ids  = local.vpc.public_subnet_ids

  # Cluster configuration
  cluster_version                = "1.31"
  cluster_endpoint_public_access = false

  # System node group
  system_node_instance_types = local.config.system_node_instance_types
  system_node_min_size       = local.config.system_node_min_size
  system_node_max_size       = local.config.system_node_max_size
  system_node_desired_size   = local.config.system_node_desired_size
  system_node_disk_size      = local.config.system_node_disk_size

  # Karpenter
  karpenter_version  = "1.0.8"
  karpenter_replicas = 2

  # General NodePool
  default_node_disk_size           = local.config.default_node_disk_size
  general_pool_capacity_types      = local.config.general_pool_capacity_types
  general_pool_instance_categories = local.config.general_pool_instance_categories
  general_pool_instance_sizes      = local.config.general_pool_instance_sizes
  general_pool_cpu_limit           = local.config.general_pool_cpu_limit
  general_pool_memory_limit        = local.config.general_pool_memory_limit
  consolidation_delay              = local.config.consolidation_delay
  node_expire_after                = "720h"

  # GPU NodePool
  enable_gpu_nodes        = local.config.enable_gpu_nodes
  gpu_node_disk_size      = local.config.gpu_node_disk_size
  gpu_pool_capacity_types = local.config.gpu_pool_capacity_types
  gpu_instance_types      = local.config.gpu_instance_types
  gpu_pool_cpu_limit      = local.config.gpu_pool_cpu_limit
  gpu_pool_memory_limit   = local.config.gpu_pool_memory_limit
  gpu_pool_gpu_limit      = local.config.gpu_pool_gpu_limit
  gpu_consolidation_delay = local.config.gpu_consolidation_delay

  tags = {
    Environment = local.environment
    Workspace   = terraform.workspace
  }
}

# =============================================================================
# Outputs
# =============================================================================
output "workspace" {
  description = "Current workspace"
  value       = terraform.workspace
}

output "environment" {
  description = "Environment"
  value       = local.environment
}

output "region" {
  description = "AWS Region"
  value       = local.region
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL"
  value       = module.eks.cluster_oidc_issuer_url
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN"
  value       = module.eks.oidc_provider_arn
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = module.eks.configure_kubectl
}

output "karpenter_iam_role_arn" {
  description = "Karpenter IAM role ARN"
  value       = module.eks.karpenter_iam_role_arn
}
