# Interview Questions by Module

## Quick Reference: Top 20 Questions Clients Ask

1. Explain the difference between blue-green and canary deployment
2. How do you manage Terraform state in a team environment?
3. What is a Managed Identity and why is it better than a service principal secret?
4. Walk me through a CI/CD pipeline you've designed
5. How do you handle database migrations in a zero-downtime deployment?
6. What are DORA metrics and what do they measure?
7. Explain the difference between AKS, Container Apps, and ACI
8. How do you secure secrets in Azure DevOps pipelines?
9. What is Azure Policy and how do you use it for governance?
10. Explain Terraform modules and when you'd create one
11. How do you implement auto-scaling in Azure?
12. What is the difference between Azure Monitor and Application Insights?
13. How do you implement a multi-region architecture in Azure?
14. What is GitOps and how does Flux work?
15. How do you handle Terraform state corruption?
16. Explain the OAuth 2.0 client credentials flow
17. What is the expand-contract pattern for database migrations?
18. How do you implement rate limiting in Azure API Management?
19. What security scanning tools do you use in CI/CD pipelines?
20. How do you right-size Azure resources for cost optimization?

---

## Module-by-Module Question Bank

### Azure App Service
- What App Service Plan tier would you choose for a production app needing auto-scale and VNet integration?
- How do deployment slots work and what are slot-specific settings?
- When would you use Azure Functions Premium plan vs Consumption?
- How do you diagnose high response times in App Service?
- What is `applicationInitialization` and why does it matter for slot swaps?

### Azure SQL + Containers
- What is the difference between TDE and Always Encrypted?
- How do failover groups differ from active geo-replication?
- When would you choose Container Apps over AKS?
- How do you implement traffic splitting between Container App revisions?
- What is Dynamic Data Masking and what are its limitations?

### Auth + API Management
- Explain the difference between system-assigned and user-assigned Managed Identity
- How do you implement JWT validation in APIM?
- What is the difference between APIM `rate-limit` and `quota` policies?
- How do you reference Key Vault secrets in APIM named values?
- What OAuth 2.0 flow does a background service use?

### DevOps Fundamentals
- What are the four DORA metrics?
- Compare trunk-based development with GitFlow
- How do you configure branch policies in Azure DevOps?
- What is a blameless post-mortem?
- How do you measure and manage technical debt?

### CI/CD Pipelines
- What is the difference between CI, CD (Delivery), and CD (Deployment)?
- How do you implement OIDC authentication in GitHub Actions?
- What is artifact immutability and why does it matter?
- How do you implement approval gates in Azure Pipelines?
- How do you speed up a slow CI pipeline?

### Release Strategies
- When would you choose blue-green over canary?
- How do you handle database migrations in blue-green deployments?
- What metrics should trigger an automated canary rollback?
- What is a feature flag kill switch?
- Explain the expand-contract pattern

### Terraform Basics
- What is Terraform state and why is remote state important?
- What does `terraform plan` do and why should you always run it first?
- How do you migrate from local to remote state without destroying resources?
- What is state locking and how does Azure Storage implement it?
- When would you use `terraform state rm`?

### Terraform Advanced
- When would you use `for_each` vs `count`?
- What is the purpose of `outputs.tf` in a module?
- How do you handle breaking changes in a shared Terraform module?
- What is a data source and when would you use it?
- Why should you avoid Terraform provisioners?

### Azure Infrastructure with Terraform
- How do you size AKS node pools?
- What is the difference between Azure CNI and kubenet networking?
- Why use `ignore_changes = [instances]` on a VMSS?
- How do you implement a private AKS cluster?
- What is the Key Vault CSI driver?

### Security and Compliance
- What does "shift-left security" mean?
- What is the difference between Checkov and Trivy?
- How do you respond to a Defender for Cloud security alert?
- What Azure Policy effects are available and when do you use each?
- How do you improve Azure Security Score quickly?

---

## Scenario-Based Questions (Most Common in Client Interviews)

**Scenario 1**: "Our app is down in production. Walk me through your incident response."
Key points: Immediate mitigation first (scale out, rollback), then investigate, then fix root cause, then post-mortem.

**Scenario 2**: "We need to deploy a critical update with zero downtime. How do you do it?"
Key points: Blue-green with deployment slots, backward-compatible DB migration, smoke tests, approval gate, rollback plan.

**Scenario 3**: "Our Terraform state is locked and the pipeline crashed. What do you do?"
Key points: Verify no active process, `terraform force-unlock`, verify state consistency with `terraform plan`.

**Scenario 4**: "A developer committed a service principal secret to GitHub. What do you do?"
Key points: Rotate immediately, check audit logs, clean git history, implement OIDC to prevent recurrence.

**Scenario 5**: "Our Azure costs are 40% over budget. How do you reduce them?"
Key points: Right-size (check utilization), Reserved Instances, scale-in during off-hours, move batch jobs to Functions, dev/test pricing.
