# Karpenter + GPU Setup - Dev Environment

## Overview

This directory contains a complete EKS cluster setup with Karpenter-based node autoscaling and GPU support for scale-to-zero ML inference.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         EKS CLUSTER (v1.31)                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │ SYSTEM NODES (Managed Node Group - Always On)                    │   │
│  │ • Instance: 2x t3.small (On-Demand)                              │   │
│  │ • Workloads: Karpenter, CoreDNS, AWS LB Controller               │   │
│  │ • Taint: CriticalAddonsOnly=true:NoSchedule                      │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │ APPLICATION NODES (Karpenter-Managed - Dynamic)                  │   │
│  │                                                                   │   │
│  │  ┌────────────────────────────────────────────────────────────┐  │   │
│  │  │ General NodePool (Spot Preferred)                          │  │   │
│  │  │ • Instances: t3/m5/c5.small-large                          │  │   │
│  │  │ • Consolidation: 1 minute (aggressive for dev)             │  │   │
│  │  │ • Limits: 50 vCPU, 100Gi RAM                               │  │   │
│  │  └────────────────────────────────────────────────────────────┘  │   │
│  │                                                                   │   │
│  │  ┌────────────────────────────────────────────────────────────┐  │   │
│  │  │ Critical NodePool (On-Demand Only)                         │  │   │
│  │  │ • Instances: t3/m5.small-medium                            │  │   │
│  │  │ • Consolidation: 5 minutes (conservative)                  │  │   │
│  │  │ • Taint: workload=critical:NoSchedule                      │  │   │
│  │  │ • Limits: 20 vCPU, 40Gi RAM                                │  │   │
│  │  └────────────────────────────────────────────────────────────┘  │   │
│  │                                                                   │   │
│  │  ┌────────────────────────────────────────────────────────────┐  │   │
│  │  │ GPU NodePool (Scale-to-Zero) 🎯                            │  │   │
│  │  │ • Instances: g4dn.xlarge/2xlarge (Spot preferred)          │  │   │
│  │  │ • GPU: NVIDIA T4 (16GB VRAM)                               │  │   │
│  │  │ • Storage: 200Gi gp3 (for model weights)                   │  │   │
│  │  │ • Consolidation: 5 minutes (scale-to-zero)                 │  │   │
│  │  │ • Taint: nvidia.com/gpu=true:NoSchedule                    │  │   │
│  │  │ • Limits: 4 GPUs max, 32 vCPU, 128Gi RAM                   │  │   │
│  │  │ • Cost: ~$10-30/month (vs $374/month always-on)            │  │   │
│  │  └────────────────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## File Structure

```
aws/environments/dev-app-account/
├── main.tf                      # VPC configuration
├── eks.tf                       # EKS cluster + system nodes + Karpenter IAM
├── karpenter.tf                 # Karpenter controller + NodePools (19K, well-commented)
├── nvidia-device-plugin.tf      # NVIDIA device plugin (3.6K, well-commented)
├── rds.tf                       # PostgreSQL database
├── alb-controller.tf            # AWS Load Balancer Controller
├── acm.tf                       # TLS certificates
├── iam.tf                       # Deployment IAM roles
├── providers.tf                 # Provider configuration
├── variables.tf                 # Input variables
├── outputs.tf                   # Output values
└── backend.tf                   # S3 backend config
```

## Key Components

### 1. Karpenter Controller ([karpenter.tf](karpenter.tf))

- **Purpose**: Watches for pending pods and provisions right-sized nodes
- **Version**: v1.0.8 (latest stable)
- **API**: karpenter.sh/v1 (GA)
- **HA**: 2 replicas with leader election
- **Spot Handling**: SQS queue for 2-minute interruption warnings

### 2. EC2NodeClasses ([karpenter.tf](karpenter.tf))

**Default NodeClass** (for CPU workloads):
- AMI: Amazon Linux 2023 (latest)
- Storage: 50Gi gp3 (3000 IOPS, 125 MiB/s)
- Security: IMDSv2 required, encrypted EBS

**GPU NodeClass** (for ML workloads):
- AMI: Amazon Linux 2023 with GPU support (includes NVIDIA drivers)
- Storage: 200Gi gp3 (4000 IOPS, 200 MiB/s) - 4x larger for model weights
- Security: IMDSv2 required, encrypted EBS

