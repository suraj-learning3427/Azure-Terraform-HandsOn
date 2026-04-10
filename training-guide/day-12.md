# Day 12 — Apr 30 | Capstone Review + Interview Preparation
**Presenters**: Lini & Karthik

---

## What You'll Do Today
- Complete POC 5 and validate end-to-end
- Review all key concepts
- Practice the top interview questions
- Mock interview scenarios

---

## Part 1: POC 5 Completion Checklist

Go through each item and verify:

```bash
# 1. Infrastructure
terraform -chdir=terraform show | grep -E "azurerm_kubernetes_cluster|azurerm_application_gateway|azurerm_mssql_server|azurerm_redis_cache"

# 2. AKS cluster healthy
kubectl get nodes
kubectl get pods -n production

# 3. GitOps synced
flux get kustomizations
flux get helmreleases -A

# 4. End-to-end request
AGW_IP=$(az network public-ip show --name pip-agw-poc5-prod --resource-group rg-poc5-prod --query ipAddress -o tsv)
curl -v http://$AGW_IP/api/health

# 5. Secrets mounted
kubectl exec -n production deploy/myapp-api -- ls /mnt/secrets/

# 6. Monitoring active
az monitor app-insights component show --app appi-poc5-prod --resource-group rg-poc5-prod --query provisioningState -o tsv
```

---

## Part 2: Complete Concept Review

### Azure Services Quick Reference

| Service | Key Points | Common Interview Topics |
|---------|-----------|------------------------|
| App Service | Plans (Free→Isolated), slots, auto-scale, Managed Identity | Tier selection, slot-specific settings, cold starts |
| Azure SQL | vCore vs DTU, TDE, DDM, Always Encrypted, failover groups | Encryption differences, HA options, private endpoints |
| Container Apps | Scale-to-zero, traffic splitting, Dapr, KEDA | vs ACI vs AKS decision |
| AKS | System/user node pools, Azure CNI, RBAC, autoscaler | Node sizing, private cluster, CSI driver |
| Key Vault | RBAC vs access policies, Managed Identity, Key Vault references | Secret rotation, federated identity |
| APIM | Policy pipeline, JWT validation, rate limiting | Policy order, debugging 401s |
| Azure Policy | Audit/Deny/DeployIfNotExists/Modify | Effect selection, compliance reporting |
| Terraform | State, modules, for_each, lifecycle | State management, count vs for_each |

### The 5 Most Important Concepts

**1. Managed Identity** — Never store credentials. Use Managed Identity for all Azure resource authentication.

**2. Remote State** — Always use Azure Storage backend for Terraform in teams. State locking prevents conflicts.

**3. Deployment Slots** — Zero-downtime deployments. Slot-specific settings stay with the slot.

**4. DORA Metrics** — Deployment Frequency, Lead Time, Change Failure Rate, Time to Restore. Know these cold.

**5. Shift-Left Security** — Security at every stage: IDE → pre-commit → PR → CI → staging → production.

---

## Part 3: Top 25 Interview Questions

### Azure DevOps & CI/CD

**Q1: Walk me through a CI/CD pipeline you've designed.**
Structure your answer: trigger → build → test (with coverage) → security scan → artifact → deploy to staging → approval → deploy to production. Mention: OIDC auth, quality gates, rollback plan.

**Q2: How do you implement zero-downtime deployments?**
App Service deployment slots: deploy to staging → smoke test → canary 10% → approval → swap to production. Rollback: swap back in < 30 seconds.

**Q3: What are DORA metrics and what do they measure?**
Deployment Frequency, Lead Time for Changes, Change Failure Rate, Time to Restore. Elite: multiple deploys/day, < 1 hour lead time, < 5% failure rate, < 1 hour recovery.

**Q4: How do you secure secrets in Azure DevOps pipelines?**
Variable groups linked to Key Vault. OIDC federated identity (no stored service principal secrets). Never store secrets in pipeline YAML. Secret scanning in CI.

**Q5: What is the difference between blue-green and canary?**
Blue-green: atomic switch, instant rollback, full traffic shift. Canary: gradual traffic shift (5%→25%→100%), validate with real traffic, automated rollback on metric breach.

### Terraform

**Q6: What is Terraform state and why is remote state important?**
State maps config to real resources. Remote state (Azure Storage) enables team collaboration, state locking, and shared source of truth.

**Q7: When would you use `for_each` vs `count`?**
`for_each` almost always — stable keys, removing one item only affects that resource. `count` only for optional resources (`count = var.enabled ? 1 : 0`).

**Q8: How do you structure Terraform for multiple environments?**
Separate directories per environment, each with own state file. Shared logic in modules. Never use workspaces for environment isolation.

**Q9: What does `prevent_destroy` do?**
Causes `terraform destroy` and any plan that would destroy the resource to fail. Use on critical resources: databases, Key Vaults, storage accounts.

**Q10: How do you handle a stuck Terraform state lock?**
Verify no active process → `terraform force-unlock <lock-id>` → `terraform plan` to verify consistency.

