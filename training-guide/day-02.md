# Day 2 — Apr 8 | Azure SQL + Containers + Terraform State
**Presenters**: Lini & Karthik

---

## What You'll Learn Today
- Azure SQL tiers, HA, encryption, data masking, backup
- Azure Container Registry, Container Instances, Container Apps
- Terraform state management, remote backends, lifecycle rules

---

## Part 1: Azure SQL

### Service Tiers — Which to Choose

| Model | Tier | vCores | Use For |
|-------|------|--------|---------|
| vCore | General Purpose | 2–80 | Most production workloads |
| vCore | Business Critical | 2–80 | High IOPS, in-memory, readable replica |
| vCore | Hyperscale | 2–80 | Very large databases (> 4 TB) |
| DTU | Basic/Standard/Premium | — | Simple workloads, no Hybrid Benefit |

**Rule**: Use vCore for production — you can apply Azure Hybrid Benefit (existing SQL Server licenses = 55% savings).

### Create SQL with Security Controls
```bash
# Create SQL Server (no public access)
az sql server create \
  --name sql-training-dev \
  --resource-group rg-training-dev \
  --location eastus2 \
  --admin-user sqladmin \
  --admin-password "P@ssw0rd123!" \
  --enable-public-network false

# Create database
az sql db create \
  --name sqldb-training \
  --server sql-training-dev \
  --resource-group rg-training-dev \
  --service-objective GP_Gen5_2

# Enable Dynamic Data Masking on email column
az sql db data-masking rule create \
  --resource-group rg-training-dev \
  --server sql-training-dev \
  --database sqldb-training \
  --schema-name dbo \
  --table-name Customers \
  --column-name Email \
  --masking-function Email

# Create failover group (geo-replication + auto-failover)
az sql failover-group create \
  --name fog-training \
  --server sql-training-dev \
  --resource-group rg-training-dev \
  --partner-server sql-training-secondary \
  --failover-policy Automatic \
  --grace-period 1
```

### Key Security Concepts

| Feature | What It Does | When to Use |
|---------|-------------|-------------|
| TDE (Transparent Data Encryption) | Encrypts data at rest | Always — enabled by default |
| Dynamic Data Masking | Non-admins see `XXXX` instead of real data | PII columns (email, phone, SSN) |
| Always Encrypted | Client-side encryption — DB never sees plaintext | Most sensitive columns (SSN, credit card) |
| Private Endpoint | No public internet access | All production databases |

---

## Part 2: Azure Container Services

### Decision Matrix — Which Service to Use

| Requirement | ACI | Container Apps | AKS |
|-------------|-----|----------------|-----|
| One-off batch job | ✅ Best | ✅ | ❌ Overkill |
| Microservices | ❌ | ✅ Best | ✅ |
| Scale to zero | ❌ | ✅ | With KEDA |
| Full Kubernetes control | ❌ | ❌ | ✅ |
| Dapr built-in | ❌ | ✅ | Manual |
| Operational complexity | Low | Low-Med | High |

**Rule**: ACI for jobs → Container Apps for microservices → AKS when you need full Kubernetes.

### Azure Container Registry (ACR)
```bash
# Create ACR (Premium for geo-replication)
az acr create \
  --name acrtrainingdev \
  --resource-group rg-training-dev \
  --sku Premium \
  --admin-enabled false  # Use Managed Identity, not admin credentials

# Build and push image (no docker needed — ACR Tasks)
az acr build \
  --registry acrtrainingdev \
  --image myapp:v1 \
  --file Dockerfile .

# Grant AKS/App Service pull access (Managed Identity)
az role assignment create \
  --role AcrPull \
  --assignee <principal-id> \
  --scope $(az acr show --name acrtrainingdev --query id -o tsv)
```

### Azure Container Apps
```bash
# Create Container Apps environment
az containerapp env create \
  --name cae-training-dev \
  --resource-group rg-training-dev \
  --location eastus2

# Deploy container app with scale-to-zero
az containerapp create \
  --name myapp \
  --resource-group rg-training-dev \
  --environment cae-training-dev \
  --image acrtrainingdev.azurecr.io/myapp:v1 \
  --registry-identity system \
  --min-replicas 0 \
  --max-replicas 10 \
  --scale-rule-name http-rule \
  --scale-rule-type http \
  --scale-rule-http-concurrency 50

# Traffic splitting: 80% stable, 20% canary
az containerapp ingress traffic set \
  --name myapp \
  --resource-group rg-training-dev \
  --revision-weight stable=80 canary=20
```

---

## Part 3: Terraform State Management

