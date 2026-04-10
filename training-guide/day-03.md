# Day 3 — Apr 9 | Auth, Key Vault, APIM + Terraform Advanced
**Presenters**: Thulasi & Swaroop

---

## What You'll Learn Today
- Microsoft Identity Platform, Managed Identities, Key Vault, RBAC
- Azure API Management policies (JWT, rate limiting, caching)
- Terraform modules, dynamic blocks, functions, data sources

---

## Part 1: Authentication & Authorization

### Managed Identity — The Golden Rule
**Never store passwords or secrets in app settings, pipelines, or code. Use Managed Identity.**

```bash
# Enable system-assigned identity on App Service
az webapp identity assign --name myapp --resource-group myRG

# Get the identity's principal ID
PRINCIPAL_ID=$(az webapp identity show \
  --name myapp --resource-group myRG \
  --query principalId -o tsv)

# Create Key Vault with RBAC (not access policies)
az keyvault create \
  --name kv-training-dev \
  --resource-group rg-training-dev \
  --enable-rbac-authorization true

# Grant App Service access to read secrets
az role assignment create \
  --role "Key Vault Secrets User" \
  --assignee $PRINCIPAL_ID \
  --scope $(az keyvault show --name kv-training-dev --query id -o tsv)

# Store a secret
az keyvault secret set \
  --vault-name kv-training-dev \
  --name SqlConnectionString \
  --value "Server=tcp:myserver.database.windows.net;Authentication=Active Directory Managed Identity;"

# Reference in App Service (no password stored anywhere)
az webapp config appsettings set \
  --name myapp --resource-group myRG \
  --settings "ConnectionStrings__Default=@Microsoft.KeyVault(VaultName=kv-training-dev;SecretName=SqlConnectionString)"
```

### OAuth 2.0 Flows — Which to Use

| Scenario | Flow |
|----------|------|
| Web app with user sign-in | Authorization Code + PKCE |
| Background service calling API (no user) | Client Credentials |
| API calling another API on behalf of user | On-Behalf-Of (OBO) |
| CLI tool / IoT device | Device Code |

### RBAC Scope Hierarchy
```
Management Group → Subscription → Resource Group → Resource
```
Roles assigned at a higher scope are inherited by all children.

**Common built-in roles**:
- `Key Vault Secrets User` — read secrets
- `Key Vault Secrets Officer` — read/write secrets
- `AcrPull` — pull images from ACR
- `Storage Blob Data Contributor` — read/write blobs
- `Contributor` — full access except role assignments

---

## Part 2: Azure API Management

### APIM Policy Pipeline
```
Request → [Inbound policies] → Backend → [Outbound policies] → Response
                                    ↓
                             [On-Error policies]
```

### Essential Policies
```xml
<policies>
  <inbound>
    <!-- 1. Validate JWT token from Azure AD -->
    <validate-jwt header-name="Authorization" failed-validation-httpcode="401">
      <openid-config url="https://login.microsoftonline.com/{tenant-id}/.well-known/openid-configuration" />
      <required-claims>
        <claim name="aud"><value>api://my-api-id</value></claim>
      </required-claims>
    </validate-jwt>

    <!-- 2. Rate limit: 100 calls/minute per subscription -->
    <rate-limit calls="100" renewal-period="60" />

    <!-- 3. Cache GET requests for 5 minutes -->
    <cache-lookup vary-by-developer="false" vary-by-developer-groups="false" />

    <base />
  </inbound>

  <outbound>
    <cache-store duration="300" />
    <base />
  </outbound>
</policies>
```

### APIM Tiers

| Tier | SLA | VNet | Use For |
|------|-----|------|---------|
| Developer | None | ✅ | Dev/test only |
| Basic | 99.95% | ❌ | Small production |
| Standard | 99.95% | External | Medium production |
| Premium | 99.99% | Internal/External | Enterprise, multi-region |
| Consumption | 99.95% | ❌ | Serverless, pay-per-call |

---

## Part 3: Terraform Advanced

