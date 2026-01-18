# 🛡️ AltanovaLLM Threat Model
## STRIDE Analysis for Secure Multi-Tenant AI Platform

---

## 1. Executive Summary

**System:** AltanovaLLM - Secure Multi-Tenant AI Inference Platform

**Purpose:** Enable multiple tenants to securely use LLM inference while maintaining strict isolation, data privacy, and compliance.

**Methodology:** STRIDE (Spoofing, Tampering, Repudiation, Information Disclosure, Denial of Service, Elevation of Privilege)

**Risk Appetite:** Low - Enterprise/regulated customers require strong security guarantees.

---

## 2. System Overview

### 2.1 Assets to Protect

| Asset | Classification | Impact if Compromised |
|-------|---------------|----------------------|
| Tenant Prompts | Confidential | Data breach, compliance violation |
| LLM Responses | Confidential | PII leak, reputation damage |
| Model Artifacts | Proprietary | IP theft, competitive loss |
| Tenant Credentials | Secret | Account takeover, data theft |
| Audit Logs | Integrity-Critical | Compliance failure, forensics loss |
| Platform Infrastructure | Critical | Complete system compromise |

### 2.2 Trust Boundaries

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  INTERNET (Untrusted)                                                       │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                          ══════════╪══════════  Trust Boundary 1: Edge
                                    │
┌─────────────────────────────────────────────────────────────────────────────┐
│  EDGE LAYER (WAF + ALB)                                                     │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                          ══════════╪══════════  Trust Boundary 2: Auth
                                    │
┌─────────────────────────────────────────────────────────────────────────────┐
│  CONTROL PLANE (Gateway + OPA)                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                          ══════════╪══════════  Trust Boundary 3: Tenant
                                    │
┌───────────────────────────────┐   │   ┌───────────────────────────────┐
│  TENANT A NAMESPACE           │   │   │  TENANT B NAMESPACE           │
│  (org-a)                      │   │   │  (org-b)                      │
└───────────────────────────────┘   │   └───────────────────────────────┘
                                    │
                          ══════════╪══════════  Trust Boundary 4: Data
                                    │
┌─────────────────────────────────────────────────────────────────────────────┐
│  DATA LAYER (RDS + S3)                                                      │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Data Flow Diagram (DFD)

### 3.1 Request Flow with Attack Points

```
                                    ATTACK POINTS
                                    
     [User]                         ① Credential theft
        │                           ② Session hijacking
        ▼                           
   ┌─────────┐                      
   │ Browser │──────────────────────③ XSS, CSRF
   └────┬────┘                      
        │ HTTPS                     
        ▼                           
   ┌─────────┐                      
   │   WAF   │──────────────────────④ DDoS, SQLi bypass
   └────┬────┘                      
        │                           
        ▼                           
   ┌─────────┐                      
   │   ALB   │──────────────────────⑤ TLS downgrade
   └────┬────┘                      
        │                           
        ▼                           
   ┌─────────┐                      
   │ Gateway │──────────────────────⑥ Auth bypass, injection
   └────┬────┘                      
        │                           
        ▼                           
   ┌─────────┐                      
   │   OPA   │──────────────────────⑦ Policy bypass
   └────┬────┘                      
        │                           
        ▼                           
   ┌─────────┐                      
   │ LLM Pod │──────────────────────⑧ Container escape, prompt injection
   └────┬────┘                      
        │                           
        ▼                           
   ┌─────────┐                      
   │ Policy  │──────────────────────⑨ PII bypass
   │ Engine  │                      
   └────┬────┘                      
        │                           
        ▼                           
   ┌─────────┐                      
   │  Kafka  │──────────────────────⑩ Log tampering
   └────┬────┘                      
        │                           
        ▼                           
   ┌─────────┐                      
   │   RDS   │──────────────────────⑪ SQL injection, data exfil
   └─────────┘                      
```

---

## 4. STRIDE Analysis

### 4.1 S - Spoofing (Identity)

