# Security Dashboard Roadmap
## Centralized Vulnerability Management for Ecommerce SaaS Platform

---

## Summary of Goals

### Mission
Establish a comprehensive security vulnerability management system that provides:
1. **Centralized visibility** into all security findings across infrastructure and applications
2. **Historical tracking** of vulnerabilities over time
3. **Risk-based prioritization** for remediation efforts
4. **Compliance reporting** for SOC 2 and future certifications
5. **Integration** with development workflows (GitHub, Jira, Slack)

### Why a Security Dashboard?

| Challenge | Solution |
|-----------|----------|
| Findings scattered across tools | Single pane of glass |
| No historical trending | Track improvement over time |
| Manual review process | Automated triage and alerting |
| Compliance audit preparation | Built-in reporting |
| Context switching | Integrated with existing tools |

---

## Current Architecture (Phase 2 - GitHub-Native)

### Overview

Currently, security scanning is integrated directly into GitHub Actions with results displayed in PR comments and GitHub's Security tab.

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         CURRENT STATE (Phase 2)                             │
│                        GitHub-Native Security Scanning                       │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────┐
│ Developer Workstation                                                        │
│                                                                              │
│   git push ──────────────────────────────────────────────────────────┐      │
│                                                                      │      │
└──────────────────────────────────────────────────────────────────────┼──────┘
                                                                       │
                                                                       ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ GitHub Repository (altanova-cloud/altanova-infrastructure)                   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │ GitHub Actions Workflow                                              │    │
│  │                                                                      │    │
│  │  ┌───────────────┐    ┌───────────────┐    ┌───────────────┐       │    │
│  │  │ terraform-    │    │ security-scan │    │ terraform-    │       │    │
│  │  │ validate      │───▶│ (reusable)    │───▶│ plan          │       │    │
│  │  │               │    │               │    │               │       │    │
│  │  │ - fmt check   │    │ ┌───────────┐ │    │ - init        │       │    │
│  │  │ - init        │    │ │ TFLint    │ │    │ - plan        │       │    │
│  │  │ - validate    │    │ ├───────────┤ │    │ - comment PR  │       │    │
│  │  └───────────────┘    │ │ Checkov   │ │    └───────────────┘       │    │
│  │                       │ ├───────────┤ │                             │    │
│  │                       │ │ TFSec     │ │                             │    │
│  │                       │ └───────────┘ │                             │    │
│  │                       └───────┬───────┘                             │    │
│  │                               │                                      │    │
│  └───────────────────────────────┼──────────────────────────────────────┘    │
│                                  │                                           │
│                                  ▼                                           │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                         Outputs                                        │  │
│  │                                                                        │  │
│  │  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐                 │  │
│  │  │ PR Comments │   │ Artifacts   │   │ SARIF       │                 │  │
│  │  │             │   │             │   │ Upload      │                 │  │
│  │  │ Security    │   │ JSON/SARIF  │   │             │                 │  │
│  │  │ results     │   │ reports     │   │ Code        │                 │  │
│  │  │ table       │   │ (90 days)   │   │ Scanning    │                 │  │
│  │  └─────────────┘   └─────────────┘   └─────────────┘                 │  │
│  │                                              │                        │  │
│  └──────────────────────────────────────────────┼────────────────────────┘  │
│                                                 │                            │
│                                                 ▼                            │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │ GitHub Security Tab                                                  │    │
│  │                                                                      │    │
│  │  - Code scanning alerts                                             │    │
│  │  - Filter by tool (tflint, checkov, tfsec)                          │    │
│  │  - Severity levels                                                  │    │
│  │  - Dismiss/track findings                                           │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Current Capabilities

| Feature | Status | Notes |
|---------|--------|-------|
| Infrastructure scanning | ✅ Active | TFLint, Checkov, TFSec |
| PR feedback | ✅ Active | Security results in PR comments |
| SARIF integration | ✅ Active | GitHub Security tab |
| Artifact retention | ✅ Active | 90 days (SOC 2) |
| Historical trending | ❌ Limited | Only via GitHub Security tab |
| Custom dashboards | ❌ None | Not available |
| Multi-repo aggregation | ❌ None | Each repo separate |
| Jira integration | ❌ None | Manual ticket creation |
| Risk scoring | ❌ Limited | Basic severity only |

