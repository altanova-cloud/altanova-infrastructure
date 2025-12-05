# Prod App Account Infrastructure

This directory contains the production VPC infrastructure configuration for the AltaNova platform.

## 🏗️ Architecture

```
Production Account (624755517249)
├── VPC: 10.1.0.0/16 (eu-west-1)
│   ├── Public Subnets (3 AZs)
│   │   ├── eu-west-1a: 10.1.1.0/24 (ALB, NAT Gateway)
│   │   ├── eu-west-1b: 10.1.2.0/24 (ALB, NAT Gateway)
│   │   └── eu-west-1c: 10.1.3.0/24 (ALB, NAT Gateway)
│   │
│   ├── Private Subnets (3 AZs)
│   │   ├── eu-west-1a: 10.1.10.0/24 (EKS Nodes, Pods)
│   │   ├── eu-west-1b: 10.1.11.0/24 (EKS Nodes, Pods)
│   │   └── eu-west-1c: 10.1.12.0/24 (EKS Nodes, Pods)
│   │
│   ├── Database Subnets (3 AZs)
│   │   ├── eu-west-1a: 10.1.20.0/24 (RDS, ElastiCache)
│   │   ├── eu-west-1b: 10.1.21.0/24 (RDS, ElastiCache)
│   │   └── eu-west-1c: 10.1.22.0/24 (RDS, ElastiCache)
│   │
│   ├── NAT Gateways: 3 (one per AZ for HA)
│   ├── Internet Gateway: Implicit
│   └── VPC Flow Logs: Enabled to CloudWatch
│
└── Deployment Role: ProdDeployRole (for CI/CD)
```

## 🚀 Deployment

### Prerequisites
1. AWS credentials configured for prod account (624755517249)
2. Access to shared account state backend
3. Terraform >= 1.8
4. Approval from infrastructure team (2 reviewers required)

### Deploy Infrastructure

```bash
# Navigate to prod environment
cd aws/environments/prod-app-account

# Initialize Terraform
terraform init -backend-config=backend.conf

# Validate configuration
terraform validate

# Review plan (careful - this is production!)
terraform plan -out=tfplan.prod

# Show plan details
terraform show tfplan.prod
```

### Review and Apply (With Approval)

**IMPORTANT:** Production deployments require 2-person approval

```bash
# After approval from team, apply infrastructure
terraform apply tfplan.prod
```

## ✅ What's Deployed

- ✅ VPC (10.1.0.0/16)
- ✅ Public Subnets (3 AZs)
- ✅ Private Subnets (3 AZs)
- ✅ Database Subnets (3 AZs)
- ✅ NAT Gateways (3 - one per AZ for HA)
- ✅ VPC Flow Logs (CloudWatch)

## 🎯 Production Features

### High Availability
- ✅ **3 Availability Zones** for fault tolerance
- ✅ **NAT per AZ** - no single point of failure
- ✅ **Multi-AZ subnets** for all tiers
- ✅ **Subnet redundancy** across all 3 AZs

### Network Design
- ✅ **3-tier architecture**: Public, Private, Database
- ✅ **Isolated subnets** for security
- ✅ **VPC Flow Logs** for compliance and monitoring
- ✅ **Private database** tier with RDS/ElastiCache support

### Security
- ✅ **Private subnets** for EKS nodes
- ✅ **VPC Flow Logs** enabled (30-day retention)
- ✅ **CloudWatch logging** for audit trail
- ✅ **Cross-account** role assumption for state access

## 💰 Cost Considerations

### VPC Infrastructure Costs

| Component | Quantity | Monthly Cost |
|-----------|----------|--------------|
| NAT Gateway | 3 (one per AZ) | ~$96 |
| VPC Flow Logs | Data transfer | ~$5 |
| **Total VPC Cost** | | **~$100/month** |

**Note:** Costs for EKS cluster, RDS, and application workloads will be added in subsequent phases.

## Accessing Outputs

After deployment:

```bash
# View all outputs
terraform output -json

# Access specific values
terraform output vpc_id
terraform output private_subnet_ids
terraform output database_subnet_ids
terraform output deploy_role_arn
```

## Key Outputs

| Output | Value | Usage |
|--------|-------|-------|
| `vpc_id` | VPC ID | EKS cluster configuration |
| `private_subnet_ids` | Subnet IDs (3) | EKS node groups |
| `public_subnet_ids` | Subnet IDs (3) | Application load balancer |
| `database_subnet_ids` | Subnet IDs (3) | RDS Multi-AZ, ElastiCache |
| `nat_gateway_ids` | NAT GW IDs (3) | Network monitoring |
| `availability_zones` | AZs (3) | Deployment planning |
| `deploy_role_arn` | IAM Role ARN | CI/CD pipeline |

## Files

| File | Purpose |
|------|---------|
| `vpc.tf` | VPC module configuration (3 AZs, multi-NAT) |
| `main.tf` | Deployment role setup |
| `providers.tf` | AWS provider configuration |
| `backend.tf` | S3 backend setup |
| `backend.conf` | Backend configuration (partial) |
| `outputs.tf` | Terraform outputs |

## Next Steps

1. ✅ Deploy VPC (this phase)
2. ⏳ Deploy EKS cluster with eks-blueprints
3. ⏳ Deploy RDS database with Multi-AZ failover
4. ⏳ Deploy Karpenter for intelligent auto-scaling
5. ⏳ Deploy production microservices

## 🆘 Troubleshooting

### Terraform Init Fails

```
Error: Failed to get existing workspaces
```

**Solution:** Verify backend.conf:
```bash
cat backend.conf
# Should show:
# - bucket = altanova-tf-state-eu-central-1
# - key = prod-app-account/terraform.tfstate
# - assume_role with TerraformStateAccessRole
```

### NAT Gateway Costs

If concerned about NAT costs (~$96/month):
- VPC Endpoints can reduce data transfer costs
- CloudFront can cache content
- Consider multi-NAT only if truly necessary for prod

### State Lock Issues

```
Error: Error acquiring the state lock
```

**Solution:** Release stuck lock (use with caution in prod!):
```bash
terraform force-unlock <LOCK_ID>
```

## Documentation

- [ARCHITECTURE.md](../../docs/ARCHITECTURE.md) - Multi-account architecture
- [INFRASTRUCTURE_BUILD_PLAN.md](../../docs/INFRASTRUCTURE_BUILD_PLAN.md) - Implementation roadmap
- [PIPELINE.md](../../docs/PIPELINE.md) - CI/CD pipeline documentation
- [VPC Module](../../modules/vpc) - VPC module documentation
