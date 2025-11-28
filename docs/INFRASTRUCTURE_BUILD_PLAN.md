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

**Based on your existing design:**
- VPC: `172.16.0.0/16`
- Public Zone A: `172.16.0.0/24`
- Public Zone B: `172.16.1.0/24`
- Private Zone A: `172.16.2.0/24`
- Private Zone B: `172.16.3.0/24`

**Features:**
- 2 Availability Zones
- Public subnets (for ALB, NAT)
- Private subnets (for EKS nodes)
- NAT Gateway (1 for dev, 2 for prod)
- Proper EKS tags
- VPC Flow Logs

---

## 📋 Next Steps

### Step 1: Create EKS Blueprints Module ⏳
Location: `landing-zones/aws/modules/eks-blueprints/`

This will wrap AWS EKS Blueprints with our configuration.

### Step 2: Deploy Dev Environment ⏳
Location: `landing-zones/aws/environments/dev-app-account/`

Files to create:
- `vpc.tf` - Use VPC module
- `eks.tf` - Use EKS Blueprints module
- Update `backend.tf`
- Update `terraform.tfvars`

### Step 3: Deploy Prod Environment ⏳
Location: `landing-zones/aws/environments/prod-app-account/`

Same as dev but with HA configuration.

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

## ✅ What's Complete

- [x] VPC Module created in landing-zones
- [x] Matches your existing subnet design
- [x] Supports dev (1 NAT) and prod (2 NAT)
- [x] Proper EKS tags
- [x] VPC Flow Logs

---

## ⏳ What's Next

- [ ] Create EKS Blueprints module
- [ ] Deploy to dev-app-account
- [ ] Deploy to prod-app-account
- [ ] Deploy your microservices

---

**Ready to create the EKS Blueprints module?**
