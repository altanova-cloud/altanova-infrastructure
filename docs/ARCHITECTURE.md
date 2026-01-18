# AWS Multi-Account Architecture for Microservices Platform
## Production-Ready Design with AWS Organizations Best Practices

---

## 📊 Current Deployment Status

> **Last Updated:** January 2026
>
> This document reflects the **actual deployed state** of the infrastructure.
> Items marked with ✅ are deployed, ➕ are planned, and ❌ are not recommended.

---

## 🏢 AWS Organization Structure

```
AWS Organization (Root)
├── Management Account (Org root)
├── Shared Services Account (265245191272) ─── eu-west-1/us-east-1
├── Dev Account ─────────────────────────────── eu-west-1
└── Prod Account ────────────────────────────── eu-west-1
```

---

## 🎯 Architecture Overview

### **Separate VPCs in Dev and Prod Accounts (AWS Best Practice)**

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
│               │    │ │ VPC  ✅   │ │    │ │ VPC  ✅   │ │
│ ✅ GitHub OIDC│    │ │ EKS  ✅   │ │    │ │ EKS  ➕   │ │
│ ✅ TF State   │    │ │ Cluster   │ │    │ │ Cluster   │ │
│ ✅ ECR        │◄───┼─┤           │ │    │ │           │ │
│ ➕ Secrets Mgr│    │ │ Dev Apps  │ │    │ │ Prod Apps │ │
│ ✅ Route53    │    │ └───────────┘ │    │ └───────────┘ │
│ ➕ Transit GW │    │               │    │               │
│   (optional)  │    │ ✅ Dev RDS    │    │ ➕ Prod RDS   │
│               │    │ ➕ Dev Redis  │    │ ➕ Prod Redis │
└───────────────┘    │ ➕ Dev S3     │    │ ➕ Prod S3    │
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

**Current Deployment Status:**
```
Shared Services Account (265245191272)
│
├── CI/CD Infrastructure
│   ├── ✅ GitHub OIDC Provider
│   │   └── GitHubActionsRole (OIDC authentication)
│   ├── ✅ Terraform State Backend
│   │   ├── S3 Bucket: altanova-tf-state-eu-central-1
│   │   └── DynamoDB Table: altanova-terraform-locks
│   └── ✅ Cross-Account Access
│       └── TerraformStateAccessRole
│
├── Container Registry
│   └── ✅ Amazon ECR
│       ├── altanova/control-plane
│       ├── altanova/inference-service
│       ├── altanova/tenant-console
│       └── altanova/audit-logger
│
├── Networking (Optional)
│   └── ➕ Transit Gateway (planned)
│
├── DNS
│   └── ✅ Route53 Hosted Zone
│       └── altanova.cloud (external NS at one.com)
│
├── Secrets Management
│   ├── ➕ AWS Secrets Manager (cross-account, planned)
│   └── ➕ Parameter Store (planned)
│
├── Security Services
│   ├── ➕ AWS Security Hub (planned)
│   ├── ➕ GuardDuty (planned)
│   └── ➕ AWS Config (planned)
│
└── Monitoring (Optional)
    ├── ➕ CloudWatch (planned)
    └── ➕ Grafana/Prometheus (planned)
```

**What NOT to deploy:**
- ❌ Application VPCs
- ❌ EKS clusters for apps
- ❌ Application databases

**Why:** Shared services should be infrastructure-focused, not application-focused

---

### 3. **Dev Account** ✅ DEVELOPMENT VPC + EKS

**Purpose:** Development and testing environment