| ID | Threat | Attack Scenario | Likelihood | Impact | Risk | Mitigation |
|----|--------|-----------------|------------|--------|------|------------|
| S1 | Fake tenant identity | Attacker forges JWT token | Medium | High | **High** | OIDC with Auth0, JWT signature validation |
| S2 | Stolen API key | API key leaked in logs/code | Medium | High | **High** | Key rotation, Gitleaks scanning, short TTL |
| S3 | Service impersonation | Rogue pod pretends to be gateway | Low | High | **Medium** | mTLS, ServiceAccount validation |
| S4 | DNS spoofing | Redirect traffic to attacker | Low | Critical | **Medium** | DNSSEC, Route53 with IAM |

**Controls Implemented:**
```
✅ Auth0 OIDC for authentication
✅ JWT validation with JWKS endpoint
✅ Gitleaks in CI/CD to detect leaked secrets
✅ API key rotation policy
✅ ServiceAccount per workload (no default SA)
```

---

### 4.2 T - Tampering (Integrity)

| ID | Threat | Attack Scenario | Likelihood | Impact | Risk | Mitigation |
|----|--------|-----------------|------------|--------|------|------------|
| T1 | Modify request in-flight | MITM alters prompt | Low | Medium | **Low** | TLS 1.3 everywhere |
| T2 | Alter model artifacts | Poison model in S3 | Low | Critical | **Medium** | S3 versioning, KMS encryption, checksums |
| T3 | Tamper audit logs | Delete evidence of breach | Medium | High | **High** | Immutable logs, separate audit account |
| T4 | Config drift | Manual kubectl changes | Medium | Medium | **Medium** | ArgoCD self-healing, GitOps |
| T5 | Container image tampering | Push malicious image | Low | Critical | **Medium** | ECR image signing, allowed-repos policy |

**Controls Implemented:**
```
✅ TLS 1.3 on all connections
✅ S3 bucket versioning + KMS encryption
✅ Model artifact checksums (SHA256)
✅ Immutable audit logs in PostgreSQL
✅ ArgoCD drift detection + self-healing
✅ Gatekeeper allowed-repos policy (ECR only)
✅ Trivy image scanning in CI/CD
```

---

### 4.3 R - Repudiation (Accountability)

| ID | Threat | Attack Scenario | Likelihood | Impact | Risk | Mitigation |
|----|--------|-----------------|------------|--------|------|------------|
| R1 | Deny sending prompt | Tenant claims "I never asked that" | Medium | Medium | **Medium** | Request signing, audit logs |
| R2 | Deny data access | User claims unauthorized access | Medium | High | **High** | Comprehensive audit trail |
| R3 | Admin denies changes | "I didn't modify that config" | Low | Medium | **Low** | Git history, CloudTrail |

**Controls Implemented:**
```
✅ Every request logged with:
   - request_id (UUID)
   - tenant_id
   - user_id
   - timestamp
   - input_hash (SHA256)
   - output_hash (SHA256)
   - latency_ms
   - policy_decision
✅ Immutable audit logs (no UPDATE/DELETE)
✅ Git history for all config changes
✅ CloudTrail for AWS API calls
✅ Kafka for real-time audit streaming
```

---

### 4.4 I - Information Disclosure (Confidentiality)

| ID | Threat | Attack Scenario | Likelihood | Impact | Risk | Mitigation |
|----|--------|-----------------|------------|--------|------|------------|
| I1 | Cross-tenant data leak | Tenant A sees Tenant B's prompts | Medium | Critical | **Critical** | Namespace isolation, NetworkPolicy, RLS |
| I2 | PII in LLM output | Model generates SSN, email | High | High | **Critical** | Python policy engine, PII detection |
| I3 | Logs expose secrets | Credentials in error logs | Medium | High | **High** | Log sanitization, no PII in logs |
| I4 | Model extraction | Steal model weights | Low | High | **Medium** | S3 bucket policy, no public access |
| I5 | Memory disclosure | Side-channel attack on pod | Low | Medium | **Low** | Separate nodes per tenant (future) |
| I6 | Prompt injection | Extract system prompt | High | Medium | **High** | Input validation, output filtering |

