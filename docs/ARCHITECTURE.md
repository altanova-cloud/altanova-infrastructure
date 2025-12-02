# AWS Multi-Account Architecture for Microservices Platform
## Production-Ready Design with AWS Organizations Best Practices

---

## 🏢 Your Current AWS Organization Structure

```
AWS Organization (Root)
├── Management Account (Org root)
├── Shared Services Account (SharedOU)
├── Dev Account (Development workloads)
└── Prod Account (Production workloads)
```

---

## 🎯 Recommended Architecture: Where to Deploy VPC & EKS

### **RECOMMENDATION: Deploy Separate VPCs in Dev and Prod Accounts**

#### ✅ **Best Practice Architecture:**

```
┌─────────────────────────────────────────────────────────────────┐
│ Management Account                                              │
│ - AWS Organizations                                             │
│ - Consolidated Billing                                          │
│ - CloudTrail (Organization trail)                               │
│ - AWS Config (Aggregator)                                       │
│ - NO WORKLOADS (Security best practice)                         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ (Organization hierarchy)
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│ Shared        │    │ Dev Account   │    │ Prod Account  │
│ Services      │    │               │    │               │
│ Account       │    │ ┌───────────┐ │    │ ┌───────────┐ │
│               │    │ │ VPC       │ │    │ │ VPC       │ │
│ - GitLab OIDC │    │ │ Dev EKS   │ │    │ │ Prod EKS  │ │
│ - TF State    │    │ │ Cluster   │ │    │ │ Cluster   │ │
│ - ECR         │◄───┼─┤           │ │    │ │           │ │
│ - Secrets Mgr │    │ │ Dev Apps  │ │    │ │ Prod Apps │ │
│ - Route53     │    │ └───────────┘ │    │ └───────────┘ │
│ - Transit GW  │    │               │    │               │
│   (optional)  │    │ - Dev RDS     │    │ - Prod RDS    │
│               │    │ - Dev Redis   │    │ - Prod Redis  │
└───────────────┘    │ - Dev S3      │    │ - Prod S3     │
                     └───────────────┘    └───────────────┘
```

---

## 📋 Detailed Recommendation by Account

### 1. **Management Account** ❌ NO WORKLOADS

**Purpose:** Governance and billing only

**What to deploy:**
- ✅ AWS Organizations configuration
- ✅ Service Control Policies (SCPs)
- ✅ CloudTrail (organization-wide)
- ✅ AWS Config (aggregator)
- ✅ Cost Explorer / Budgets

**What NOT to deploy:**
- ❌ VPCs
- ❌ EKS clusters
- ❌ Application workloads
- ❌ Databases

**Why:** Security isolation - if management account is compromised, entire org is at risk

---

### 2. **Shared Services Account** ✅ SHARED INFRASTRUCTURE

**Purpose:** Centralized services used by all accounts

**What to deploy:**
```
Shared Services Account
├── Networking (Optional)
│   └── Transit Gateway (for cross-account connectivity)
│
├── Container Registry
│   └── Amazon ECR (shared Docker images)
│
├── CI/CD Infrastructure
│   ├── GitLab OIDC Provider (already deployed)
│   └── Terraform State (S3 + DynamoDB) (already deployed)
│
├── DNS
│   └── Route53 Hosted Zones (company.com)
│
├── Secrets Management
│   ├── AWS Secrets Manager (cross-account access)
│   └── Parameter Store
│
├── Security Services
│   ├── AWS Security Hub (aggregator)
│   ├── GuardDuty (delegated admin)
│   └── AWS Config (rules)
│
└── Monitoring (Optional)
    ├── CloudWatch (cross-account dashboards)
    └── Grafana/Prometheus (centralized)
```

**What NOT to deploy:**
- ❌ Application VPCs
- ❌ EKS clusters for apps
- ❌ Application databases

**Why:** Shared services should be infrastructure-focused, not application-focused

---

### 3. **Dev Account** ✅ DEVELOPMENT VPC + EKS

**Purpose:** Development and testing environment

**What to deploy:**
```
Dev Account
├── VPC (10.0.0.0/16)
│   ├── Public Subnets (10.0.1.0/24, 10.0.2.0/24)
│   ├── Private Subnets (10.0.10.0/24, 10.0.11.0/24)
│   ├── Database Subnets (10.0.20.0/24, 10.0.21.0/24)
│   ├── Internet Gateway
│   └── NAT Gateway (1 for cost savings)
│
├── EKS Cluster (Dev)
│   ├── Cluster Name: technosol-dev
│   ├── Version: 1.32
│   ├── Node Groups: 2-4 nodes (smaller instances)
│   └── Add-ons: LB Controller, Autoscaler, etc.
│
├── Data Layer
│   ├── RDS (Dev) - smaller instances
│   ├── ElastiCache (Dev)
│   └── S3 Buckets (dev-*)
│
└── Microservices
    ├── Service A (dev)
    ├── Service B (dev)
    └── Service C (dev)
```

