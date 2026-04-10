# Training Schedule: April 7–30, 2026

## Overview
- Duration: 12 training days (weekdays only, Apr 7–30)
- Daily structure: 5.5 hours (theory + problem statements + hands-on POC)
- Presenters: Varsha, Gowtham, Lini, Karthik, Thulasi, Swaroop, Sabari, Shruthi, Suraj, Joby, Vijay, Manju, Murali, Venkat

---

## Schedule

| Date | Day | Presenters | Azure DevOps Module | Terraform Module | POC |
|------|-----|------------|---------------------|------------------|-----|
| Apr 7 | Mon | Varsha & Gowtham | M1: Azure App Service | M7: Terraform Basics | POC 1 (start) |
| Apr 8 | Tue | Lini & Karthik | M2: Azure SQL + Containers | M7: Terraform Basics (cont.) | POC 1 (complete) |
| Apr 9 | Wed | Thulasi & Swaroop | M3: Auth + APIM | M8: Terraform Advanced | — |
| Apr 14 | Mon | Sabari & Shruthi | M4: DevOps Fundamentals | M8: Terraform Advanced (cont.) | POC 2 (start) |
| Apr 15 | Tue | Suraj & Joby | M5: CI/CD Pipelines | M9: Azure Infra with Terraform | POC 2 (complete) |
| Apr 16 | Wed | Varsha & Gowtham | M5: CI/CD Pipelines (cont.) | — | — |
| Apr 21 | Mon | Vijay & Manju | M6: Release Strategies | M9: Azure Infra (cont.) | POC 3 (start) |
| Apr 22 | Tue | Murali & Venkat | M6: Release Strategies (cont.) | — | POC 3 (complete) |
| Apr 23 | Wed | Sabari & Shruthi | M10: Security + Compliance | — | — |
| Apr 28 | Mon | Vijay & Manju | M10: Security (cont.) | — | POC 4 (start) |
| Apr 29 | Tue | Suraj & Joby | Capstone Review | — | POC 5 (start) |
| Apr 30 | Wed | Lini & Karthik | Interview Prep + Final Review | — | POC 5 (complete) |

---

## Daily Structure (5.5 hours)

| Time | Activity |
|------|----------|
| 0:00–0:30 | Recap of previous session, Q&A |
| 0:30–2:00 | Theory delivery with live demos |
| 2:00–2:15 | Break |
| 2:15–3:00 | Problem statement discussion and design exercise |
| 3:00–5:00 | Hands-on POC implementation |
| 5:00–5:30 | Validation, debrief, preview of next session |

---

## Daily Learning Objectives

### Apr 7 — Azure App Service + Terraform Basics
- Select appropriate App Service Plan tier for production workloads
- Configure deployment slots and perform slot swaps
- Configure metric-based auto-scaling
- Write basic Terraform HCL with variables, locals, and outputs
- Configure Azure Storage remote state backend

### Apr 8 — Azure SQL + Containers + Terraform Basics
- Configure Azure SQL with TDE, Dynamic Data Masking, and failover groups
- Choose between ACI, Container Apps, and AKS for a given scenario
- Deploy multi-container application with traffic splitting
- Complete POC 1: App + SQL + Networking with remote state

### Apr 9 — Auth + APIM + Terraform Advanced
- Implement Managed Identity for Azure resource authentication
- Configure Key Vault with RBAC and Key Vault references
- Implement JWT validation and rate limiting in APIM
- Create reusable Terraform modules with dynamic blocks

### Apr 14 — DevOps Fundamentals + Terraform Advanced
- Configure Azure DevOps branch policies and PR automation
- Explain DORA metrics and how to improve them
- Create Terraform modules with for_each and data sources
- Start POC 2: CI Pipeline + VMSS infrastructure

### Apr 15 — CI/CD Pipelines + Azure Infra with Terraform
- Create multi-stage Azure Pipelines YAML with quality gates
- Implement OIDC authentication for GitHub Actions
- Deploy AKS cluster and VMSS with Terraform
- Complete POC 2: CI pipeline running green

### Apr 16 — CI/CD Pipelines Deep Dive
- Implement pipeline templates for DRY pipelines
- Configure approval gates and deployment environments
- Implement security scanning (Trivy, Checkov, SonarCloud) in pipelines

### Apr 21 — Release Strategies + AKS
- Implement blue-green deployment with App Service slots
- Configure canary traffic routing with automated rollback
- Deploy AKS with Application Gateway ingress
- Start POC 3: Full CI/CD with slots and AKS

### Apr 22 — Release Strategies + POC 3
- Implement feature flags with Azure App Configuration
- Configure A/B testing with Application Insights metrics
- Complete POC 3: Canary deployment working end-to-end

### Apr 23 — Security and Compliance
- Implement security scanning in CI/CD pipelines
- Configure Azure Policy for governance
- Set up Log Analytics and Application Insights alerts

### Apr 28 — Security + POC 4
- Configure OIDC federated identity for pipelines
- Implement Azure Policy initiative at subscription level
- Start POC 4: Full pipeline with Key Vault + Policy + Monitor

### Apr 29 — Capstone + POC 5
- Review all modules and connect concepts
- Start POC 5: 3-tier architecture with AKS GitOps
- Practice whiteboarding architecture designs

### Apr 30 — Final Review + Interview Prep
- Complete POC 5: GitOps sync working end-to-end
- Mock interview practice with scenario questions
- Review top 20 interview questions
- Q&A and final preparation

---

## Prerequisites (Complete Before Apr 7)

- [ ] Azure subscription with Contributor access
- [ ] Azure CLI installed and authenticated (`az login`)
- [ ] Terraform >= 1.5.0 installed
- [ ] kubectl installed
- [ ] Helm >= 3.0 installed
- [ ] Azure DevOps organization created
- [ ] GitHub account with access to organization
- [ ] SonarCloud account linked to GitHub
- [ ] VS Code with Azure Tools extension pack

---

## Interview Preparation Timeline

| Week | Focus |
|------|-------|
| Apr 7–9 | Foundation concepts: App Service, SQL, Auth, Terraform basics |
| Apr 14–16 | DevOps practices: Git, CI/CD, pipelines |
| Apr 21–23 | Advanced topics: Release strategies, AKS, security |
| Apr 28–30 | Integration + interview prep: capstone POC, mock interviews |

**Final week (Apr 28–30)**: Focus on scenario-based questions, whiteboarding, and STAR stories from POC implementations.