### Lifecycle Meta-Arguments
```hcl
resource "azurerm_mssql_server" "main" {
  name = "sql-training-prod"
  # ...

  lifecycle {
    prevent_destroy = true  # Block accidental terraform destroy

    ignore_changes = [
      administrator_login_password  # Don't reset password on every apply
    ]
  }
}

resource "azurerm_kubernetes_cluster" "main" {
  # ...
  lifecycle {
    create_before_destroy = true  # Zero-downtime replacement
    ignore_changes = [
      default_node_pool[0].node_count  # Managed by autoscaler
    ]
  }
}
```

### State Commands
```bash
terraform state list              # List all resources in state
terraform state show <resource>   # Show resource details
terraform state mv old new        # Rename resource (after refactoring)
terraform state rm <resource>     # Remove from state (don't destroy)
terraform import <address> <id>   # Import existing Azure resource
terraform force-unlock <lock-id>  # Release stuck lock
```

---

## POC 1 Continued: Add SQL + Complete Networking

### Add to your existing Terraform from Day 1
```hcl
# Azure SQL (private endpoint only)
resource "azurerm_mssql_server" "main" {
  name                          = "sql-poc1-dev"
  resource_group_name           = azurerm_resource_group.main.name
  location                      = azurerm_resource_group.main.location
  version                       = "12.0"
  administrator_login           = "sqladmin"
  administrator_login_password  = var.sql_password
  public_network_access_enabled = false
  minimum_tls_version           = "1.2"

  lifecycle { prevent_destroy = true }
}

resource "azurerm_mssql_database" "main" {
  name      = "sqldb-poc1"
  server_id = azurerm_mssql_server.main.id
  sku_name  = "GP_Gen5_2"
}

# Data subnet for private endpoint
resource "azurerm_subnet" "data" {
  name                 = "snet-data"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
  private_endpoint_network_policies_enabled = false
}

# Private endpoint — SQL accessible only from VNet
resource "azurerm_private_endpoint" "sql" {
  name                = "pe-sql-poc1"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  subnet_id           = azurerm_subnet.data.id

  private_service_connection {
    name                           = "sql-connection"
    private_connection_resource_id = azurerm_mssql_server.main.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }
}
```

### Validate
```bash
# SQL public access disabled
az sql server show --name sql-poc1-dev --resource-group rg-poc1-dev \
  --query publicNetworkAccess -o tsv
# Expected: Disabled

# TDE enabled (default on Azure SQL)
az sql db tde show --database sqldb-poc1 --server sql-poc1-dev \
  --resource-group rg-poc1-dev --query status -o tsv
# Expected: Enabled

# Private endpoint provisioned
az network private-endpoint show --name pe-sql-poc1 \
  --resource-group rg-poc1-dev --query provisioningState -o tsv
# Expected: Succeeded
```

---

## Interview Q&A — Day 2 Topics

**Q: What is the difference between TDE and Always Encrypted?**
A: TDE encrypts data at rest at the storage level — Azure handles it transparently, the database engine sees plaintext. Always Encrypted encrypts client-side — the database engine never sees plaintext, only the application with the column master key can decrypt. Use TDE for general compliance (always on by default). Use Always Encrypted for the most sensitive columns where even DBAs shouldn't see the data (SSN, credit card numbers).

**Q: What is Dynamic Data Masking and what are its limitations?**
A: DDM shows masked data (e.g., `XXXX@XXXX.com`) to non-privileged users without changing the actual stored data. Limitation: it's a presentation-layer control — privileged users (db_owner, sysadmin) always see real data. It doesn't protect against SQL injection or direct database access. For true protection of sensitive data, use Always Encrypted.

**Q: When would you choose Container Apps over AKS?**
A: Container Apps for most microservices — it removes 80% of Kubernetes operational overhead while providing auto-scale (including scale-to-zero), built-in ingress, Dapr integration, and traffic splitting. Choose AKS when you need: full Kubernetes control (custom operators, CRDs), GPU nodes, specific node configurations, or your team already has deep Kubernetes expertise. For new projects, start with Container Apps and migrate to AKS only if you hit its limits.

**Q: What is `prevent_destroy` in Terraform and when do you use it?**
A: A lifecycle rule that causes `terraform destroy` and any plan that would destroy the resource to fail with an error. Use it on critical resources that should never be accidentally deleted: production databases, Key Vaults, storage accounts with important data. It's a safety net — you have to explicitly remove the `prevent_destroy` block before you can destroy the resource.

**Q: How do you handle a stuck Terraform state lock?**
A: 1) Verify no Terraform process is actually running. 2) Get the lock ID from the error message. 3) Run `terraform force-unlock <lock-id>`. 4) Run `terraform plan` to verify state is consistent. Prevention: set pipeline timeouts so crashed pipelines release locks automatically.