**Configuration:**
- Lower-cost instances
- Single NAT Gateway
- Relaxed security for testing
- Auto-shutdown during off-hours

---

### 4. **Prod Account** ✅ PRODUCTION VPC + EKS

**Purpose:** Production workloads

**What to deploy:**
```
Prod Account
├── VPC (10.1.0.0/16)
│   ├── Public Subnets (10.1.1.0/24, 10.1.2.0/24, 10.1.3.0/24)
│   ├── Private Subnets (10.1.10.0/24, 10.1.11.0/24, 10.1.12.0/24)
│   ├── Database Subnets (10.1.20.0/24, 10.1.21.0/24, 10.1.22.0/24)
│   ├── Internet Gateway
│   └── NAT Gateways (3 - one per AZ for HA)
│
├── EKS Cluster (Prod)
│   ├── Cluster Name: technosol-prod
│   ├── Version: 1.32
│   ├── Node Groups: 6-20 nodes (production-grade)
│   ├── Multi-AZ deployment
│   └── Add-ons: Full observability stack
│
├── Data Layer (HA)
│   ├── RDS Multi-AZ
│   ├── ElastiCache Multi-AZ
│   └── S3 Buckets (prod-*, versioned)
│
└── Microservices
    ├── Service A (prod) - Multi-AZ
    ├── Service B (prod) - Multi-AZ
    └── Service C (prod) - Multi-AZ
```

**Configuration:**
- Production-grade instances
- Multi-AZ NAT Gateways
- Strict security policies
- Enhanced monitoring
- Automated backups

---

## 🏗️ Network Architecture Details

### VPC Design (Per Environment)

```
┌─────────────────────────────────────────────────────────────┐
│ VPC (10.0.0.0/16 for Dev, 10.1.0.0/16 for Prod)           │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ AZ-1a        │  │ AZ-1b        │  │ AZ-1c        │     │
│  │              │  │              │  │              │     │
│  │ Public       │  │ Public       │  │ Public       │     │
│  │ 10.x.1.0/24  │  │ 10.x.2.0/24  │  │ 10.x.3.0/24  │     │
│  │ - NAT GW     │  │ - NAT GW     │  │ - NAT GW     │     │
│  │ - ALB        │  │ - ALB        │  │ - ALB        │     │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘     │
│         │                 │                 │             │
│  ┌──────▼───────┐  ┌──────▼───────┐  ┌──────▼───────┐     │
│  │ Private      │  │ Private      │  │ Private      │     │
│  │ 10.x.10.0/24 │  │ 10.x.11.0/24 │  │ 10.x.12.0/24 │     │
│  │ - EKS Nodes  │  │ - EKS Nodes  │  │ - EKS Nodes  │     │
│  │ - App Pods   │  │ - App Pods   │  │ - App Pods   │     │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘     │
│         │                 │                 │             │
│  ┌──────▼───────┐  ┌──────▼───────┐  ┌──────▼───────┐     │
│  │ Database     │  │ Database     │  │ Database     │     │
│  │ 10.x.20.0/24 │  │ 10.x.21.0/24 │  │ 10.x.22.0/24 │     │
│  │ - RDS        │  │ - RDS        │  │ - RDS        │     │
│  │ - ElastiCache│  │ - ElastiCache│  │ - ElastiCache│     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

### Subnet Sizing Guide

| Subnet Type | CIDR | IPs Available | Purpose |
|-------------|------|---------------|---------|
| Public | /24 | 251 | Load balancers, NAT GW |
| Private | /24 | 251 | EKS nodes, app pods |
| Database | /24 | 251 | RDS, ElastiCache |

---

## 🔐 Security Architecture

### Network Security Layers

```
Internet
    ↓
[CloudFront / WAF] ← DDoS protection
    ↓
[Application Load Balancer] ← Public subnet
    ↓
[Security Group: ALB → EKS] ← Only allow ALB traffic
    ↓
[EKS Pods in Private Subnet] ← No direct internet access
    ↓
[Security Group: EKS → RDS] ← Only allow EKS traffic
    ↓
[RDS in Database Subnet] ← Isolated
```

### Cross-Account Access

```
Dev/Prod Accounts
    ↓
[IAM Role Assumption] ← DevDeployRole / ProdDeployRole
    ↓
Shared Services Account
    ↓