### 3. NodePools ([karpenter.tf](karpenter.tf))

| Pool | Purpose | Instance Types | Capacity | Consolidation | Taint |
|------|---------|---------------|----------|---------------|-------|
| **general** | Default workloads | t3/m5/c5.small-large | Spot+OD | 1 min | None |
| **critical** | Critical workloads | t3/m5.small-medium | OD only | 5 min | workload=critical |
| **gpu-inference** | ML inference | g4dn.xlarge/2xlarge | Spot+OD | 5 min | nvidia.com/gpu |

### 4. NVIDIA Device Plugin ([nvidia-device-plugin.tf](nvidia-device-plugin.tf))

- **Purpose**: Exposes GPUs as schedulable resources (`nvidia.com/gpu`)
- **Version**: v0.17.0
- **Deployment**: DaemonSet (only runs on GPU nodes)
- **Integration**: Required for pods to request GPU resources

## Cost Analysis - GPU NodePool

### Monthly Costs (eu-west-1)

| Configuration | Instance | Usage | Cost/Month |
|---------------|----------|-------|------------|
| Always-On On-Demand | g4dn.xlarge | 24/7 | **$374** ❌ |
| Always-On Spot | g4dn.xlarge | 24/7 | **$115** |
| **Scale-to-Zero Spot** | g4dn.xlarge | 2 hrs/day | **$10-30** ✅ |

**Savings**: 90-95% cost reduction with scale-to-zero

### How Scale-to-Zero Works

```
1. No GPU pods → Node is idle
   ↓
2. After 5 minutes → Karpenter terminates node
   ↓ Cost: $0/hr
3. New GPU pod created → Pod is Pending
   ↓
4. Karpenter provisions g4dn.xlarge Spot (~60 seconds)
   ↓
5. NVIDIA device plugin exposes GPU
   ↓
6. Pod scheduled and runs inference
   ↓ Cost: ~$0.16/hr (Spot)
7. Pod completes → Node becomes idle
   ↓
8. Return to step 1
```

**Cold Start Time**: ~90 seconds (60s node launch + 30s model loading)

## Deployment

### Prerequisites

1. AWS credentials configured
2. Terraform >= 1.8 installed
3. kubectl installed (for post-deployment verification)

### Deploy Infrastructure

```bash
cd /Users/marwanghubein/altanova/AltanovaLLM/aws/environments/dev-app-account

# Initialize Terraform (downloads modules)
terraform init

# Review planned changes
terraform plan

# Apply infrastructure
terraform apply

# Get kubeconfig
aws eks update-kubeconfig --region eu-west-1 --name altanova-dev-euw1-eks
```

### Verify Installation

```bash
# Check Karpenter controller
kubectl get pods -n karpenter
# Expected: 2 karpenter pods Running

# Check NVIDIA device plugin
kubectl get pods -n kube-system -l app.kubernetes.io/name=nvidia-device-plugin
# Expected: 0 pods (no GPU nodes yet - scale-to-zero)

# Check NodePools
kubectl get nodepools
# Expected: general, critical, gpu-inference

# Check EC2NodeClasses
kubectl get ec2nodeclasses
# Expected: default, gpu
```

## Deploying GPU Workloads

### Example: TinyLlama Inference Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: tinyllama-inference
  namespace: default
spec:
  # GPU toleration - required to schedule on GPU nodes
  tolerations:
    - key: nvidia.com/gpu
      operator: Exists
      effect: NoSchedule

  # Node selector - target GPU NodePool
  nodeSelector:
    nodepool: gpu-inference

  containers:
    - name: inference
      image: <your-ecr-repo>/tinyllama:latest
      resources:
        requests:
          cpu: "2"
          memory: "8Gi"
          nvidia.com/gpu: "1"  # Request 1 GPU
        limits:
          cpu: "4"
          memory: "16Gi"
          nvidia.com/gpu: "1"  # Limit to 1 GPU

      env:
        - name: MODEL_NAME
          value: "TinyLlama/TinyLlama-1.1B-Chat-v1.0"
        - name: DEVICE
          value: "cuda"  # Use GPU