**Current Deployment Status:**
```
Dev Account (eu-west-1)
│
├── ✅ VPC: altanova-dev-euw1-vpc (10.0.0.0/16)
│   ├── ✅ Public Subnets (2 AZs)
│   │   ├── altanova-dev-euw1-public-a (10.0.1.0/24) - eu-west-1a
│   │   └── altanova-dev-euw1-public-b (10.0.2.0/24) - eu-west-1b
│   ├── ✅ Private Subnets (2 AZs) - EKS-ready tags
│   │   ├── altanova-dev-euw1-private-a (10.0.10.0/24) - eu-west-1a
│   │   └── altanova-dev-euw1-private-b (10.0.11.0/24) - eu-west-1b
│   ├── ✅ Database Subnets (2 AZs)
│   │   ├── altanova-dev-euw1-database-a (10.0.20.0/24) - eu-west-1a
│   │   └── altanova-dev-euw1-database-b (10.0.21.0/24) - eu-west-1b
│   ├── ✅ Internet Gateway: altanova-dev-euw1-igw
│   ├── ✅ NAT Gateway: altanova-dev-euw1-nat (single, cost-optimized)
│   └── ✅ VPC Flow Logs (CloudWatch)
│
├── ✅ IAM
│   └── DevDeployRole (GitHub Actions cross-account access)
│
├── ✅ RDS PostgreSQL: altanova-dev-euw1-postgres
│   ├── Engine: PostgreSQL 18.1
│   ├── Instance: db.t3.micro (Free Tier)
│   ├── Storage: 20GB gp3 (encrypted)
│   ├── Single-AZ (cost-optimized)
│   ├── Performance Insights: enabled (7 days)
│   └── Credentials: AWS Secrets Manager
│
├── ✅ EKS Cluster: altanova-dev-euw1-eks
│   ├── Version: 1.31
│   ├── System Nodes: 2x t3.small (managed, on-demand)
│   │   ├── Taint: CriticalAddonsOnly=true:NoSchedule
│   │   └── Runs: Karpenter, CoreDNS, system add-ons
│   ├── Application Nodes: Karpenter-managed (SPOT + on-demand)
│   │   ├── General NodePool: t3/m5/c5 (small-large), SPOT priority
│   │   └── Critical NodePool: t3/m5 (small-medium), on-demand only
│   ├── Add-ons: CoreDNS, kube-proxy, VPC-CNI, Pod Identity Agent
│   └── IRSA: Enabled for service account IAM integration
│
├── ✅ ACM Certificate: *.dev.altanova.cloud
│   └── DNS Validation via Route53 (shared account)
│
├── ➕ ElastiCache (planned)
│
└── ➕ Application S3 Buckets (planned)
```

**Configuration:**
- ✅ Single NAT Gateway (cost optimization)
- ✅ VPC Flow Logs enabled
- ✅ Database in isolated subnets
- ✅ EKS-ready subnet tagging
- ➕ Auto-shutdown during off-hours (planned)

---

### 4. **Prod Account** ✅ PRODUCTION VPC + EKS

**Purpose:** Production workloads

**Current Deployment Status:**
```
Prod Account (eu-west-1)
│
├── ✅ VPC: altanova-prod-euw1-vpc (10.1.0.0/16)
│   ├── ✅ Public Subnets (3 AZs)
│   │   ├── altanova-prod-euw1-public-a (10.1.1.0/24) - eu-west-1a
│   │   ├── altanova-prod-euw1-public-b (10.1.2.0/24) - eu-west-1b
│   │   └── altanova-prod-euw1-public-c (10.1.3.0/24) - eu-west-1c
│   ├── ✅ Private Subnets (3 AZs) - EKS-ready tags
│   │   ├── altanova-prod-euw1-private-a (10.1.10.0/24) - eu-west-1a
│   │   ├── altanova-prod-euw1-private-b (10.1.11.0/24) - eu-west-1b
│   │   └── altanova-prod-euw1-private-c (10.1.12.0/24) - eu-west-1c
│   ├── ✅ Database Subnets (3 AZs)
│   │   ├── altanova-prod-euw1-database-a (10.1.20.0/24) - eu-west-1a
│   │   ├── altanova-prod-euw1-database-b (10.1.21.0/24) - eu-west-1b
│   │   └── altanova-prod-euw1-database-c (10.1.22.0/24) - eu-west-1c
│   ├── ✅ Internet Gateway: altanova-prod-euw1-igw
│   ├── ✅ NAT Gateway: altanova-prod-euw1-nat (single, upgrade to 3 for HA)
│   ├── ✅ VPC Flow Logs (CloudWatch)
│   └── ✅ Default Security Group (locked down - no ingress/egress)
│
├── ✅ IAM
│   └── ProdDeployRole (GitHub Actions cross-account access)
│
├── ➕ RDS PostgreSQL (planned)
│   ├── Multi-AZ deployment
│   ├── Production instance class
│   └── Automated backups
│
├── ➕ EKS Cluster (planned)
│   ├── Cluster Name: altanova-prod-euw1-eks
│   ├── Version: 1.32
│   ├── Node Groups: 6-20 nodes (production-grade)
│   └── Multi-AZ deployment
│
├── ➕ ElastiCache Multi-AZ (planned)
│
└── ➕ Application S3 Buckets (planned, versioned)
```

