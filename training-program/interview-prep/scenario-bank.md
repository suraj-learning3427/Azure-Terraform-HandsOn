# Scenario Bank — Troubleshooting and Design

## Troubleshooting Scenarios

### Scenario T1: App Service 503 Errors
**Situation**: Production app returning 503 errors intermittently. `HttpQueueLength` metric is 800.
**Diagnosis**: App can't process requests fast enough — queue backing up.
**Resolution**: 1) Scale out immediately. 2) Check auto-scale — is it configured? Is it triggering? 3) Check Application Insights for slow operations. 4) Check database query performance. 5) Look for thread pool starvation (sync-over-async).

### Scenario T2: AKS Pods Stuck in Pending
**Situation**: New deployment pods stuck in Pending state.
**Diagnosis**: `kubectl describe pod` → check Events section.
**Common causes**: Insufficient CPU/memory (autoscaler should add nodes), node selector mismatch, taint/toleration mismatch, PVC not bound.
**Resolution**: Check autoscaler logs, verify node labels, check resource requests vs. available capacity.

### Scenario T3: Terraform Plan Shows Unexpected Destroy
**Situation**: `terraform plan` shows production database will be destroyed.
**Diagnosis**: Check which attribute changed. Common causes: provider upgrade, manual change in Azure (drift), required attribute added.
**Resolution**: Don't apply. Understand why. Use `ignore_changes` for drifted attributes. Add `prevent_destroy = true`.

### Scenario T4: Pipeline Failing on Secret Access
**Situation**: Azure Pipelines job fails with "Access denied" when reading Key Vault secret.
**Diagnosis**: Service connection identity doesn't have Key Vault Secrets User role.
**Resolution**: Get the service connection's service principal object ID. Assign `Key Vault Secrets User` role on the Key Vault. Verify RBAC authorization is enabled on the vault (not access policies).

### Scenario T5: Canary Showing Higher Error Rate
**Situation**: Canary deployment shows 5% error rate vs. 0.1% for stable.
**Diagnosis**: Is it a real bug or traffic distribution issue?
**Resolution**: 1) Check Application Insights — filter by `cloud_RoleInstance` to compare same endpoints. 2) Check if canary is getting disproportionate complex requests. 3) If real bug: roll back immediately (`az webapp traffic-routing clear`). 4) Fix bug, redeploy.

---

## Design Scenarios

### Scenario D1: Design a Highly Available Web Application
**Requirements**: 99.99% SLA, < 100ms latency globally, handle 100K concurrent users.
**Solution**: Azure Front Door Premium → App Service Premium v3 (multi-region) → Azure SQL with failover groups → Azure Cache for Redis. Auto-scale: 2-50 instances per region. Pre-scale for known events.

### Scenario D2: Design a Secure CI/CD Pipeline for Financial Services
**Requirements**: SOX compliance, all changes reviewed, no stored credentials, security scanning.
**Solution**: GitHub with branch protection (2 approvals, signed commits) → GitHub Actions with OIDC → SonarCloud + Trivy + Checkov → Azure DevOps environments with approval gates → Terraform with remote state → Key Vault for all secrets.

### Scenario D3: Design a Cost-Optimized Development Environment
**Requirements**: Dev environment for 10 developers, minimize cost, auto-shutdown nights/weekends.
**Solution**: Basic App Service Plan (not Premium), Azure Dev/Test subscription pricing, auto-shutdown VMs at 7pm, scale to 0 for Container Apps, Consumption plan for Functions, shared Key Vault and Log Analytics.

### Scenario D4: Migrate Monolith to Microservices
**Requirements**: Gradually decompose a monolith without big-bang rewrite.
**Solution**: Strangler Fig pattern — new features as microservices in Container Apps, APIM as gateway routing to both old and new, feature flags to control traffic, shared database initially then migrate to database-per-service over time.

---

## Common Interview Mistakes to Avoid

1. **Saying "it depends" without explaining what it depends on** — always give a concrete recommendation with conditions
2. **Not mentioning security** — every architecture question should include security considerations
3. **Ignoring cost** — always mention cost implications of your design choices
4. **Not knowing DORA metrics** — these come up in almost every DevOps interview
5. **Confusing blue-green and canary** — know the exact difference and when to use each
6. **Not knowing Terraform state** — state management is a core Terraform interview topic
7. **Saying "I'd use Kubernetes for everything"** — know when AKS is overkill vs. Container Apps
8. **Not having a rollback plan** — every deployment design should include rollback