### Limitations

1. **No centralized dashboard** - Each repo has its own Security tab
2. **Limited historical analysis** - No trending over time
3. **Manual triage** - No automated workflows
4. **No custom reporting** - Only GitHub's built-in views
5. **Single-repo scope** - Can't aggregate across repos/projects

---

## Future Architecture (DefectDojo on EKS)

### Overview

DefectDojo provides a centralized security dashboard that aggregates findings from multiple tools and repositories, enabling enterprise-grade vulnerability management.

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      FUTURE STATE (DefectDojo on EKS)                       │
│                    Centralized Vulnerability Management                      │
└─────────────────────────────────────────────────────────────────────────────┘

                                   Developer
                                      │
                                      │ git push
                                      ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ GitHub (Multiple Repositories)                                               │
│                                                                              │
│  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐ │
│  │ landing-zones       │  │ application-repo    │  │ microservices-repo  │ │
│  │ (Terraform)         │  │ (Python/Node)       │  │ (Go/Rust)           │ │
│  │                     │  │                     │  │                     │ │
│  │ GitHub Actions      │  │ GitHub Actions      │  │ GitHub Actions      │ │
│  │ ┌─────────────────┐ │  │ ┌─────────────────┐ │  │ ┌─────────────────┐ │ │
│  │ │ Security Scan   │ │  │ │ Security Scan   │ │  │ │ Security Scan   │ │ │
│  │ │ - TFLint        │ │  │ │ - Bandit        │ │  │ │ - GoSec         │ │ │
│  │ │ - Checkov       │ │  │ │ - npm audit     │ │  │ │ - Trivy         │ │ │
│  │ │ - TFSec         │ │  │ │ - Trivy         │ │  │ │ - SAST          │ │ │
│  │ └────────┬────────┘ │  │ └────────┬────────┘ │  │ └────────┬────────┘ │ │
│  └──────────┼──────────┘  └──────────┼──────────┘  └──────────┼──────────┘ │
│             │                        │                        │             │
└─────────────┼────────────────────────┼────────────────────────┼─────────────┘
              │                        │                        │
              │    SARIF/JSON Reports  │                        │
              │                        │                        │
              └────────────────────────┼────────────────────────┘
                                       │
                                       ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ AWS Shared Services Account (265245191272)                                   │
│                                                                              │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │ EKS Cluster (Shared Services)                                          │  │
│  │                                                                        │  │
│  │  ┌────────────────────────────────────────────────────────────────┐   │  │
│  │  │ DefectDojo Namespace                                            │   │  │
│  │  │                                                                 │   │  │
│  │  │  ┌─────────────────┐  ┌─────────────────┐  ┌───────────────┐  │   │  │
│  │  │  │ DefectDojo      │  │ PostgreSQL      │  │ Redis         │  │   │  │
│  │  │  │ Application     │  │ (RDS or Pod)    │  │ (ElastiCache  │  │   │  │
│  │  │  │                 │  │                 │  │  or Pod)      │  │   │  │
│  │  │  │ - Web UI        │  │ - Findings DB   │  │ - Session     │  │   │  │
│  │  │  │ - API Server    │  │ - Users/Roles   │  │ - Cache       │  │   │  │
│  │  │  │ - Import Engine │  │ - Audit Logs    │  │ - Celery      │  │   │  │
│  │  │  └─────────────────┘  └─────────────────┘  └───────────────┘  │   │  │
│  │  │           │                                                    │   │  │
│  │  │           │                                                    │   │  │
│  │  │  ┌────────┴───────────────────────────────────────────────┐   │   │  │
│  │  │  │                    Celery Workers                       │   │   │  │
│  │  │  │  - Report import processing                             │   │   │  │
│  │  │  │  - Deduplication                                        │   │   │  │
│  │  │  │  - Notification dispatch                                │   │   │  │
│  │  │  └─────────────────────────────────────────────────────────┘   │   │  │
│  │  │                                                                 │   │  │
│  │  └─────────────────────────────────────────────────────────────────┘   │  │
│  │                                      │                                  │  │
│  │                                      │ ALB Ingress                      │  │
│  │                                      ▼                                  │  │
│  │  ┌─────────────────────────────────────────────────────────────────┐   │  │
│  │  │ Application Load Balancer                                        │   │  │
│  │  │ defectdojo.internal.yourcompany.com                             │   │  │
│  │  └─────────────────────────────────────────────────────────────────┘   │  │
│  │                                                                        │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
                                       │
                                       │
                    ┌──────────────────┼──────────────────┐
                    │                  │                  │
                    ▼                  ▼                  ▼
            ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
            │ Jira        │    │ Slack       │    │ Email       │
            │ Integration │    │ Webhooks    │    │ Alerts      │
            │             │    │             │    │             │
            │ Auto-create │    │ #security   │    │ Weekly      │
            │ tickets     │    │ channel     │    │ digests     │
            └─────────────┘    └─────────────┘    └─────────────┘
