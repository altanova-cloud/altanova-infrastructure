# Karpenter Configuration for AltaNova

This directory contains Karpenter configuration for intelligent, cost-optimized node provisioning.

## 🚀 What is Karpenter?

Karpenter is a Kubernetes node autoscaler that provisions right-sized compute resources in response to changing application load. It's designed to improve cost efficiency and application availability compared to traditional Cluster Autoscaler.

### **Benefits over Cluster Autoscaler:**
- ✅ **60% cost savings** on average
- ✅ **Better Spot instance utilization** (70-80% vs manual management)
- ✅ **Faster scaling** (~30 seconds vs 2-3 minutes)
- ✅ **Right-sizing** - provisions exact instance types needed
- ✅ **Automatic consolidation** - terminates underutilized nodes
- ✅ **No ASG management** required

## 📋 Configuration Files

### `karpenter-nodepool.yaml`
Defines how Karpenter should provision nodes:
- **Instance types**: t3.medium, t3a.medium (cost-optimized)
- **Capacity type**: SPOT instances with on-demand fallback
- **Consolidation**: Automatic node replacement for better bin packing
- **Limits**: Max 100 vCPUs, 200GB memory

## 🔧 Deployment

### 1. **Deploy EKS Cluster with Karpenter**
```bash
cd /Users/marwanghubein/tech-repo/landing-zones/aws/environments/dev-app-account
terraform init
terraform plan
terraform apply
```

Karpenter will be automatically installed as part of the EKS deployment.

### 2. **Apply NodePool Configuration**
After the cluster is created, apply the Karpenter NodePool:

```bash
# Configure kubectl
aws eks update-kubeconfig --region eu-west-1 --name altanova-dev

# Verify Karpenter is running
kubectl get pods -n karpenter

# Apply NodePool configuration
kubectl apply -f karpenter-nodepool.yaml

# Verify NodePool is created
kubectl get nodepools -n karpenter
kubectl get ec2nodeclasses -n karpenter
```

### 3. **Tag Subnets and Security Groups**
Karpenter uses tags to discover resources. Ensure your subnets and security groups have:

```hcl
tags = {
  "karpenter.sh/discovery" = "altanova-dev"
}
```

## 📊 Monitoring Karpenter

### Check Karpenter logs:
```bash
kubectl logs -f -n karpenter -l app.kubernetes.io/name=karpenter
```

### View provisioned nodes:
```bash
kubectl get nodes -l karpenter.sh/provisioner-name=general-purpose
```

### Check NodePool status:
```bash
kubectl describe nodepool general-purpose -n karpenter
```

## 💡 How Karpenter Works

1. **Pod Scheduling**: When pods can't be scheduled (pending state)
2. **Instance Selection**: Karpenter analyzes pod requirements and selects optimal instance type
3. **Provisioning**: Directly provisions EC2 instance (no ASG needed)
4. **Consolidation**: Continuously monitors for underutilized nodes and consolidates workloads

## 🎯 Cost Optimization Features

### **Spot Instance Management**
- Automatically uses Spot instances for up to 70% savings
- Falls back to on-demand if Spot unavailable
- Handles Spot interruptions gracefully

### **Bin Packing**
- Maximizes pod density on nodes
- Reduces number of nodes needed
- Minimizes waste

### **Consolidation**
- Identifies underutilized nodes
- Moves pods to fewer, better-packed nodes
- Terminates empty nodes automatically

## 🔐 Security

- **IMDSv2 required**: Metadata service v2 enforced
- **Encrypted EBS volumes**: All node volumes encrypted
- **Private subnets**: Nodes deployed in private subnets only
- **IAM roles**: Least-privilege IAM roles for nodes

## 📝 Customization

### Add more instance types:
Edit `karpenter-nodepool.yaml` and add to `node.kubernetes.io/instance-type`:
```yaml
values:
  - t3.medium
  - t3a.medium
  - t3.large    # Add larger instances
```

### Adjust limits:
```yaml
limits:
  cpu: "200"      # Increase max vCPUs
  memory: 400Gi   # Increase max memory
```

### Change consolidation behavior:
```yaml
disruption:
  consolidateAfter: 60s  # Wait longer before consolidating
```

## 🚨 Troubleshooting

### Nodes not provisioning?
1. Check Karpenter logs: `kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter`
2. Verify subnet/SG tags: `karpenter.sh/discovery = altanova-dev`
3. Check IAM permissions for Karpenter controller

### Pods still pending?
1. Check pod resource requests
2. Verify NodePool limits aren't exceeded
3. Check if instance types are available in your region

## 📚 Resources

- [Karpenter Documentation](https://karpenter.sh/)
- [AWS Karpenter Best Practices](https://aws.github.io/aws-eks-best-practices/karpenter/)
- [Karpenter vs Cluster Autoscaler](https://karpenter.sh/docs/concepts/scheduling/)
