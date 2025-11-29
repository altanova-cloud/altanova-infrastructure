# EKS Blueprints Module

A wrapper module around AWS EKS Blueprints for standardized Kubernetes cluster deployment.

## Features

- ✅ EKS Cluster v1.32 (configurable)
- ✅ AWS EKS Blueprints integration
- ✅ Managed node groups
- ✅ IRSA (IAM Roles for Service Accounts)
- ✅ Essential add-ons (ALB Controller, Metrics Server, Cluster Autoscaler)
- ✅ Optional add-ons (ArgoCD, Prometheus, Fluent Bit)
- ✅ Security best practices
- ✅ CloudWatch logging

## Prerequisites

### VPC Tagging for Karpenter

**IMPORTANT**: If you enable Karpenter (`enable_karpenter = true`), your VPC subnets and security groups **MUST** be tagged for Karpenter discovery:

```hcl
# Required tags on private subnets
tags = {
  "karpenter.sh/discovery" = var.cluster_name  # Must match your cluster name
}

# Required tags on node security group (automatically added by this module)
tags = {
  "karpenter.sh/discovery" = var.cluster_name
}
```

**If these tags are missing, Karpenter will fail to provision nodes.**

See your VPC module configuration to ensure these tags are applied.

## Usage

### Basic Example (Dev Environment)

```hcl
module "eks" {
  source = "../../modules/eks-blueprints"
  
  cluster_name    = "altanova-dev"
  cluster_version = "1.32"
  environment     = "dev"
  
  # Network
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  
  # Node groups
  node_groups = {
    general = {
      instance_types = ["t3.medium"]
      min_size       = 2
      max_size       = 4
      desired_size   = 2
      
      labels = {
        workload = "general"
      }
    }
  }
  
  # Core add-ons (enabled by default)
  enable_aws_load_balancer_controller = true  # AWS recommended approach
  enable_metrics_server               = true
  enable_cluster_autoscaler           = true
  
  tags = {
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}
```

### Production Example

```hcl
module "eks" {
  source = "../../modules/eks-blueprints"
  
  cluster_name    = "altanova-prod"
  cluster_version = "1.32"
  environment     = "prod"
  
  # Network
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  
  # Node groups - production sizing
  node_groups = {
    general = {
      instance_types = ["m5.large"]
      min_size       = 3
      max_size       = 10
      desired_size   = 3
      
      labels = {
        workload = "general"
      }
    }
    
    compute = {
      instance_types = ["c5.xlarge"]
      min_size       = 2
      max_size       = 8
      desired_size   = 2
      
      labels = {
        workload = "compute-intensive"
      }
      
      taints = [{
        key    = "workload"
        value  = "compute"
        effect = "NoSchedule"
      }]
    }
  }
  
  # Enable all add-ons for production
  enable_aws_load_balancer_controller = true  # AWS recommended (replaces NGINX)
  enable_metrics_server               = true
  enable_cluster_autoscaler           = true
  enable_aws_for_fluentbit            = true
  enable_argocd                       = true
  enable_kube_prometheus_stack        = true
  
  # Enable encryption
  enable_cluster_encryption = true
  kms_key_arn              = aws_kms_key.eks.arn
  
  tags = {
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| cluster_name | Name of the EKS cluster | string | - | yes |
| cluster_version | Kubernetes version | string | "1.32" | no |
| environment | Environment name | string | - | yes |
| vpc_id | VPC ID | string | - | yes |
| private_subnet_ids | Private subnet IDs | list(string) | - | yes |
| node_groups | Node group definitions | any | {} | no |
| enable_aws_load_balancer_controller | Enable ALB Controller (AWS recommended) | bool | true | no |
| enable_metrics_server | Enable Metrics Server | bool | true | no |
| enable_karpenter | Enable Karpenter (recommended for cost optimization) | bool | true | no |
| enable_cluster_autoscaler | Enable Cluster Autoscaler (legacy, use Karpenter instead) | bool | false | no |
| enable_gateway_api | Enable Gateway API (successor to Ingress) | bool | true | no |
| enable_aws_for_fluentbit | Enable Fluent Bit logging | bool | false | no |
| enable_argocd | Enable ArgoCD | bool | false | no |
| enable_kube_prometheus_stack | Enable Prometheus/Grafana | bool | false | no |
| enable_aws_efs_csi_driver | Enable EFS CSI Driver | bool | false | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster_id | EKS cluster ID |
| cluster_name | EKS cluster name |
| cluster_endpoint | EKS cluster endpoint |
| cluster_version | Kubernetes version |
| oidc_provider_arn | OIDC provider ARN for IRSA |
| configure_kubectl | Command to configure kubectl |

## Add-ons Included

### Core Add-ons (Always Installed)
- **CoreDNS** - DNS resolution
- **kube-proxy** - Network proxy
- **VPC CNI** - Pod networking
- **EBS CSI Driver** - EBS volume support

### Optional Add-ons
- **AWS Load Balancer Controller** ✅ **RECOMMENDED** - Native AWS ALB/NLB integration
  - Replaces deprecated NGINX Ingress
  - Supports Application Load Balancer (ALB) for HTTP/HTTPS
  - Supports Network Load Balancer (NLB) for TCP/UDP
  - Better AWS integration and cost optimization
- **Metrics Server** - Resource metrics
- **Cluster Autoscaler** - Auto-scaling nodes
- **Fluent Bit** - Log forwarding to CloudWatch
- **ArgoCD** - GitOps deployment
- **Kube Prometheus Stack** - Monitoring (Prometheus + Grafana)
- **EFS CSI Driver** - EFS volume support

## Autoscaling: Karpenter vs Cluster Autoscaler

**⚠️ IMPORTANT: Choose ONE autoscaling solution, not both!**

### Karpenter (Recommended) ✅

**Use Karpenter if:**
- You want **up to 60% cost savings** through intelligent instance selection
- You need **faster node provisioning** (seconds vs minutes)
- You want **automatic instance type optimization**
- You're building a new cluster or can migrate workloads

**Benefits:**
- Automatically selects the best instance type for your workload
- Supports Spot instances with intelligent fallback
- Provisions nodes in ~30 seconds (vs 3-5 minutes with CA)
- Consolidates underutilized nodes automatically
- No need to manage multiple node groups

**Setup:**
```hcl
enable_karpenter          = true
enable_cluster_autoscaler = false