```

### Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           DATA FLOW                                          │
└─────────────────────────────────────────────────────────────────────────────┘

Step 1: Scan Execution
───────────────────────────────────────────────────────────────────────────────

  GitHub Actions          Security Tools              Report Generation
  ┌──────────┐           ┌──────────────┐           ┌──────────────────┐
  │ Workflow │──trigger──▶│ TFLint       │──scan────▶│ tflint.sarif     │
  │ Run      │           │ Checkov      │           │ checkov.sarif    │
  │          │           │ TFSec        │           │ tfsec.sarif      │
  └──────────┘           └──────────────┘           └────────┬─────────┘
                                                             │
                                                             ▼
Step 2: Report Upload
───────────────────────────────────────────────────────────────────────────────

  ┌──────────────────┐              ┌──────────────────────────────────────┐
  │ Security Reports │──HTTP POST──▶│ DefectDojo API                       │
  │ (SARIF/JSON)     │              │ POST /api/v2/import-scan/            │
  │                  │              │                                       │
  │ Headers:         │              │ Parameters:                           │
  │ - Authorization  │              │ - scan_type: "SARIF"                  │
  │ - Content-Type   │              │ - product: "landing-zones"            │
  │                  │              │ - engagement: "CI/CD"                 │
  └──────────────────┘              └────────────────┬─────────────────────┘
                                                     │
                                                     ▼
Step 3: Processing
───────────────────────────────────────────────────────────────────────────────

  ┌───────────────────────────────────────────────────────────────────────┐
  │ DefectDojo Processing Pipeline                                        │
  │                                                                       │
  │  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐   ┌──────────┐ │
  │  │ Parse       │──▶│ Deduplicate │──▶│ Risk Score  │──▶│ Store    │ │
  │  │ Report      │   │ Findings    │   │ Calculation │   │ in DB    │ │
  │  │             │   │             │   │             │   │          │ │
  │  │ Extract:    │   │ Match by:   │   │ Based on:   │   │ Create:  │ │
  │  │ - Title     │   │ - Title     │   │ - Severity  │   │ - Finding│ │
  │  │ - Severity  │   │ - File      │   │ - CVSS      │   │ - Audit  │ │
  │  │ - Location  │   │ - Line      │   │ - Asset     │   │   log    │ │
  │  └─────────────┘   └─────────────┘   └─────────────┘   └──────────┘ │
  │                                                                       │
  └───────────────────────────────────────────────────────────────────────┘
                                                     │
                                                     ▼
Step 4: Notification & Action
───────────────────────────────────────────────────────────────────────────────

  ┌───────────────────────────────────────────────────────────────────────┐
  │                                                                       │
  │   ┌─────────────┐       ┌─────────────┐       ┌─────────────┐       │
  │   │ New CRITICAL│──────▶│ Create Jira │──────▶│ Slack Alert │       │
  │   │ Finding     │       │ Ticket      │       │ #security   │       │
  │   └─────────────┘       └─────────────┘       └─────────────┘       │
  │                                                                       │
  │   ┌─────────────┐       ┌─────────────┐       ┌─────────────┐       │
  │   │ SLA Breach  │──────▶│ Escalation  │──────▶│ Email to    │       │
  │   │ Warning     │       │ Workflow    │       │ Security    │       │
  │   └─────────────┘       └─────────────┘       └─────────────┘       │
  │                                                                       │
  └───────────────────────────────────────────────────────────────────────┘
```

### GitHub Actions Integration

