# Infrastructure Build Plan
## Building EKS Infrastructure in landing-zones Repo

---

## 📁 Repository Structure

```
landing-zones/                          ← MAIN REPO (this one)
├── aws/
│   ├── modules/
│   │   ├── bootstrap/                  ✅ Already exists
│   │   ├── deployment-role/            ✅ Already exists
│   │   ├── vpc/                        ✅ Just created
│   │   └── eks-blueprints/             ⏳ Next to create
│   │
│   └── environments/
│       ├── shared-account/             ✅ Already configured
│       ├── dev-app-account/            ⏳ Will add VPC + EKS
│       └── prod-app-account/           ⏳ Will add VPC + EKS
│
└── .gitlab-ci.yml                      ✅ Already configured

infrastructure/                         ← REFERENCE ONLY
└── (existing code with subnet CIDRs)   ← We copied the CIDR scheme
```

---

## 🎯 What We're Building

### **VPC Module** ✅ DONE
Location: `landing-zones/aws/modules/vpc/`

**Reusable VPC Module Features:**
- Auto-calculated subnet CIDRs using `cidrsubnet()` function
- Supports 2-3 Availability Zones (configurable)
- Public, Private, and Database subnets
- Single or per-AZ NAT Gateway configuration
- VPC Flow Logs to CloudWatch
- Proper EKS discovery tags
- Security group management

**Module Location & Files:**
- `aws/modules/vpc/main.tf` - VPC resource definitions
- `aws/modules/vpc/variables.tf` - Input variables
- `aws/modules/vpc/outputs.tf` - Exported values
- `aws/modules/vpc/REVIEW.md` - Known issues & recommendations

---

## 📋 Deployment Progress

### Phase 1: VPC Infrastructure ✅ IN PROGRESS

#### Step 1: VPC Module Creation ✅ DONE
- ✅ `aws/modules/vpc/main.tf` - Complete
- ✅ `aws/modules/vpc/variables.tf` - Complete
- ✅ `aws/modules/vpc/outputs.tf` - Complete
- ✅ `aws/modules/vpc/REVIEW.md` - Quality assurance document

#### Step 2: Dev Environment VPC Configuration ✅ DONE
Location: `aws/environments/dev-app-account/`

Files created/updated:
- ✅ `vpc.tf` - VPC module configured (10.0.0.0/16, 2 AZs)
- ✅ `providers.tf` - AWS provider configuration
- ✅ `outputs.tf` - VPC outputs exported
- ✅ `backend.conf` - State key path standardized
- ✅ `README.md` - Deployment documentation
- ✅ `main.tf` - Deployment role configuration (unchanged)

**Config Details:**
- VPC CIDR: 10.0.0.0/16
- AZs: eu-west-1a, eu-west-1b (2 for cost optimization)
- Public Subnets: 10.0.1.0/24, 10.0.2.0/24
- Private Subnets: 10.0.10.0/24, 10.0.11.0/24
- Database Subnets: 10.0.20.0/24, 10.0.21.0/24
- NAT Gateways: 1 (single for dev cost optimization)
- VPC Flow Logs: Enabled

#### Step 3: Prod Environment VPC Configuration ✅ DONE
Location: `aws/environments/prod-app-account/`

Files created/updated:
- ✅ `vpc.tf` - VPC module configured (10.1.0.0/16, 3 AZs, HA)
- ✅ `providers.tf` - AWS provider configuration
- ✅ `outputs.tf` - VPC outputs exported
- ✅ `README.md` - Deployment documentation (with prod emphasis)
- ✅ `main.tf` - Deployment role configuration (unchanged)

**Config Details:**
- VPC CIDR: 10.1.0.0/16
- AZs: eu-west-1a, eu-west-1b, eu-west-1c (3 for HA)
- Public Subnets: 10.1.1.0/24, 10.1.2.0/24, 10.1.3.0/24
- Private Subnets: 10.1.10.0/24, 10.1.11.0/24, 10.1.12.0/24
- Database Subnets: 10.1.20.0/24, 10.1.21.0/24, 10.1.22.0/24
- NAT Gateways: 3 (one per AZ for HA)
- VPC Flow Logs: Enabled

### Phase 2: EKS Deployment ⏳ NEXT
Location: `landing-zones/aws/modules/eks-blueprints/`

**Tasks:**
- Create EKS Blueprints module wrapper
- Deploy to dev environment
- Deploy to prod environment (with HA configuration)

### Phase 3: Additional Infrastructure ⏳ FUTURE
- RDS databases (dev and prod)
- ElastiCache (dev and prod)
- S3 buckets per environment

---

## 🔄 Subnet CIDR Scheme (From Your Infrastructure)

### Dev Account
```
VPC: 172.16.0.0/16
├── Public Zone A:  172.16.0.0/24  (eu-west-1a)
├── Public Zone B:  172.16.1.0/24  (eu-west-1b)
├── Private Zone A: 172.16.2.0/24  (eu-west-1a)
└── Private Zone B: 172.16.3.0/24  (eu-west-1b)
```

### Prod Account (Different VPC)
```
VPC: 172.17.0.0/16  (different range)
├── Public Zone A:  172.17.0.0/24  (eu-west-1a)
├── Public Zone B:  172.17.1.0/24  (eu-west-1b)
├── Private Zone A: 172.17.2.0/24  (eu-west-1a)
└── Private Zone B: 172.17.3.0/24  (eu-west-1b)
```

---

## ✅ Phase 1 Completion Status

### Core VPC Module
- [x] VPC module created and reviewed
- [x] Auto-calculated subnet allocation
- [x] EKS discovery tags
- [x] VPC Flow Logs enabled by default
- [x] NAT Gateway configuration (single and per-AZ)

### Dev Environment
- [x] VPC module instantiation
- [x] Provider configuration
- [x] Output exports
- [x] Backend configuration
- [x] State key path standardized
- [x] README documentation
- [x] Database subnets enabled

### Prod Environment
- [x] VPC module instantiation (3 AZs, multi-NAT)
- [x] Provider configuration
- [x] Output exports
- [x] Backend configuration (unchanged)
- [x] README documentation (with prod guidance)
- [x] Database subnets enabled

### Documentation & Safety
- [x] Both environments match ARCHITECTURE.md CIDR scheme
- [x] Shared account infrastructure untouched
- [x] S3 state bucket remains safe
- [x] DynamoDB lock table untouched
- [x] Cross-account IAM roles verified

## ⏳ What's Next (Phase 2+)

1. **EKS Deployment** - Create eks-blueprints module
2. **RDS Deployment** - Multi-AZ databases
3. **Karpenter Setup** - Node autoscaling
4. **Microservices** - Application deployment

---

## 📊 Infrastructure Costs (VPC Only)

| Environment | NAT Gateways | Monthly Cost |
|-------------|--------------|--------------|
| Dev | 1 | ~$32 |
| Prod | 3 | ~$96 |
| **Total** | **4** | **~$128** |

*Plus CloudWatch logs and data transfer costs (~$10/month)*

---

**VPC Infrastructure is ready for deployment!**
