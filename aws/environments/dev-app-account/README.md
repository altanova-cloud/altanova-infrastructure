# Dev Environment - Infrastructure

This directory contains the Terraform configuration for the **Dev** environment infrastructure.

## What's Deployed

- ✅ VPC (172.16.0.0/16)
- ✅ EKS Cluster v1.32
- ✅ AWS Load Balancer Controller
- ✅ Gateway API support
- ✅ Cluster Autoscaler
- ✅ Metrics Server

## Architecture

```
Dev Account (975050047325)
├── VPC: 172.16.0.0/16
│   ├── Public Subnets
│   │   ├── eu-west-1a: 172.16.0.0/24
│   │   └── eu-west-1b: 172.16.1.0/24
│   │
│   ├── Private Subnets
│   │   ├── eu-west-1a: 172.16.2.0/24
│   │   └── eu-west-1b: 172.16.3.0/24
│   │
│   └── NAT Gateway: 1 (cost-optimized)
│
└── EKS Cluster: altanova-dev
    ├── Version: 1.32
    ├── Node Group: general (t3.medium, 2-4 nodes)
    └── Add-ons:
        ├── AWS Load Balancer Controller
        ├── Gateway API
        ├── Cluster Autoscaler
        └── Metrics Server
```

## Prerequisites

1. **AWS Credentials** configured for Dev account
2. **Terraform** >= 1.0
3. **aws-vault** (recommended) or AWS CLI configured

## Deployment

### Step 1: Initialize Terraform

```bash
cd /Users/marwanghubein/tech-repo/landing-zones/aws/environments/dev-app-account

# Initialize with backend configuration
terraform init -backend-config=backend.conf
```

### Step 2: Plan

```bash
terraform plan
```

### Step 3: Apply

```bash
terraform apply
```

**Deployment time:** ~15-20 minutes

## Post-Deployment

### Configure kubectl

```bash
aws eks update-kubeconfig --region eu-west-1 --name altanova-dev
```

### Verify Cluster

```bash
# Check nodes
kubectl get nodes

# Check system pods
kubectl get pods -A

# Check Gateway API CRDs
kubectl get crd | grep gateway
```

### Test Gateway API

```bash
# Create a test Gateway
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: dev-gateway
spec:
  gatewayClassName: aws-alb
  listeners:
    - name: http
      protocol: HTTP
      port: 80
EOF

# Check Gateway status
kubectl get gateway dev-gateway
```

## Cost Optimization

**Dev environment is cost-optimized:**
- ✅ Single NAT Gateway (~$32/month)
- ✅ t3.medium instances (2-4 nodes)
- ✅ Shorter log retention (7 days)
- ✅ Optional add-ons disabled

**Estimated monthly cost:** ~$150-200

## Cleanup

```bash
# Destroy all resources
terraform destroy
```

## Files

| File | Purpose |
|------|---------|
| `vpc.tf` | VPC configuration |
| `eks.tf` | EKS cluster configuration |
| `providers.tf` | Provider configuration |
| `backend.conf` | Remote state configuration |
| `outputs.tf` | Output values |

## Next Steps

1. ✅ Deploy infrastructure
2. ⏳ Deploy your microservices
3. ⏳ Enable ArgoCD for GitOps
4. ⏳ Enable monitoring (Prometheus/Grafana)
5. ⏳ Enable logging (Fluent Bit)

## Troubleshooting

### Issue: Cannot assume role

**Solution:** Ensure you're authenticated to the Dev account:
```bash
aws-vault exec dev-account -- terraform plan
```

### Issue: VPC already exists

**Solution:** Import existing VPC or change CIDR block in `vpc.tf`

### Issue: EKS cluster creation fails

**Solution:** Check IAM permissions and VPC configuration

## Support

For issues, check:
- [EKS Blueprints Documentation](https://aws-ia.github.io/terraform-aws-eks-blueprints/)
- [Gateway API Documentation](https://gateway-api.sigs.k8s.io/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