**Configuration:**
- ✅ 3 Availability Zones (HA-ready)
- ✅ VPC Flow Logs enabled
- ✅ Default Security Group locked down
- ✅ EKS-ready subnet tagging
- ⚠️ Single NAT Gateway (upgrade to 3 for production HA)
- ➕ Multi-AZ NAT Gateways (planned)
- ➕ Enhanced monitoring (planned)

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

### Cross-Account Access ✅ DEPLOYED

```
GitHub Actions (OIDC)
    ↓
[GitHubActionsRole] ← Shared Account (OIDC trust)
    ↓
    ├── Direct: Terraform State (S3 + DynamoDB)
    │
    └── Cross-Account Assume Role
        ├── [DevDeployRole] ← Dev Account
        │       └── Assumes: TerraformStateAccessRole
        │
        └── [ProdDeployRole] ← Prod Account
                └── Assumes: TerraformStateAccessRole
```

**IAM Role Chain:**
1. GitHub Actions authenticates via OIDC → `GitHubActionsRole` (Shared)
2. `GitHubActionsRole` assumes `DevDeployRole` or `ProdDeployRole` (App Accounts)
3. Deploy roles assume `TerraformStateAccessRole` (Shared) for state access

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

### Phase 1: Foundation ✅ COMPLETE
**Shared Services Account:**
- ✅ GitHub OIDC Provider + GitHubActionsRole
- ✅ Terraform State Backend (S3 + DynamoDB)
- ✅ Cross-Account Access Role (TerraformStateAccessRole)

**Dev Account:**
- ✅ VPC with 3-tier subnet architecture
- ✅ DevDeployRole for CI/CD
- ✅ RDS PostgreSQL (dev instance)

**Prod Account:**
- ✅ VPC with 3-tier subnet architecture (3 AZs)
- ✅ ProdDeployRole for CI/CD
- ✅ Hardened default security group

### Phase 2: Shared Services Enhancement ✅ COMPLETE
**Shared Services Account:**
- ✅ ECR repositories (control-plane, inference-service, tenant-console, audit-logger)
- ✅ Route53 hosted zone (altanova.cloud)
- ➕ Centralized Secrets Manager (planned)

### Phase 3: EKS Clusters ✅ IN PROGRESS
**Dev Account:**
- ✅ EKS cluster deployed (altanova-dev-euw1-eks v1.31)
- ✅ Karpenter for auto-scaling (replaces Cluster Autoscaler)
- ✅ System node group (2x t3.small, on-demand)
- ✅ Application NodePools (general + critical)
- ✅ AWS Load Balancer Controller
- ✅ ACM Certificate (*.dev.altanova.cloud)
- ➕ ElastiCache for session/cache

**Prod Account:**
- ➕ Deploy EKS cluster (altanova-prod-euw1-eks)
- ➕ Upgrade NAT Gateway to Multi-AZ (3 gateways)
- ➕ RDS PostgreSQL Multi-AZ
- ➕ ElastiCache Multi-AZ

### Phase 4: Application Deployment ➕ PLANNED
**Both Accounts:**
- ➕ Deploy microservices
- ➕ Configure monitoring (CloudWatch, Prometheus)
- ➕ Set up disaster recovery
- ➕ Production go-live

---

## 📁 Current Directory Structure

