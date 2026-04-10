# Module 3: Auth + API Management — Theory

## 1. Microsoft Identity Platform

### 1.1 App Registrations and Service Principals
An **app registration** in Azure AD represents an application identity. It creates two objects:
- **Application object** (global, in home tenant): defines the app's identity, permissions, and configuration
- **Service principal** (per tenant): the local instance used for authentication in that tenant

```bash
# Register an application
az ad app create --display-name "MyAPI" --sign-in-audience AzureADMyOrg

# Create a service principal for the app
az ad sp create --id <app-id>

# Create a client secret
az ad app credential reset --id <app-id> --append
```

### 1.2 OAuth 2.0 Flows

| Flow | Use Case | Token Type |
|------|----------|------------|
| Authorization Code + PKCE | Web apps, SPAs with user sign-in | Access + Refresh token |
| Client Credentials | Service-to-service (no user) | Access token |
| Device Code | CLI tools, IoT devices | Access + Refresh token |
| On-Behalf-Of | API calling another API on behalf of user | Access token |

**Client Credentials Flow** (most common for backend services):
```
Client → POST /token with client_id + client_secret → Azure AD → Access Token
Client → API call with Bearer token → API validates token → Response
```

### 1.3 Managed Identities
Managed Identities eliminate the need to manage credentials. Azure automatically creates and rotates the identity's credentials.

| Type | Use Case |
|------|----------|
| System-assigned | Tied to a single resource lifecycle; deleted when resource is deleted |
| User-assigned | Shared across multiple resources; independent lifecycle |

```bash
# Enable system-assigned identity on a Web App
az webapp identity assign --name myapp --resource-group myRG

# Enable user-assigned identity
az identity create --name myIdentity --resource-group myRG
az webapp identity assign --name myapp --resource-group myRG \
  --identities /subscriptions/.../resourceGroups/myRG/providers/Microsoft.ManagedIdentity/userAssignedIdentities/myIdentity
```

---

## 2. Azure Key Vault

### 2.1 Key Vault Objects
- **Secrets**: passwords, connection strings, API keys
- **Keys**: cryptographic keys for encryption/signing (HSM-backed available)
- **Certificates**: X.509 certificates with automatic renewal

### 2.2 Access Models
- **Access Policies** (legacy): vault-level permissions, coarse-grained
- **RBAC** (recommended): Azure role assignments, fine-grained, auditable

```bash
# Create Key Vault with RBAC authorization
az keyvault create --name myKV --resource-group myRG --enable-rbac-authorization true

# Grant Managed Identity access to secrets
PRINCIPAL_ID=$(az webapp identity show --name myapp --resource-group myRG --query principalId -o tsv)
KV_ID=$(az keyvault show --name myKV --query id -o tsv)
az role assignment create --role "Key Vault Secrets User" --assignee $PRINCIPAL_ID --scope $KV_ID

# Store a secret
az keyvault secret set --vault-name myKV --name DbPassword --value "s3cr3t!"

# Reference in App Service app settings
# @Microsoft.KeyVault(VaultName=myKV;SecretName=DbPassword)
```

### 2.3 Terraform: Key Vault with RBAC

```hcl
resource "azurerm_key_vault" "main" {
  name                       = "kv-myapp-prod"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  enable_rbac_authorization  = true  # Use RBAC instead of access policies
  purge_protection_enabled   = true  # Prevent accidental deletion
  soft_delete_retention_days = 90

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    virtual_network_subnet_ids = [azurerm_subnet.app.id]
  }
}

resource "azurerm_role_assignment" "app_kv_secrets_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app.main.identity[0].principal_id
}
```

---

## 3. RBAC (Role-Based Access Control)

### 3.1 Scope Hierarchy
```
Management Group
  └── Subscription
        └── Resource Group
              └── Resource
```
Roles assigned at a higher scope are inherited by all child scopes.

### 3.2 Built-in Roles
| Role | Description |
|------|-------------|
| Owner | Full access including role assignments |
| Contributor | Full access except role assignments |
| Reader | Read-only access |
| Key Vault Secrets User | Read secrets |
| Key Vault Secrets Officer | Read/write secrets |
| Storage Blob Data Contributor | Read/write blobs |
| AcrPull | Pull images from ACR |

