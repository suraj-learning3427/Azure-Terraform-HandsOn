# Module 2: Azure SQL + Containers — Assessment

## Knowledge Check Questions

**Q1**: What is the difference between Transparent Data Encryption (TDE) and Always Encrypted?
**Answer**: TDE encrypts data at rest at the storage level — Azure handles encryption/decryption transparently. The database engine sees plaintext. Always Encrypted encrypts data client-side — the database engine never sees plaintext, only the client application with the column master key can decrypt. Use TDE for general encryption compliance; use Always Encrypted for the most sensitive columns where even DBAs should not see plaintext.

**Q2**: A Container App is receiving 1000 requests/minute but only 2 replicas are running. How do you configure it to scale automatically?
**Answer**: Configure a scaling rule using HTTP concurrent requests trigger. Set `minReplicas: 1`, `maxReplicas: 20`, and an HTTP scaling rule with `concurrentRequests: 50`. Container Apps uses KEDA under the hood. With 1000 req/min and 50 concurrent requests per replica, it will scale to ~20 replicas automatically.

**Q3**: What is an ACR Task and when would you use it?
**Answer**: ACR Tasks automate container image builds triggered by git commits, base image updates, or schedules. Use them to: automatically rebuild images when source code changes (CI), automatically rebuild when a base image (e.g., `mcr.microsoft.com/dotnet/aspnet:8.0`) is updated (security patching), or run multi-step tasks (build → test → push).

**Q4**: What is a failover group in Azure SQL and how does it differ from active geo-replication?
**Answer**: Active geo-replication creates readable secondary replicas in up to 4 regions — you manage failover manually. A failover group wraps geo-replication with an automatic failover policy and provides a single read-write listener endpoint that automatically redirects to the new primary after failover. Failover groups are preferred for production because the connection string doesn't change after failover.

**Q5**: What is the difference between Azure Container Instances and Azure Container Apps?
**Answer**: ACI runs a single container or container group — no auto-scaling, no service discovery, no ingress management. It's for short-lived, isolated workloads (batch jobs, CI agents). Container Apps is a fully managed microservices platform built on Kubernetes + KEDA + Dapr — it provides auto-scaling (including scale-to-zero), built-in ingress, service discovery, traffic splitting, and Dapr integration. Use ACI for simple one-off tasks; use Container Apps for production microservices.

---

## Practical Tasks

### Task 1: Deploy Azure SQL with Security Controls
Deploy an Azure SQL Database with TDE, Dynamic Data Masking, and a failover group.

```bash
# Validation commands
# 1. Verify TDE is enabled
az sql db tde show --database mydb --server myserver --resource-group myRG --query status

# 2. Verify Dynamic Data Masking rules
az sql db data-masking rule list --database mydb --server myserver --resource-group myRG

# 3. Verify failover group exists
az sql failover-group show --name myfog --server myserver --resource-group myRG --query replicationState

# 4. Verify no public endpoint
az sql server show --name myserver --resource-group myRG --query publicNetworkAccess
# Expected: Disabled
```

### Task 2: Deploy Container App with Traffic Splitting
Deploy two revisions of a Container App with 80/20 traffic split.

```bash
# Validation commands
# 1. List revisions and traffic weights
az containerapp revision list --name myapp --resource-group myRG \
  --query "[].{name:name,traffic:properties.trafficWeight,active:properties.active}"

# 2. Verify scale-to-zero config
az containerapp show --name myapp --resource-group myRG \
  --query "properties.template.scale.minReplicas"
# Expected: 0

# 3. Verify Managed Identity is used for ACR (no admin credentials)
az containerapp show --name myapp --resource-group myRG \
  --query "properties.configuration.registries[0].identity"
# Expected: resource ID of managed identity, not username/password
```

---

## Rubric

### Criterion 1: Azure SQL Security Design
| Level | Description |
|-------|-------------|
| Exemplary (4) | Implements TDE + Always Encrypted for sensitive columns + Dynamic Data Masking + private endpoint + Defender for SQL + audit logging. Correctly identifies which columns need Always Encrypted vs. DDM. |
| Proficient (3) | Implements TDE + Dynamic Data Masking + private endpoint. Minor gaps in audit logging or Defender configuration. |
| Developing (2) | Implements TDE only. Aware of other controls but cannot configure them correctly. |
| Beginning (1) | Cannot configure TDE or explain the difference between encryption options. |

### Criterion 2: Container Service Selection and Configuration
| Level | Description |
|-------|-------------|
| Exemplary (4) | Correctly selects Container Apps for microservices with clear justification. Configures scale-to-zero, traffic splitting, Managed Identity for ACR, and Dapr sidecar. Explains trade-offs vs. AKS. |
| Proficient (3) | Selects Container Apps with reasonable justification. Configures auto-scaling and traffic splitting. Minor gaps in Dapr or Managed Identity configuration. |
| Developing (2) | Selects a valid service but cannot fully justify. Configures basic deployment but missing scaling or traffic splitting. |
| Beginning (1) | Cannot distinguish between ACI, Container Apps, and AKS. Cannot configure a basic container deployment. |