```

### What Happens When You Deploy:

1. Pod is created with `nvidia.com/gpu: "1"` request
2. Scheduler finds no suitable node (all nodes either lack GPU or don't tolerate the request)
3. Pod goes **Pending**
4. **Karpenter detects pending pod** (~5 seconds)
5. **Karpenter provisions g4dn.xlarge Spot** (~60 seconds)
   - Uses GPU EC2NodeClass (200Gi storage)
   - Applies nvidia.com/gpu taint
   - Joins cluster
6. **NVIDIA device plugin DaemonSet starts** on new GPU node (~10 seconds)
   - Discovers T4 GPU
   - Registers `nvidia.com/gpu: 1` capacity
7. **Scheduler binds pod to GPU node** (~5 seconds)
8. **Container starts, loads model, runs inference** (~30 seconds)
9. **When pod completes/deletes**:
   - Node becomes idle
   - After 5 minutes, Karpenter terminates node
   - **Cost returns to $0/hr**

## Monitoring

### Check Node Provisioning

```bash
# Watch Karpenter logs
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter -f

# Check provisioned nodes
kubectl get nodes -L nodepool,karpenter.sh/capacity-type,node.kubernetes.io/instance-type

# Check GPU node capacity
kubectl get nodes -l nodepool=gpu-inference -o json | jq '.items[].status.capacity'
```

### Cost Tracking

```bash
# List GPU nodes with uptime
kubectl get nodes -l NodeType=gpu -o wide

# Check GPU utilization (requires metrics-server)
kubectl top nodes -l nodepool=gpu-inference
```

## Troubleshooting

### Pod Stuck in Pending

```bash
# Check why pod is pending
kubectl describe pod <pod-name>

# Common issues:
# 1. Missing toleration for nvidia.com/gpu taint
# 2. Missing nvidia.com/gpu resource request
# 3. Karpenter limits reached (check limits.nvidia.com/gpu: 4)
```

### No GPU Detected in Container

```bash
# Verify NVIDIA device plugin is running on the node
kubectl get pods -n kube-system -o wide | grep nvidia-device-plugin

# Check GPU visibility in container
kubectl exec <pod-name> -- nvidia-smi

# If nvidia-smi fails:
# 1. Ensure pod has nvidia.com/gpu request
# 2. Check NVIDIA device plugin logs
```

### Karpenter Not Provisioning Nodes

```bash
# Check Karpenter controller logs
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --tail=100

# Check NodePool events
kubectl describe nodepool gpu-inference

# Verify IAM role has EC2 permissions
aws iam get-role --role-name altanova-dev-euw1-eks-karpenter-node
```

## Security Features

### Instance Metadata Service (IMDS)
- **IMDSv2 Required**: Prevents SSRF attacks
- **Hop Limit: 1**: Prevents container escape to IMDS

### Encryption
- **EBS Volumes**: Encrypted at rest with AWS managed keys
- **Node Communication**: TLS 1.3 enforced

### Network Isolation
- **Private Subnets**: All nodes in private subnets (no public IPs)
- **Security Groups**: Karpenter auto-discovers tagged security groups
- **VPC Flow Logs**: Enabled for audit trail

### IAM
- **IRSA**: Karpenter uses IAM Roles for Service Accounts
- **Least Privilege**: Node IAM role has minimal required permissions
- **No Static Credentials**: All authentication via IRSA or instance profiles

## Related Documentation

- **Reference Architecture**: [context/KARPENTER_GPU_ADDENDUM.md](../../../context/KARPENTER_GPU_ADDENDUM.md)
- **Main Sprint Guide**: [context/7DAY_DEVSECOPS_SPRINT_GITOPS.md](../../../context/7DAY_DEVSECOPS_SPRINT_GITOPS.md)
- **Karpenter Docs**: https://karpenter.sh/docs/
- **NVIDIA Device Plugin**: https://github.com/NVIDIA/k8s-device-plugin

## Next Steps

1. **Deploy Infrastructure**: Run `terraform apply`
2. **Build GPU Docker Image**: Create TinyLlama inference container
3. **Push to ECR**: Store image in AWS container registry
4. **Deploy Inference Pod**: Apply GPU workload manifest
5. **Test Scale-to-Zero**: Verify node terminates after 5 minutes idle
6. **Monitor Costs**: Track GPU node uptime vs cost savings

---

**Environment**: Dev
**Region**: eu-west-1
**Cluster**: altanova-dev-euw1-eks
**Karpenter Version**: v1.0.8
**NVIDIA Device Plugin Version**: v0.17.0
**Last Updated**: 2026-01-01