```yaml
# Updated workflow to upload to DefectDojo
- name: Upload to DefectDojo
  if: always()
  env:
    DEFECTDOJO_URL: ${{ secrets.DEFECTDOJO_URL }}
    DEFECTDOJO_TOKEN: ${{ secrets.DEFECTDOJO_TOKEN }}
  run: |
    # Upload Checkov results
    curl -X POST "${DEFECTDOJO_URL}/api/v2/import-scan/" \
      -H "Authorization: Token ${DEFECTDOJO_TOKEN}" \
      -H "Content-Type: multipart/form-data" \
      -F "file=@security-reports/results_sarif.sarif" \
      -F "scan_type=SARIF" \
      -F "product_name=landing-zones" \
      -F "engagement_name=CI/CD Pipeline" \
      -F "auto_create_context=true" \
      -F "close_old_findings=false"

    # Upload TFSec results
    curl -X POST "${DEFECTDOJO_URL}/api/v2/import-scan/" \
      -H "Authorization: Token ${DEFECTDOJO_TOKEN}" \
      -F "file=@security-reports/tfsec-results.sarif" \
      -F "scan_type=SARIF" \
      -F "product_name=landing-zones" \
      -F "engagement_name=CI/CD Pipeline"
```

---

## Implementation Phases

### Phase Timeline

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        IMPLEMENTATION ROADMAP                                │
└─────────────────────────────────────────────────────────────────────────────┘

Phase 2 (Current)           Phase 3 (Next Quarter)        Phase 4 (Production)
──────────────────          ────────────────────          ────────────────────

   GitHub-Native                Deploy DefectDojo            Full Integration
   ┌──────────┐                ┌──────────────┐             ┌──────────────┐
   │ TFLint   │                │ DefectDojo   │             │ Multi-repo   │
   │ Checkov  │ ─────────────▶ │ on EKS       │ ──────────▶ │ Aggregation  │
   │ TFSec    │                │              │             │              │
   │          │                │ Basic        │             │ Jira         │
   │ GitHub   │                │ Integration  │             │ Slack        │
   │ Security │                │              │             │ Compliance   │
   └──────────┘                └──────────────┘             └──────────────┘
       │                            │                            │
       │                            │                            │
       ▼                            ▼                            ▼
   MVP Complete                 Beta Testing                 Go-Live
   ✅ Done                      Q1 Next Year                Q2 Next Year
```

### Phase 3: DefectDojo Deployment (Next Quarter)

**Objectives:**
1. Deploy DefectDojo to Shared Services EKS
2. Configure basic authentication (SSO later)
3. Create products and engagements structure
4. Update GitHub Actions to upload reports
5. Validate end-to-end flow

**Prerequisites:**
- [ ] EKS cluster deployed in Shared Services account
- [ ] RDS PostgreSQL or in-cluster PostgreSQL
- [ ] ElastiCache Redis or in-cluster Redis
- [ ] ALB Ingress Controller configured
- [ ] DNS entry for DefectDojo (e.g., defectdojo.internal.yourcompany.com)

**Estimated Resources:**

| Resource | Specification | Monthly Cost |
|----------|---------------|--------------|
| EKS Node | t3.medium (2 vCPU, 4GB) | ~$30 |
| RDS PostgreSQL | db.t3.micro (shared) | ~$15 |
| ElastiCache Redis | cache.t3.micro | ~$12 |
| ALB | Shared with other services | ~$20 |
| **Total** | | **~$75-100/month** |

### Phase 4: Full Integration (Production)

**Objectives:**
1. SSO integration (SAML/OIDC)
2. Jira integration for ticket creation
3. Slack webhook notifications
4. Custom dashboards and reports
5. SLA tracking and escalations
6. Multi-repository aggregation

---

## Tool Comparison

### Why DefectDojo?

| Feature | DefectDojo | GitHub Code Scanning | SonarQube | Snyk |
|---------|------------|---------------------|-----------|------|
| **Cost** | Free (self-hosted) | Free (public) / $49/user (private) | Free Community / $$ Commercial | $$ Per developer |
| **Multi-tool support** | 150+ parsers | Limited to SARIF | Code quality focus | Limited scanners |
| **Self-hosted** | ✅ | ❌ | ✅ | ❌ |
| **Historical trending** | ✅ | Limited | ✅ | ✅ |
| **Risk scoring** | ✅ | Basic | ✅ | ✅ |
| **Jira integration** | ✅ Built-in | Via Actions | ✅ | ✅ |
| **OWASP backed** | ✅ | ❌ | ❌ | ❌ |
| **Kubernetes native** | ✅ Helm chart | N/A | ✅ | SaaS only |
| **Compliance reports** | ✅ | ❌ | Limited | ✅ |
| **API access** | ✅ Full API | ✅ | ✅ | ✅ |

### Recommendation

**For Altanova's ecommerce SaaS platform:**

| Phase | Recommendation | Reasoning |
|-------|----------------|-----------|
| MVP (Now) | GitHub-native | Zero cost, minimal setup |
| Growth | DefectDojo | Self-hosted control, multi-tool support |
| Enterprise | DefectDojo + Commercial add-ons | Scale with business needs |

---

## DefectDojo Configuration

### Product Structure

```
DefectDojo Organization
│
├── Product: altanova-infrastructure (landing-zones)
│   ├── Engagement: CI/CD Pipeline
│   │   ├── Test: TFLint Scan
│   │   ├── Test: Checkov Scan
│   │   └── Test: TFSec Scan
│   │
│   └── Engagement: Manual Reviews
│       └── Test: Architecture Review
│
├── Product: altanova-application
│   ├── Engagement: CI/CD Pipeline
│   │   ├── Test: SAST Scan
│   │   ├── Test: Dependency Check
│   │   └── Test: Container Scan
│   │
│   └── Engagement: Penetration Test
│       └── Test: Annual Pentest 2025
│
└── Product: altanova-microservices
    └── Engagement: CI/CD Pipeline
        ├── Test: Go Security Scan
        └── Test: Container Scan