# Minimal node group ONLY for system components (Karpenter controller itself)
node_groups = {
  system = {
    instance_types = ["t3.small"]
    min_size       = 1
    max_size       = 2
    desired_size   = 1
  }
}
```

### Cluster Autoscaler (Legacy)

**Use Cluster Autoscaler if:**
- You have existing infrastructure that's hard to migrate
- You need a proven, stable solution with years of production use
- Your organization has strict policies against newer tools

**Limitations:**
- Slower scaling (3-5 minutes)
- Requires pre-defined node groups
- Less cost-efficient
- More complex configuration for multiple instance types

### Why Gateway API?

**Evolution of Kubernetes Networking:**
```
Ingress (2015) → Gateway API (2023+) ✅ FUTURE
```

**Gateway API is the successor to Ingress:**
- ✅ More expressive and flexible
- ✅ Role-oriented design (Infrastructure vs App teams)
- ✅ Better for complex routing
- ✅ Supports TCP/UDP (not just HTTP)
- ✅ Portable across cloud providers
- ✅ Kubernetes SIG-Network official project

**AWS Load Balancer Controller supports BOTH:**
- Ingress API (legacy, still works)
- Gateway API (modern, recommended)

### Gateway API vs Ingress

| Feature | Ingress | Gateway API |
|---------|---------|-------------|
| **HTTP/HTTPS** | ✅ | ✅ |
| **TCP/UDP** | ❌ | ✅ |
| **Role separation** | ❌ | ✅ |
| **Advanced routing** | Limited | ✅ |
| **Multi-team** | ❌ | ✅ |
| **Future** | Maintenance | ✅ Active development |

### How to Use Gateway API

**Old Way (Ingress):**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
spec:
  rules:
    - host: myapp.example.com
      http:
        paths:
          - path: /
            backend:
              service:
                name: my-app
                port:
                  number: 80
```

**New Way (Gateway API):**
```yaml
# Infrastructure team creates Gateway (once)
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: production-gateway
spec:
  gatewayClassName: aws-alb
  listeners:
    - name: http
      protocol: HTTP
      port: 80

---
# App team creates HTTPRoute (per app)
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-app
spec:
  parentRefs:
    - name: production-gateway
  hostnames:
    - myapp.example.com
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: my-app
          port: 80
```

**Benefits of Gateway API:**
- ✅ Infrastructure team manages Gateway
- ✅ App teams manage HTTPRoutes
- ✅ Better separation of concerns
- ✅ More flexible routing rules
- ✅ Easier to understand and maintain

## Node Group Configuration

```hcl
node_groups = {
  group_name = {
    instance_types = ["t3.medium"]
    min_size       = 2
    max_size       = 10
    desired_size   = 2
    
    # Optional: Labels
    labels = {
      workload = "general"
    }
    
    # Optional: Taints
    taints = [{
      key    = "workload"
      value  = "special"
      effect = "NoSchedule"
    }]
    
    # Optional: Disk size
    disk_size = 50
    
    # Optional: Capacity type
    capacity_type = "ON_DEMAND"  # or "SPOT"
  }
}
```

## Security Features

- ✅ Private API endpoint (optional public)
- ✅ IRSA enabled for pod-level IAM
- ✅ Security groups configured
- ✅ CloudWatch logging enabled
- ✅ Optional KMS encryption
- ✅ Network policies support

## Post-Deployment

### Configure kubectl

```bash
aws eks update-kubeconfig --region eu-west-1 --name altanova-dev
```

### Verify cluster

```bash
kubectl get nodes
kubectl get pods -A
```

### Access ArgoCD (if enabled)

```bash
kubectl get svc -n argocd
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

### Access Grafana (if enabled)

```bash
kubectl get svc -n kube-prometheus-stack
kubectl port-forward svc/kube-prometheus-stack-grafana -n kube-prometheus-stack 3000:80
```

## Cost Optimization

### Dev Environment
- Use `t3.medium` instances
- 2-4 nodes
- Spot instances for non-critical workloads
- Disable optional add-ons

### Prod Environment
- Use `m5.large` or larger
- 3+ nodes for HA
- On-demand instances
- Enable monitoring and logging

## Examples

See `../../environments/dev-app-account/` and `../../environments/prod-app-account/` for complete examples.
