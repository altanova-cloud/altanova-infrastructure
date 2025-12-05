# Dev App Account Infrastructure

This directory contains the Terraform configuration for the **Dev** environment VPC infrastructure.

## What's Deployed

- ✅ VPC (10.0.0.0/16)
- ✅ Public Subnets (2 AZs)
- ✅ Private Subnets (2 AZs)
- ✅ Database Subnets (2 AZs)
- ✅ NAT Gateway (1 for cost optimization)
- ✅ VPC Flow Logs (CloudWatch)

## Architecture

```
Dev Account (975050047325)
├── VPC: 10.0.0.0/16 (eu-west-1)
│   ├── Public Subnets
│   │   ├── eu-west-1a: 10.0.1.0/24 (ALB, NAT Gateway)
│   │   └── eu-west-1b: 10.0.2.0/24 (ALB)
│   │
│   ├── Private Subnets
│   │   ├── eu-west-1a: 10.0.10.0/24 (EKS Nodes, Pods)
│   │   └── eu-west-1b: 10.0.11.0/24 (EKS Nodes, Pods)
│   │
│   ├── Database Subnets
│   │   ├── eu-west-1a: 10.0.20.0/24 (RDS, ElastiCache)
│   │   └── eu-west-1b: 10.0.21.0/24 (RDS, ElastiCache)
│   │
│   ├── NAT Gateway: 1 (cost-optimized)
│   ├── Internet Gateway: Implicit
│   └── VPC Flow Logs: Enabled to CloudWatch
│
└── Deployment Role: DevDeployRole (for CI/CD)
```

## Prerequisites

1. **AWS Credentials** configured for dev account (975050047325)
2. **Terraform** >= 1.8
3. Access to shared account state backend

## Cost Optimization

**Dev environment is cost-optimized:**
- ✅ Single NAT Gateway (~$32/month)
- ✅ 2 Availability Zones (vs 3 in prod)
- ✅ Minimal VPC Flow Logs retention
- ✅ Suitable for development/testing

**Estimated monthly VPC cost:** ~$40-50 (NAT GW + data transfer)

## Deployment

### Initialize Terraform

```bash
cd aws/environments/dev-app-account

# Initialize with backend configuration
terraform init -backend-config=backend.conf

# Validate configuration
terraform validate

# Plan deployment
terraform plan -out=tfplan.dev
```

### Review and Apply

```bash
# Review the plan
terraform show tfplan.dev

# Apply infrastructure
terraform apply tfplan.dev
```

**Deployment time:** ~5-10 minutes

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
| `private_subnet_ids` | Subnet IDs | EKS node groups |
| `public_subnet_ids` | Subnet IDs | Application load balancer |
| `database_subnet_ids` | Subnet IDs | RDS, ElastiCache |
| `nat_gateway_ids` | NAT GW IDs | Network monitoring |
| `deploy_role_arn` | IAM Role ARN | CI/CD pipeline |

## Next Steps

1. ✅ Deploy VPC (this phase)
2. ⏳ Deploy EKS cluster with eks-blueprints
3. ⏳ Deploy RDS database
4. ⏳ Deploy Karpenter for auto-scaling
5. ⏳ Deploy microservices

## Files

| File | Purpose |
|------|---------|
| `vpc.tf` | VPC module configuration |
| `main.tf` | Deployment role setup |
| `providers.tf` | AWS provider configuration |
| `backend.tf` | S3 backend setup |
| `backend.conf` | Backend configuration (partial) |
| `outputs.tf` | Terraform outputs |

## Troubleshooting

### Terraform Init Fails

```
Error: Failed to get existing workspaces
```

**Solution:** Verify backend.conf is correct:
```bash
cat backend.conf
# Should show:
# - bucket = altanova-tf-state-eu-central-1
# - key = dev-app-account/terraform.tfstate
# - assume_role with TerraformStateAccessRole
```

### State Lock Issues

```
Error: Error acquiring the state lock
```

**Solution:** Release stuck lock (if needed):
```bash
terraform force-unlock <LOCK_ID>
```

## Documentation

- [ARCHITECTURE.md](../../docs/ARCHITECTURE.md) - Multi-account architecture
- [INFRASTRUCTURE_BUILD_PLAN.md](../../docs/INFRASTRUCTURE_BUILD_PLAN.md) - Implementation roadmap
- [VPC Module](../../modules/vpc) - VPC module documentation
