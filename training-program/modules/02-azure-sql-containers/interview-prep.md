# Module 2: Azure SQL + Containers — Interview Preparation

## Q1 (Conceptual): Azure SQL Service Tiers
**Question**: Compare DTU-based and vCore-based purchasing models. When would you choose each?

**Sample Answer**:
DTU (Database Transaction Unit) bundles CPU, memory, and I/O into a single metric. It's simpler to reason about for small workloads but gives you no control over individual resource dimensions. vCore lets you independently scale CPU and memory, choose hardware generation, and use Azure Hybrid Benefit to apply existing SQL Server licenses (saving up to 55%).

Choose DTU for: small dev/test databases, simple workloads under 100 DTUs, when you don't need fine-grained control.
Choose vCore for: production workloads, when you have SQL Server licenses (Hybrid Benefit), when you need predictable performance, or when you need Hyperscale or Business Critical tiers.

For enterprise production, I always recommend vCore General Purpose or Business Critical — the transparency and Hybrid Benefit savings justify it.

**Follow-ups**: What is the Hyperscale tier and when would you use it? How does serverless vCore differ from provisioned?

---

## Q2 (Scenario): Zero-Downtime Database Migration
**Question**: A client needs to migrate a 2TB on-premises SQL Server database to Azure SQL with less than 1 hour of downtime. Walk through your approach.

**Sample Answer**:
I'd use Azure Database Migration Service (DMS) in online migration mode:

1. Pre-migration: Run Database Experimentation Assistant (DEA) to identify compatibility issues. Fix any blocking issues (deprecated features, unsupported syntax).
2. Create target Azure SQL Managed Instance (for full SQL Server compatibility) or Azure SQL Database.
3. Configure DMS online migration — it does a full backup/restore then continuously applies transaction log changes.
4. Run parallel validation: run the application against both databases, compare query results.
5. Cutover window (< 1 hour): stop writes to source, let DMS drain remaining log changes, update connection strings, redirect traffic.
6. Monitor for 24 hours, keep source as fallback.

Key risk: schema differences between SQL Server and Azure SQL. Always test with DEA first.

**Follow-ups**: What's the difference between Azure SQL Database and Azure SQL Managed Instance? When would you choose Managed Instance?

---

## Q3 (Troubleshooting): High DTU/CPU on Azure SQL
**Question**: A production Azure SQL Database is hitting 90% DTU consistently. Users are experiencing slow queries. What do you do?

**Sample Answer**:
First, I'd check Query Performance Insight in the Azure portal — it shows the top resource-consuming queries over time. Then:

1. Identify the top 5 queries by CPU/duration in Query Store
2. Check for missing indexes using `sys.dm_db_missing_index_details`
3. Check for blocking/deadlocks in `sys.dm_exec_requests` and Extended Events
4. Look for parameter sniffing issues — queries with wildly different execution plans

Immediate mitigation: scale up to the next DTU/vCore tier (takes ~5 minutes with no downtime on General Purpose).

Long-term: add missing indexes, rewrite inefficient queries, implement read replicas for reporting workloads, consider elastic pools if multiple databases are involved.

**Follow-ups**: What is Query Store and how does it help with performance troubleshooting? How do read replicas work in Azure SQL?

---

## Q4 (Design): Container Service Selection
**Question**: A client asks you to choose between ACI, Container Apps, and AKS for their microservices platform. How do you decide?

**Sample Answer**:
I use a decision matrix based on complexity, scale, and operational overhead:

| Requirement | ACI | Container Apps | AKS |
|-------------|-----|----------------|-----|
| Simple one-off tasks | ✅ | ✅ | ❌ (overkill) |
| Microservices with auto-scale | ❌ | ✅ | ✅ |
| Scale to zero | ❌ | ✅ | With KEDA |
| Full Kubernetes control | ❌ | ❌ | ✅ |
| Dapr/service mesh | ❌ | ✅ (built-in) | ✅ (manual) |
| GPU workloads | ❌ | ❌ | ✅ |
| Operational complexity | Low | Low-Medium | High |

My recommendation framework:
- **ACI**: Batch jobs, CI/CD agents, simple isolated containers. Not for long-running services.
- **Container Apps**: Microservices that need auto-scale, scale-to-zero, Dapr, event-driven scaling. Best for most enterprise microservices.
- **AKS**: When you need full Kubernetes control, custom operators, GPU nodes, or have an existing Kubernetes expertise.

For most new microservices projects, I start with Container Apps — it removes 80% of the Kubernetes operational burden while still providing enterprise-grade scaling.

**Follow-ups**: What is KEDA and how does it work with Container Apps? How would you handle secrets in Container Apps?

---

## Q5 (Security): Securing Azure SQL in Production
**Question**: What security controls would you implement for a production Azure SQL database handling financial data?

**Sample Answer**:
Defense in depth — multiple layers:

**Network**: Private endpoint only, no public access. NSG rules restrict access to the subnet. Azure Firewall for outbound inspection.

**Authentication**: Azure AD authentication only — no SQL logins. Service principals and Managed Identities for applications. No shared accounts.

**Encryption**: TDE enabled (default). Always Encrypted for the most sensitive columns (SSN, credit card) — encrypted client-side, Azure never sees plaintext. TLS 1.2 minimum for connections.

**Data masking**: Dynamic Data Masking for non-privileged users — they see `XXXX-XXXX` instead of actual card numbers.

**Auditing**: All queries logged to Log Analytics. Retention: 90 days hot, 1 year cold (Azure Storage).

**Threat detection**: Microsoft Defender for SQL — alerts on SQL injection attempts, anomalous access patterns, brute force.

**Access control**: Least privilege — app service account has only SELECT/INSERT/UPDATE on specific tables. No db_owner for application accounts.

**Follow-ups**: What's the difference between Dynamic Data Masking and Always Encrypted? When would you use each?

---

## Q6 (Design): Multi-Region Container Architecture
**Question**: Design a container architecture for a globally distributed application serving users in US, Europe, and Asia with < 100ms latency.

**Sample Answer**:
I'd use Azure Front Door + AKS in three regions:

- Azure Front Door Premium: global anycast routing, WAF, health probes. Routes users to nearest healthy region.
- AKS clusters in East US 2, West Europe, Southeast Asia: identical deployments via GitOps (Flux).
- ACR with geo-replication: images replicated to all three regions, AKS pulls from local replica.
- Azure SQL with active geo-replication: primary in East US 2, readable secondaries in West Europe and Southeast Asia for read queries.
- Azure Cache for Redis (geo-replication): session state and cache replicated across regions.

Deployment strategy: GitOps with Flux. A single git push triggers deployment to all three regions sequentially (US → Europe → Asia) with automated rollback if health checks fail.

Cost consideration: running three AKS clusters is expensive. For cost optimization, use spot node pools for non-critical workloads and right-size node pools based on actual utilization.

**Follow-ups**: How would you handle database writes in a multi-region active-active setup? What consistency model would you choose?