**Controls Implemented:**
```
✅ Kubernetes namespace per tenant
✅ NetworkPolicy deny-all default
✅ PostgreSQL Row-Level Security (RLS)
✅ Python policy engine with PII detection:
   - Email: [REDACTED_EMAIL]
   - Phone: [REDACTED_PHONE]
   - SSN: [REDACTED_SSN]
   - Credit Card: [REDACTED_CC]
✅ Log sanitization (no raw prompts in logs)
✅ S3 bucket policy (no public access)
✅ VPC endpoints (traffic stays in AWS)
```

---

### 4.5 D - Denial of Service (Availability)

| ID | Threat | Attack Scenario | Likelihood | Impact | Risk | Mitigation |
|----|--------|-----------------|------------|--------|------|------------|
| D1 | DDoS attack | Flood API with requests | High | High | **Critical** | WAF rate limiting, CloudFront |
| D2 | Noisy neighbor | One tenant consumes all CPU | High | Medium | **High** | ResourceQuota, LimitRange |
| D3 | Storage exhaustion | Fill disk with logs | Medium | Medium | **Medium** | Log rotation, PVC limits |
| D4 | Connection exhaustion | Open many connections | Medium | Medium | **Medium** | Connection limits, timeouts |
| D5 | Poison model | Model returns infinite loop | Low | Medium | **Low** | Response timeout, output limits |

**Controls Implemented:**
```
✅ AWS WAF with rate limiting (2000 req/IP/5min)
✅ ResourceQuota per namespace:
   - CPU: 4 cores max
   - Memory: 8Gi max
   - Pods: 10 max
✅ LimitRange for pod defaults
✅ HPA for auto-scaling (2-4 replicas)
✅ Request timeout (30s)
✅ Response size limit (1MB)
✅ CloudWatch alarms for anomalies
```

---

### 4.6 E - Elevation of Privilege

| ID | Threat | Attack Scenario | Likelihood | Impact | Risk | Mitigation |
|----|--------|-----------------|------------|--------|------|------------|
| E1 | Container escape | Break out of container | Low | Critical | **High** | Non-root, read-only FS, seccomp |
| E2 | Namespace breakout | Access other namespace | Medium | Critical | **Critical** | NetworkPolicy, RBAC |
| E3 | ServiceAccount abuse | Use SA to access AWS | Medium | High | **High** | IRSA, minimal IAM permissions |
| E4 | Privilege escalation | User becomes admin | Low | Critical | **Medium** | RBAC, OPA policies |
| E5 | Kubectl access | Dev gets cluster admin | Medium | Critical | **High** | No direct kubectl, GitOps only |

**Controls Implemented:**
```
✅ Gatekeeper policies:
   - block-privileged (no privileged containers)
   - require-serviceaccount (no default SA)
   - require-resource-limits
✅ Pod Security Standards (restricted)
✅ NetworkPolicy deny-all between namespaces
✅ IRSA with minimal IAM permissions
✅ RBAC with least privilege
✅ No kubectl access - GitOps only
✅ Read-only root filesystem
✅ Non-root user (runAsNonRoot: true)
```

---

## 5. Risk Summary Matrix

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           RISK MATRIX                                       │
├─────────────────┬───────────────────────────────────────────────────────────┤
│                 │                      IMPACT                               │
│   LIKELIHOOD    │   Low        Medium       High         Critical          │
├─────────────────┼───────────────────────────────────────────────────────────┤
│   High          │   -          D2           I2,I6        D1                │
│   Medium        │   -          R1,T4        S1,S2,R2,I3  I1,E2             │
│   Low           │   T1         I5,D5        T2,T5,E4     S3,S4,E1,E3,E5    │
├─────────────────┴───────────────────────────────────────────────────────────┤
│   Legend: Critical ██  High ▓▓  Medium ░░  Low --                          │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 6. Threat to Control Mapping

| Threat Category | Primary Controls | Secondary Controls |
|-----------------|------------------|-------------------|
| **Spoofing** | OIDC/Auth0, JWT validation | Gitleaks, key rotation |
| **Tampering** | TLS, KMS, ArgoCD | Checksums, image signing |
| **Repudiation** | Audit logs, Kafka | Git history, CloudTrail |
| **Info Disclosure** | NetworkPolicy, RLS, PII filter | Encryption, VPC endpoints |
| **Denial of Service** | WAF, ResourceQuota | HPA, timeouts |
| **Elevation of Privilege** | Gatekeeper, RBAC, IRSA | GitOps, no kubectl |

