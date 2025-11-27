# Production Environment - AltaNova EKS Cluster

This directory contains the production infrastructure configuration for the AltaNova platform.

## 🏗️ Architecture

```
Production Account (10.1.0.0/16)
├── VPC (3 Availability Zones for HA)
│   ├── Public Subnets (10.1.1-3.0/24)
│   ├── Private Subnets (10.1.10-12.0/24) - EKS nodes
│   └── Database Subnets (10.1.20-22.0/24) - RDS, ElastiCache
│
└── EKS Cluster: altanova-prod
    ├── Version: 1.32
    ├── Karpenter: Enabled (intelligent autoscaling)
    ├── Node Groups: SPOT instances (t3.medium)
    ├── Min/Max Nodes: 3-10
    └── Add-ons:
        ├── AWS Load Balancer Controller
        ├── Metrics Server
        ├── Karpenter (autoscaling)
        ├── Gateway API
        ├── Fluent Bit (logging)
        └── Prometheus Stack (monitoring)
```

## 🚀 Deployment

### Prerequisites
1. Shared account infrastructure deployed (OIDC, Terraform state)
2. Production deployment IAM role configured
3. Backend configuration file (`backend.conf`)

### Deploy Infrastructure

```bash
# Navigate to prod environment
cd /Users/marwanghubein/tech-repo/landing-zones/aws/environments/prod-app-account

# Initialize Terraform
terraform init -backend-config=backend.conf

# Review plan
terraform plan

# Apply (requires approval)
terraform apply
```

### Configure kubectl

```bash
aws eks update-kubeconfig --region eu-west-1 --name altanova-prod
```

### Deploy Karpenter NodePools

After cluster creation:

```bash
# Verify Karpenter is running
kubectl get pods -n karpenter

# Apply NodePool configurations
kubectl apply -f karpenter-nodepool.yaml

# Verify NodePools
kubectl get nodepools -n karpenter
kubectl get ec2nodeclasses -n karpenter
```

## 🎯 Production Features

### High Availability
- ✅ **3 Availability Zones** for fault tolerance
- ✅ **Multi-AZ subnets** for all tiers
- ✅ **Karpenter** distributes nodes across AZs
- ✅ **Pod Disruption Budgets** recommended for critical apps

### Cost Optimization
- ✅ **Karpenter** for intelligent autoscaling (60% savings)
- ✅ **SPOT instances** for non-critical workloads (70% cheaper)
- ✅ **On-demand pool** for critical workloads
- ✅ **Automatic consolidation** reduces waste
- ✅ **Single NAT gateway** (can enable more if needed)

### Security
- ✅ **Private subnets** for EKS nodes
- ✅ **IMDSv2 required** on all nodes
- ✅ **Encrypted EBS volumes**
- ✅ **VPC Flow Logs** enabled (30-day retention)
- ✅ **Full CloudWatch logging** for audit trail

### Monitoring & Observability
- ✅ **Prometheus Stack** for metrics
- ✅ **Fluent Bit** for centralized logging
- ✅ **CloudWatch integration**
- ✅ **Metrics Server** for HPA

## 📊 Karpenter Configuration

### Two NodePools:

#### 1. **general-purpose** (Default)
- **Capacity**: SPOT with on-demand fallback
- **Instance Types**: t3.medium, t3a.medium
- **Limits**: 200 vCPUs, 400GB memory
- **Consolidation**: After 60s of underutilization
- **Use Case**: Most workloads

#### 2. **critical-workloads**
- **Capacity**: On-demand ONLY
- **Instance Types**: t3.medium, t3a.medium
- **Limits**: 50 vCPUs, 100GB memory
- **Taint**: `workload=critical:NoSchedule`
- **Use Case**: Databases, stateful apps, critical services

### Using Critical NodePool

To schedule pods on critical (on-demand) nodes:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: critical-app
spec:
  tolerations:
    - key: workload
      operator: Equal
      value: critical
      effect: NoSchedule
  nodeSelector:
    workload: critical
  containers:
    - name: app
      image: your-image
```

## 🔍 Monitoring

### Check Cluster Health
```bash
kubectl get nodes
kubectl get pods -A
kubectl top nodes
```

### Monitor Karpenter
```bash
# Karpenter logs
kubectl logs -f -n karpenter -l app.kubernetes.io/name=karpenter

# View provisioned nodes
kubectl get nodes -l karpenter.sh/provisioner-name

# NodePool status
kubectl describe nodepool general-purpose -n karpenter
kubectl describe nodepool critical-workloads -n karpenter
```

### Monitor Costs
```bash
# View Spot instance usage
kubectl get nodes -l karpenter.sh/capacity-type=spot

# View on-demand instance usage
kubectl get nodes -l karpenter.sh/capacity-type=on-demand
```

## 🚨 Production Best Practices

### 1. **Pod Disruption Budgets**
Always create PDBs for critical applications:

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: my-app-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: my-app
```

### 2. **Resource Requests/Limits**
Always set resource requests for proper scheduling:

```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

### 3. **Health Checks**
Configure liveness and readiness probes:

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
```

### 4. **Spot Instance Handling**
Karpenter handles Spot interruptions automatically, but ensure:
- Multiple replicas for critical services
- Pod Disruption Budgets configured
- Graceful shutdown handlers in apps

## 📈 Scaling

### Horizontal Pod Autoscaling (HPA)
```bash
kubectl autoscale deployment my-app --cpu-percent=70 --min=3 --max=10
```

### Karpenter Auto-Scaling
Karpenter automatically provisions nodes based on pending pods. No manual configuration needed!

## 🔐 Security Checklist

- [ ] VPC Flow Logs enabled
- [ ] CloudWatch logging enabled
- [ ] IMDSv2 enforced on nodes
- [ ] EBS encryption enabled
- [ ] Security groups properly configured
- [ ] IAM roles follow least privilege
- [ ] Network policies configured
- [ ] Pod Security Standards enforced

## 💰 Cost Monitoring

### Expected Monthly Costs (Estimate)

**With Karpenter + SPOT:**
- 5x t3.medium SPOT nodes: ~$45/month
- NAT Gateway: ~$32/month
- EKS control plane: $73/month
- **Total: ~$150/month**

**Without Karpenter (on-demand):**
- 5x t3.medium on-demand: ~$150/month
- NAT Gateway: ~$32/month
- EKS control plane: $73/month
- **Total: ~$255/month**

**Savings: ~$105/month (41%)**

## 📚 Additional Resources

- [Karpenter Documentation](https://karpenter.sh/)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [Prometheus Operator](https://prometheus-operator.dev/)

## 🆘 Troubleshooting

See [KARPENTER.md](../dev-app-account/KARPENTER.md) for detailed Karpenter troubleshooting guide.

### Common Issues

**Pods not scheduling?**
- Check Karpenter logs
- Verify subnet/SG tags
- Check NodePool limits

**High costs?**
- Review Spot vs on-demand ratio
- Check for underutilized nodes
- Verify consolidation is working

**Spot interruptions?**
- Check Pod Disruption Budgets
- Increase replica counts
- Use critical NodePool for sensitive workloads