### Azure Architecture

**Q11: When would you choose Container Apps over AKS?**
Container Apps for most microservices — removes 80% of K8s overhead, built-in scale-to-zero, Dapr, traffic splitting. AKS when you need full K8s control, GPU nodes, or custom operators.

**Q12: What is the difference between TDE and Always Encrypted?**
TDE: storage-level encryption, DB engine sees plaintext. Always Encrypted: client-side, DB engine never sees plaintext. Use TDE always (default). Use Always Encrypted for most sensitive columns (SSN, credit card).

**Q13: How do you design a multi-region architecture?**
Azure Front Door → App Service/AKS in 2+ regions → SQL failover groups → Redis geo-replication. RTO < 2 minutes, RPO < 5 seconds.

**Q14: What is a private endpoint?**
A network interface in your VNet with a private IP that connects to an Azure service (SQL, Storage, Key Vault). The service is accessible only from your VNet — no public internet access. Required for production databases and Key Vaults.

**Q15: How do you implement auto-scaling in Azure?**
App Service: `az monitor autoscale create` with CPU-based rules (scale out > 70%, scale in < 30%). AKS: Cluster Autoscaler for nodes + HPA for pods. VMSS: `azurerm_monitor_autoscale_setting` in Terraform.

### Security

**Q16: What is Managed Identity and why is it better than service principal secrets?**
Managed Identity: Azure manages credentials automatically, you never see them. Service principal: you manage credentials, must rotate. Always use Managed Identity when available.

**Q17: What is OIDC and why use it for pipelines?**
Short-lived tokens from identity provider — no stored credentials. Azure trusts GitHub/Azure DevOps OIDC issuer. No secrets to rotate or leak.

**Q18: What is shift-left security?**
Moving security checks earlier: IDE → pre-commit → PR → CI → staging → production. Cheaper to fix in development than production.

**Q19: What Azure Policy effects are available?**
Audit (log), Deny (block), DeployIfNotExists (auto-remediate), Modify (auto-fix properties).

**Q20: How do you respond to a security incident?**
Isolate → preserve evidence → investigate → determine scope → remediate → post-mortem → improve.

### Architecture Design

**Q21: Design a highly available web application on Azure.**
Front Door → App Service Premium v3 (multi-region, auto-scale) → SQL failover group → Redis geo-replication. 99.99% SLA.

**Q22: How do you handle database migrations in zero-downtime deployments?**
Expand-contract pattern: add nullable column → deploy new code → add NOT NULL constraint. 3 deployments, safe rollback at each step.

**Q23: What is GitOps?**
Git as single source of truth for cluster state. Flux/ArgoCD continuously reconciles cluster to match Git. Every change is a git commit — full audit trail, easy rollback.

**Q24: How do you reduce Azure costs by 40%?**
Right-size (check utilization) → Reserved Instances (35-55% savings) → scale-in during off-hours → move batch jobs to Functions → dev/test pricing.

**Q25: What is the expand-contract pattern?**
3-phase backward-compatible DB migration: Expand (add nullable column) → Deploy (new code writes to new column) → Contract (add NOT NULL, remove old code). Ensures zero downtime and safe rollback.

---

## Part 4: Mock Interview Scenarios

### Scenario 1: "Our app is down in production."
**Your answer structure**:
1. Immediate mitigation: scale out, check if rollback is needed
2. Investigate: Application Insights → Failures, check recent deployments
3. Communicate: update status page, notify stakeholders
4. Fix root cause
5. Post-mortem

### Scenario 2: "Design a CI/CD pipeline for a financial services client."
**Your answer structure**:
1. Source control: GitHub with branch protection (2 approvals, signed commits)
2. CI: build → unit tests (80% coverage) → SAST → dependency scan → container scan → IaC scan
3. CD: staging (auto) → approval gate → production (blue-green with canary)
4. Security: OIDC auth, Key Vault for secrets, no stored credentials
5. Compliance: audit trail, change management integration

### Scenario 3: "Terraform plan shows production database will be destroyed."
**Your answer structure**:
1. Don't apply — stop immediately
2. Understand why: check which attribute changed, check provider changelog
3. Options: `ignore_changes`, `prevent_destroy`, manual fix
4. Add `prevent_destroy = true` as safety net going forward

---

## Final Checklist — Are You Interview Ready?

- [ ] Can explain DORA metrics without hesitation
- [ ] Can design a 3-tier architecture on a whiteboard
- [ ] Can explain blue-green vs canary with examples
- [ ] Can write basic Terraform HCL from memory
- [ ] Can explain Managed Identity and why it's better than passwords
- [ ] Can walk through a CI/CD pipeline end-to-end
- [ ] Can explain Terraform state and remote backends
- [ ] Can describe shift-left security with specific tools
- [ ] Can answer "how do you reduce Azure costs?" with concrete strategies
- [ ] Have STAR stories ready from the POCs you built

**Good luck with the client interview!**