```

### Severity Mapping

| Tool Finding | DefectDojo Severity | SLA |
|--------------|--------------------| ----|
| CRITICAL | Critical | 24 hours |
| HIGH | High | 7 days |
| MEDIUM | Medium | 30 days |
| LOW | Low | 90 days |
| INFO | Informational | No SLA |

---

## Estimated Costs Summary

### Current (Phase 2)

| Item | Cost |
|------|------|
| GitHub Actions | Free (public repo) |
| GitHub Code Scanning | Free (public repo) |
| **Total** | **$0/month** |

### Future (Phase 3-4)

| Item | Cost |
|------|------|
| DefectDojo (EKS resources) | ~$75-100/month |
| GitHub Actions | Free |
| Development time | 2-3 days initial setup |
| **Total** | **~$100/month** |

### Comparison to Alternatives

| Solution | Monthly Cost (5 developers) |
|----------|----------------------------|
| DefectDojo (self-hosted) | ~$100 |
| GitHub Advanced Security (private) | $245 |
| Snyk | $400+ |
| SonarQube Cloud | $200+ |

---

## Next Steps

### Immediate (This Quarter)
- [x] Phase 2: GitHub-native security scanning
- [ ] Enable GitHub Code Scanning (free for public repo)
- [ ] Monitor and tune security rules
- [ ] Document exception handling process

### Next Quarter
- [ ] Deploy EKS cluster in Shared Services (if not already)
- [ ] Deploy DefectDojo via Helm
- [ ] Configure products and engagements
- [ ] Update GitHub Actions to upload to DefectDojo
- [ ] Validate end-to-end flow

### Future
- [ ] SSO integration
- [ ] Jira integration
- [ ] Slack notifications
- [ ] Custom compliance dashboards
- [ ] Container scanning (Trivy)
- [ ] Runtime security (Falco)

---

## References

- [DefectDojo Documentation](https://defectdojo.github.io/django-DefectDojo/)
- [DefectDojo Helm Chart](https://github.com/DefectDojo/django-DefectDojo/tree/master/helm/defectdojo)
- [DefectDojo API](https://defectdojo.github.io/django-DefectDojo/integrations/api-v2-docs/)
- [SARIF Specification](https://sarifweb.azurewebsites.net/)
- [OWASP DefectDojo Project](https://owasp.org/www-project-defectdojo/)

---

**Document Owner:** Infrastructure Team
**Last Updated:** 2025-12-04
**Version:** 1.0.0
**Next Review:** After Phase 3 implementation
