# Decision Matrices

## Container Service Selection

| Requirement | ACI | Container Apps | AKS |
|-------------|-----|----------------|-----|
| One-off batch jobs | ✅ Best | ✅ | ❌ Overkill |
| Microservices | ❌ | ✅ Best | ✅ |
| Scale to zero | ❌ | ✅ | With KEDA |
| Full K8s control | ❌ | ❌ | ✅ |
| Dapr built-in | ❌ | ✅ | Manual |
| GPU workloads | ❌ | ❌ | ✅ |
| Operational complexity | Low | Low-Med | High |
| Cost at idle | Per-second | Near-zero | Node cost |

**Rule of thumb**: ACI for jobs, Container Apps for microservices, AKS when you need full Kubernetes.

---

## Azure SQL Purchasing Model

| Factor | DTU | vCore |
|--------|-----|-------|
| Simplicity | ✅ Simple | ❌ More options |
| SQL Server license | ❌ Not applicable | ✅ Hybrid Benefit (55% savings) |
| Independent CPU/memory scaling | ❌ | ✅ |
| Hyperscale tier | ❌ | ✅ |
| Business Critical tier | ❌ | ✅ |
| Best for | Small/simple workloads | Production enterprise |

---

## Deployment Strategy Selection

| Scenario | Strategy |
|----------|----------|
| Simple update, can tolerate brief downtime | Rolling |
| Zero downtime, instant rollback needed | Blue-Green |
| Validate with real traffic before full rollout | Canary |
| Test hypothesis with user segments | A/B Testing |
| Decouple release from deployment | Feature Flags |
| Breaking change, database migration | Blue-Green + Expand-Contract |

---

## App Service Plan Tier Selection

| Requirement | Minimum Tier |
|-------------|-------------|
| Dev/test only | Free/Basic |
| Auto-scaling | Standard |
| Deployment slots (> 5) | Premium v3 |
| VNet integration | Standard (limited) / Premium v3 (full) |
| Network isolation (compliance) | Isolated v2 (ASE) |
| Azure Functions, no cold starts | Premium (EP1+) |

---

## Terraform State Backend Selection

| Scenario | Backend |
|----------|---------|
| Solo developer, learning | Local |
| Team of 2+ | Azure Storage (remote) |
| Enterprise, audit requirements | Terraform Cloud / Azure Storage |
| Multi-cloud | Terraform Cloud |

---

## Monitoring Tool Selection

| Need | Tool |
|------|------|
| Application performance, traces | Application Insights |
| Infrastructure metrics | Azure Monitor Metrics |
| Log aggregation and queries | Log Analytics (KQL) |
| Security events | Microsoft Sentinel |
| Container metrics | Container Insights |
| Availability testing | Application Insights Web Tests |