[ECR, Secrets Manager, Route53]
```

---

## 📦 Microservices Deployment Strategy

### Service Mesh Architecture

```
EKS Cluster
├── Namespace: team-a
│   ├── Service A (Frontend)
│   ├── Service B (API Gateway)
│   └── Service C (Auth Service)
│
├── Namespace: team-b
│   ├── Service D (Payment)
│   ├── Service E (Inventory)
│   └── Service F (Notifications)
│
└── Namespace: platform
    ├── Istio / Linkerd (Service Mesh)
    ├── ArgoCD (GitOps)
    ├── Prometheus (Monitoring)
    └── Grafana (Dashboards)
```

### Traffic Flow

```
User Request
    ↓
Route53 (Shared Account)
    ↓
CloudFront (Optional CDN)
    ↓
ALB (Public Subnet)
    ↓
NGINX Ingress Controller (EKS)
    ↓
Service Mesh (Istio)
    ↓
Microservice Pods (Private Subnet)
    ↓
RDS / ElastiCache (Database Subnet)
```

---

## 🚀 Implementation Roadmap

### Phase 1: Foundation (Week 1-2)
**Shared Services Account:**
- ✅ Already have: OIDC, Terraform State
- ➕ Add: ECR repositories
- ➕ Add: Route53 hosted zone
- ➕ Add: Secrets Manager

**Dev Account:**
- ➕ Deploy VPC with EKS Blueprints
- ➕ Deploy EKS cluster
- ➕ Configure cross-account access to Shared Services

### Phase 2: Development Environment (Week 3-4)
**Dev Account:**
- ➕ Deploy microservices (dev versions)
- ➕ Set up CI/CD pipeline
- ➕ Configure monitoring
- ➕ Test end-to-end

### Phase 3: Production Environment (Week 5-6)
**Prod Account:**
- ➕ Deploy VPC with EKS Blueprints
- ➕ Deploy EKS cluster (HA configuration)
- ➕ Deploy production databases
- ➕ Configure enhanced security

### Phase 4: Production Deployment (Week 7-8)
**Prod Account:**
- ➕ Deploy microservices (prod versions)
- ➕ Configure auto-scaling
- ➕ Set up disaster recovery
- ➕ Go live!

---

## 📁 Recommended Directory Structure

```
tech-repo/
├── landing-zones/                    # Account setup
│   └── aws/environments/
│       ├── shared-account/           # OIDC, State, ECR
│       ├── dev-app-account/          # Dev IAM roles
│       └── prod-app-account/         # Prod IAM roles
│
└── infrastructure/                   # Application infrastructure
    ├── modules/
    │   ├── vpc/                      # Reusable VPC module
    │   ├── eks-blueprints/           # EKS wrapper module
    │   └── microservices/            # App deployment module
    │
    ├── shared-services/
    │   ├── ecr/                      # Container registry
    │   ├── route53/                  # DNS
    │   └── secrets/                  # Secrets management
    │
    ├── environments/
    │   ├── dev/
    │   │   ├── vpc.tf                # Dev VPC
    │   │   ├── eks.tf                # Dev EKS (Blueprints)
    │   │   ├── rds.tf                # Dev databases
    │   │   ├── backend.tf            # Remote state
    │   │   └── terraform.tfvars      # Dev config
    │   │
    │   └── prod/
    │       ├── vpc.tf                # Prod VPC
    │       ├── eks.tf                # Prod EKS (Blueprints)
    │       ├── rds.tf                # Prod databases (HA)
    │       ├── backend.tf            # Remote state
    │       └── terraform.tfvars      # Prod config
    │
    └── .gitlab-ci.yml                # Infrastructure pipeline
```

---

## ✅ Final Recommendations

### **For Your Microservices Platform:**

1. **✅ Deploy VPC + EKS in BOTH Dev and Prod Accounts**
   - Complete environment isolation
   - Independent scaling
   - Blast radius containment

2. **✅ Use Shared Services Account for:**
   - ECR (container images)
   - Route53 (DNS)
   - Secrets Manager
   - Terraform State (already done)

3. **✅ Use EKS Blueprints**
   - Production-ready patterns
   - Best practices built-in
   - Easy multi-environment deployment

4. **✅ Network Design:**
   - Dev: 10.0.0.0/16 (1 NAT GW for cost)
   - Prod: 10.1.0.0/16 (3 NAT GWs for HA)
   - 3-tier subnet design (Public, Private, Database)

5. **✅ Security:**
   - No workloads in Management Account
   - Cross-account IAM roles (already configured)
   - Network isolation per environment
   - Service mesh for microservices

---

## 🎯 Next Steps

1. **Review and approve this architecture**
2. **Start with Dev environment:**
   - Deploy VPC in Dev Account
   - Deploy EKS with Blueprints
   - Test with one microservice

3. **Once Dev is stable:**
   - Replicate to Prod Account
   - Deploy production workloads

**Ready to start?** I can help you build the Dev environment first!