### Modules — Reusable Infrastructure
```hcl
# modules/networking/main.tf
resource "azurerm_virtual_network" "main" {
  name                = var.vnet_name
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = var.address_space
}

resource "azurerm_subnet" "main" {
  for_each             = var.subnets
  name                 = each.key
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [each.value]
}

# modules/networking/variables.tf
variable "resource_group_name" { type = string }
variable "location"            { type = string }
variable "vnet_name"           { type = string }
variable "address_space"       { type = list(string) }
variable "subnets"             { type = map(string) }  # name → prefix

# modules/networking/outputs.tf
output "vnet_id"    { value = azurerm_virtual_network.main.id }
output "subnet_ids" { value = { for k, v in azurerm_subnet.main : k => v.id } }

# Calling the module
module "networking" {
  source              = "./modules/networking"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  vnet_name           = "vnet-myapp-prod"
  address_space       = ["10.0.0.0/16"]
  subnets = {
    web  = "10.0.1.0/24"
    app  = "10.0.2.0/24"
    data = "10.0.3.0/24"
  }
}

# Use module output
resource "azurerm_linux_web_app" "main" {
  virtual_network_subnet_id = module.networking.subnet_ids["web"]
}
```

### Dynamic Blocks — Variable-Length Configurations
```hcl
variable "nsg_rules" {
  type = list(object({
    name      = string
    priority  = number
    direction = string
    access    = string
    port      = string
  }))
}

resource "azurerm_network_security_group" "main" {
  name                = "nsg-main"
  resource_group_name = var.resource_group_name
  location            = var.location

  dynamic "security_rule" {
    for_each = var.nsg_rules
    content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      direction                  = security_rule.value.direction
      access                     = security_rule.value.access
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = security_rule.value.port
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  }
}
```

### Data Sources — Reference Existing Resources
```hcl
# Reference an existing Key Vault (not managed by this Terraform)
data "azurerm_key_vault" "shared" {
  name                = "kv-shared-prod"
  resource_group_name = "rg-shared-services"
}

data "azurerm_key_vault_secret" "db_password" {
  name         = "DatabasePassword"
  key_vault_id = data.azurerm_key_vault.shared.id
}

# Use in resource
resource "azurerm_linux_web_app" "main" {
  app_settings = {
    "DB_PASSWORD" = data.azurerm_key_vault_secret.db_password.value
  }
}
```

### count vs for_each — Use for_each Almost Always
```hcl
# ❌ count: index instability — removing index 1 shifts all others
resource "azurerm_resource_group" "envs" {
  count    = 3
  name     = "rg-env-${count.index}"
  location = "eastus2"
}

# ✅ for_each: stable keys — removing "staging" only affects that one
resource "azurerm_resource_group" "envs" {
  for_each = { dev = "eastus2", staging = "eastus2", prod = "westus2" }
  name     = "rg-${each.key}"
  location = each.value
}
```

---

## Hands-On: Refactor POC 1 to Use a Module

Extract the networking resources into a reusable module:

```bash
mkdir -p modules/networking
# Move VNet, subnet, NSG resources to modules/networking/main.tf
# Add variables.tf and outputs.tf
# Update root main.tf to call the module
terraform init  # Re-initialize after adding module
terraform plan  # Should show 0 changes (same resources, different structure)
```

---

## Interview Q&A — Day 3 Topics

**Q: What is the difference between a Managed Identity and a Service Principal?**
A: A Service Principal is an app identity in Azure AD — you manage its credentials (secrets/certificates) and must rotate them. A Managed Identity is a special service principal whose credentials are automatically managed by Azure — you never see or rotate them. Always use Managed Identity when the resource supports it (App Service, Functions, AKS, VMs). Use a Service Principal only when Managed Identity isn't available (on-premises apps, GitHub Actions with OIDC).

**Q: What is the difference between system-assigned and user-assigned Managed Identity?**
A: System-assigned: tied to one resource, deleted when the resource is deleted. User-assigned: independent lifecycle, can be shared across multiple resources. Use user-assigned when multiple resources need the same identity (e.g., 5 App Services all need to read the same Key Vault).

**Q: How do you debug a 401 error from APIM even though the client has a valid token?**
A: 1) Enable APIM tracing (add `Ocp-Apim-Trace: true` header). 2) Check the trace — it shows exactly which policy failed. 3) Common causes: wrong `aud` claim (token audience must match the API's App ID URI), wrong tenant ID in `openid-config` URL, expired token. 4) Paste the Bearer token into jwt.ms to inspect claims.

**Q: When would you use `for_each` vs `count` in Terraform?**
A: Use `for_each` for almost everything. `count` has index instability — if you remove the middle item from a list, Terraform sees all subsequent items as changed and may destroy/recreate them. `for_each` uses stable string keys — removing one item only affects that resource. Use `count` only for optional resources: `count = var.enabled ? 1 : 0`.

**Q: What is a Terraform data source?**
A: A data source reads information about an existing resource that Terraform doesn't manage. Use it to reference shared infrastructure (existing VNets, Key Vaults, subscriptions) without importing them into your state. Data sources are read-only — they never create or modify resources.