---

## 7. Security Controls Summary

### 7.1 By Layer

| Layer | Controls |
|-------|----------|
| **Edge** | WAF, Rate limiting, TLS 1.3 |
| **Auth** | OIDC, JWT, API keys |
| **Authorization** | OPA, Rego policies, Styra |
| **Admission** | Gatekeeper (7 policies) |
| **Runtime** | Namespaces, NetworkPolicy, RBAC, ResourceQuota |
| **Content** | Python policy engine, PII detection |
| **Data** | RLS, KMS encryption, checksums |
| **Audit** | Kafka, immutable logs, CloudTrail |
| **Detection** | GuardDuty, Security Hub, Inspector |

### 7.2 Control Count

| STRIDE Category | Controls Implemented |
|-----------------|---------------------|
| Spoofing | 5 |
| Tampering | 7 |
| Repudiation | 5 |
| Information Disclosure | 7 |
| Denial of Service | 7 |
| Elevation of Privilege | 8 |
| **Total** | **39 controls** |

---

## 8. Residual Risks

| Risk | Status | Mitigation Plan |
|------|--------|-----------------|
| Prompt injection attacks | **Accepted** | Input validation, output filtering, monitoring |
| Advanced persistent threats | **Accepted** | GuardDuty detection, incident response plan |
| Zero-day vulnerabilities | **Accepted** | Rapid patching, Inspector scanning |
| Insider threat | **Reduced** | Audit logs, GitOps (no direct access) |
| Supply chain attack | **Reduced** | Trivy scanning, allowed-repos policy |

---

## 9. Interview Talking Points

### Q: "How did you approach security for this platform?"

> *"I started with a threat model using STRIDE methodology. I identified 6 threat categories and mapped 39 controls across 7 layers of defense. The key insight was that multi-tenant AI platforms have unique risks—cross-tenant data leakage and PII in LLM outputs—so I implemented namespace isolation with NetworkPolicy and a Python policy engine for content safety."*

### Q: "What's your biggest security concern?"

> *"Information disclosure—specifically cross-tenant data leakage and PII in LLM outputs. LLMs are probabilistic, so they might generate PII even when they shouldn't. I addressed this with defense in depth: namespace isolation at the infrastructure layer, Row-Level Security at the database layer, and a Python policy engine that detects and redacts PII patterns before any response leaves the system."*

### Q: "How do you prevent one tenant from affecting another?"

> *"Four mechanisms: (1) Kubernetes namespaces for logical isolation, (2) NetworkPolicy with deny-all default so pods can't communicate across namespaces, (3) ResourceQuota to prevent resource exhaustion, and (4) RBAC so tenants can only access their own resources. Even if one layer fails, the others catch it."*

### Q: "How do you know if you've been breached?"

> *"Multiple detection layers: GuardDuty for ML-based threat detection on VPC flow logs and CloudTrail, Security Hub for centralized findings, and comprehensive audit logs in PostgreSQL. Every request is logged with request_id, tenant_id, input/output hashes. Immutable logs mean attackers can't cover their tracks."*

---

## 10. Appendix: STRIDE Reference

| Letter | Threat | Property Violated | Question |
|--------|--------|-------------------|----------|
| **S** | Spoofing | Authentication | Can someone pretend to be someone else? |
| **T** | Tampering | Integrity | Can someone modify data they shouldn't? |
| **R** | Repudiation | Non-repudiation | Can someone deny doing something? |
| **I** | Info Disclosure | Confidentiality | Can someone see data they shouldn't? |
| **D** | Denial of Service | Availability | Can someone break the system for others? |
| **E** | Elevation of Privilege | Authorization | Can someone do things they shouldn't? |

---

**Document Version:** 1.0  
**Last Updated:** December 2024  
**Author:** AltanovaLLM Security Team  
**Review Cycle:** Quarterly