### 3.3 Custom Roles
```json
{
  "Name": "SQL DB Reader",
  "Actions": [
    "Microsoft.Sql/servers/databases/read",
    "Microsoft.Sql/servers/read"
  ],
  "NotActions": [],
  "AssignableScopes": ["/subscriptions/{subscriptionId}"]
}
```

---

## 4. Azure API Management (APIM)

### 4.1 APIM Tiers
| Tier | Use Case | SLA | VNet |
|------|----------|-----|------|
| Developer | Dev/test only | None | External/Internal |
| Basic | Small production | 99.95% | None |
| Standard | Medium production | 99.95% | External |
| Premium | Enterprise, multi-region | 99.99% | External/Internal |
| Consumption | Serverless, pay-per-call | 99.95% | None |

### 4.2 APIM Policy Pipeline
Policies execute in this order:
```
Inbound → Backend → Outbound → On-Error
```

**Common Policies:**

```xml
<!-- Rate limiting: 100 calls per minute per subscription -->
<rate-limit calls="100" renewal-period="60" />

<!-- JWT validation -->
<validate-jwt header-name="Authorization" failed-validation-httpcode="401">
  <openid-config url="https://login.microsoftonline.com/{tenant}/.well-known/openid-configuration" />
  <required-claims>
    <claim name="aud">
      <value>api://my-api-id</value>
    </claim>
  </required-claims>
</validate-jwt>

<!-- Response caching -->
<cache-lookup vary-by-developer="false" vary-by-developer-groups="false">
  <vary-by-header>Accept</vary-by-header>
</cache-lookup>
<cache-store duration="300" />

<!-- Request transformation: add header -->
<set-header name="X-Forwarded-For" exists-action="override">
  <value>@(context.Request.IpAddress)</value>
</set-header>

<!-- Mock response for testing -->
<mock-response status-code="200" content-type="application/json" />
```

### 4.3 API Versioning Strategies
| Strategy | URL Example | Best For |
|----------|-------------|----------|
| URL path | `/api/v1/users` | Most common, clear |
| Query string | `/api/users?api-version=1.0` | Backward compatible |
| Header | `Api-Version: 1.0` | Clean URLs |

### 4.4 Terraform: APIM Instance

```hcl
resource "azurerm_api_management" "main" {
  name                = "apim-mycompany-prod"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  publisher_name      = "My Company"
  publisher_email     = "api-team@mycompany.com"
  sku_name            = "Standard_1"

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_api_management_api" "orders" {
  name                = "orders-api"
  resource_group_name = azurerm_resource_group.main.name
  api_management_name = azurerm_api_management.main.name
  revision            = "1"
  display_name        = "Orders API"
  path                = "orders"
  protocols           = ["https"]
  subscription_required = true

  import {
    content_format = "openapi+json"
    content_value  = file("${path.module}/openapi/orders.json")
  }
}

# Rate limit policy on all operations
resource "azurerm_api_management_api_policy" "orders_policy" {
  api_name            = azurerm_api_management_api.orders.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name

  xml_content = <<XML
<policies>
  <inbound>
    <rate-limit calls="100" renewal-period="60" />
    <validate-jwt header-name="Authorization" failed-validation-httpcode="401">
      <openid-config url="https://login.microsoftonline.com/${var.tenant_id}/.well-known/openid-configuration" />
    </validate-jwt>
    <base />
  </inbound>
  <backend><base /></backend>
  <outbound>
    <cache-store duration="300" />
    <base />
  </outbound>
  <on-error><base /></on-error>
</policies>
XML
}
```

---

## 5. Best Practices

- Always use Managed Identity over service principal secrets where possible
- Enable RBAC authorization on Key Vault (not access policies)
- Use APIM Consumption tier for low-volume APIs to minimize cost
- Validate JWTs at the APIM gateway — don't let unauthenticated requests reach backends
- Use named values in APIM policies for secrets (reference Key Vault, not hardcoded values)
- Enable Application Insights integration in APIM for request tracing
- Use API revisions for non-breaking changes, API versions for breaking changes