```
AltanovaLLM/
├── aws/
│   ├── modules/                      # Reusable Terraform modules
│   │   ├── bootstrap/                # ✅ S3 state bucket + DynamoDB locks
│   │   ├── github-oidc/              # ✅ GitHub Actions OIDC role
│   │   └── deployment-role/          # ✅ Cross-account deploy roles
│   │
│   └── environments/
│       ├── shared-account/           # ✅ Shared Services Account
│       │   ├── main.tf               # Bootstrap + GitHub OIDC modules
│       │   ├── ecr.tf                # ✅ ECR repositories for platform services
│       │   ├── route53.tf            # ✅ Route53 hosted zone + cross-account policy
│       │   ├── variables.tf          # Account IDs, GitHub config, domain
│       │   ├── backend.tf            # Remote state config
│       │   └── backend.conf          # Backend credentials
│       │
│       ├── dev-app-account/          # ✅ Dev Account
│       │   ├── main.tf               # VPC module (terraform-aws-modules)
│       │   ├── iam.tf                # DevDeployRole
│       │   ├── rds.tf                # ✅ PostgreSQL + Secrets Manager
│       │   ├── eks.tf                # ✅ EKS cluster + system nodes + Karpenter IAM
│       │   ├── karpenter.tf          # ✅ Karpenter Helm + NodePool/EC2NodeClass
│       │   ├── alb-controller.tf     # ✅ AWS Load Balancer Controller
│       │   ├── acm.tf                # ✅ ACM certificate (*.dev.altanova.cloud)
│       │   ├── variables.tf          # Cross-account role ARNs, domain config
│       │   ├── outputs.tf            # VPC, RDS, EKS, ACM outputs
│       │   ├── providers.tf          # AWS + Kubernetes + Helm + Kubectl providers
│       │   ├── backend.tf            # Remote state config
│       │   └── backend.conf          # Backend credentials
│       │
│       └── prod-app-account/         # ✅ Prod Account
│           ├── main.tf               # VPC module (terraform-aws-modules)
│           ├── iam.tf                # ProdDeployRole
│           ├── variables.tf          # Cross-account role ARNs
│           ├── outputs.tf            # VPC outputs
│           ├── providers.tf          # AWS provider config
│           ├── backend.tf            # Remote state config
│           └── backend.conf          # Backend credentials
│
├── docs/
│   ├── ARCHITECTURE.md               # This file
│   └── PIPELINE.md                   # CI/CD pipeline documentation
│
├── .github/
│   └── workflows/
│       └── terraform-shared.yml      # ✅ GitHub Actions CI/CD
│
└── CLAUDE.md                         # Claude Code instructions
```

---

## ✅ Current State Summary

### **What's Deployed:**

| Component | Shared | Dev | Prod |
|-----------|--------|-----|------|
| Terraform State (S3/DynamoDB) | ✅ | - | - |
| GitHub OIDC | ✅ | - | - |
| Cross-Account Roles | ✅ | ✅ | ✅ |
| VPC (3-tier) | - | ✅ | ✅ |
| NAT Gateway | - | ✅ (1) | ✅ (1) |
| VPC Flow Logs | - | ✅ | ✅ |
| RDS PostgreSQL | - | ✅ | ➕ |
| EKS Cluster | - | ✅ | ➕ |
| ECR | ✅ | - | - |
| Route53 | ✅ | - | - |
| ACM Certificate | - | ✅ | ➕ |

### **Architecture Decisions Applied:**

1. **✅ Separate VPCs in Dev and Prod Accounts**
   - Complete environment isolation
   - Independent scaling
   - Blast radius containment

2. **✅ Shared Services Account for:**
   - Terraform State (deployed)
   - GitHub OIDC authentication (deployed)
   - ECR, Route53, Secrets Manager (planned)

3. **✅ Network Design:**
   - Dev: 10.0.0.0/16, 2 AZs, 1 NAT GW (cost-optimized)
   - Prod: 10.1.0.0/16, 3 AZs, 1 NAT GW (upgrade to 3 for HA)
   - 3-tier subnet design (Public, Private, Database)

4. **✅ Security:**
   - No workloads in Management Account
   - Cross-account IAM roles configured
   - Prod default security group locked down
   - VPC Flow Logs enabled in all VPCs

---

## 🎯 Next Steps

### Immediate:
1. **Configure NS records at one.com** - Point to AWS Route53 name servers
2. **Set route53_zone_id in dev-app-account** - After shared account deploy
3. **Deploy Prod RDS** - PostgreSQL Multi-AZ

### Short-term (Phase 3 continuation):
4. **Deploy ArgoCD** - GitOps controller for continuous deployment
5. **Upgrade Prod NAT to Multi-AZ** - 3 NAT gateways for HA
6. **Deploy EKS in Prod** - Production-grade cluster

### Medium-term (Phase 4):
7. **Deploy microservices** - Application workloads
8. **Configure monitoring** - CloudWatch, Prometheus, Grafana
9. **Go live!**
