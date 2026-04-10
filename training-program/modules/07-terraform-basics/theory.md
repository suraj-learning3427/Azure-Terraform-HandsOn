# Module 7: Terraform Basics — Theory

## 1. HCL Syntax

```hcl
# Block syntax: block_type "label1" "label2" { ... }
resource "azurerm_resource_group" "main" {
  name     = "rg-myapp-prod"
  location = "eastus2"

  tags = {
    environment = "production"
    team        = "platform"
    cost_center = "engineering"
  }
}

# Variables
variable "location" {
  type        = string
  description = "Azure region for all resources"
  default     = "eastus2"
}

variable "tags" {
  type = map(string)
  default = {
    environment = "dev"
  }
}

# Outputs
output "resource_group_id" {
  value       = azurerm_resource_group.main.id
  description = "The ID of the resource group"
}

# Locals (computed values)
locals {
  common_tags = merge(var.tags, {
    managed_by = "terraform"
    created_at = timestamp()
  })
  resource_prefix = "${var.environment}-${var.project}"
}
```

---

## 2. AzureRM Provider

```hcl
# versions.tf
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"  # Allow patch updates, not major
    }
  }

  # Remote state backend (Azure Storage)
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stterraformstate001"
    container_name       = "tfstate"
    key                  = "myapp/prod/terraform.tfstate"
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}

# Get current Azure context
data "azurerm_client_config" "current" {}
data "azurerm_subscription" "current" {}
```

---

## 3. Core Workflow

```bash
# Initialize: download providers, configure backend
terraform init

# Format code
terraform fmt -recursive

# Validate syntax
terraform validate

# Preview changes (ALWAYS run before apply)
terraform plan -out=tfplan

# Apply changes
terraform apply tfplan

# Destroy all resources (use with caution!)
terraform destroy

# Show current state
terraform show

# List resources in state
terraform state list

# Import existing resource into state
terraform import azurerm_resource_group.main /subscriptions/.../resourceGroups/myRG
```

---

## 4. State Management

### 4.1 Remote Backend (Azure Storage)
```bash
# Create storage account for Terraform state
az group create --name rg-terraform-state --location eastus2

az storage account create \
  --name stterraformstate001 \
  --resource-group rg-terraform-state \
  --sku Standard_LRS \
  --encryption-services blob \
  --min-tls-version TLS1_2

az storage container create \
  --name tfstate \
  --account-name stterraformstate001

# Enable versioning for state file history
az storage blob service-properties update \
  --account-name stterraformstate001 \
  --enable-versioning true
```

### 4.2 State Locking
Azure Storage backend uses blob leases for state locking — prevents concurrent `terraform apply` runs from corrupting state. If a lock is stuck (e.g., pipeline crashed):
```bash
terraform force-unlock <lock-id>
```

### 4.3 State Manipulation (Use with Caution)
```bash
# Move resource to different address (e.g., after refactoring)
terraform state mv azurerm_resource_group.old azurerm_resource_group.new

# Remove resource from state without destroying it
terraform state rm azurerm_resource_group.main

# Pull current state
terraform state pull > current.tfstate
```

---

## 5. Resource Dependencies

```hcl
# Implicit dependency: Terraform detects reference
resource "azurerm_virtual_network" "main" {
  name                = "vnet-myapp"
  resource_group_name = azurerm_resource_group.main.name  # Implicit dep
  location            = azurerm_resource_group.main.location
  address_space       = ["10.0.0.0/16"]
}

# Explicit dependency: use depends_on when no reference exists
resource "azurerm_role_assignment" "storage" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_web_app.main.identity[0].principal_id

  depends_on = [
    azurerm_linux_web_app.main,  # Ensure identity is created first
    azurerm_storage_account.main
  ]
}
```

---

## 6. Lifecycle Meta-Arguments

```hcl
resource "azurerm_kubernetes_cluster" "main" {
  name = "aks-myapp-prod"
  # ...

  lifecycle {
    # Create new resource before destroying old one (zero-downtime replacement)
    create_before_destroy = true

    # Prevent accidental destruction of critical resources
    prevent_destroy = true

    # Ignore changes to specific attributes (e.g., auto-scaled node count)
    ignore_changes = [
      default_node_pool[0].node_count,
      tags["last_modified"]
    ]
  }
}
```

---

## 7. Complete Example: Foundation Infrastructure

```hcl
# main.tf
resource "azurerm_resource_group" "main" {
  name     = "rg-${local.resource_prefix}"
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-${local.resource_prefix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = [var.vnet_address_space]
  tags                = local.common_tags
}

resource "azurerm_subnet" "web" {
  name                 = "snet-web"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.web_subnet_prefix]
}

resource "azurerm_network_security_group" "web" {
  name                = "nsg-web-${local.resource_prefix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

resource "azurerm_subnet_network_security_group_association" "web" {
  subnet_id                 = azurerm_subnet.web.id
  network_security_group_id = azurerm_network_security_group.web.id
}
```

---

## 8. Best Practices

- Always run `terraform plan` before `apply` — review every change
- Use remote state with locking — never use local state in teams
- Pin provider versions with `~>` (allow patch, not major)
- Use `terraform.tfvars` for environment-specific values, never hardcode
- Enable `prevent_destroy` on critical resources (databases, Key Vaults)
- Use `ignore_changes` for auto-managed attributes (auto-scale counts, last-modified tags)
- Store state per environment: `myapp/dev/terraform.tfstate`, `myapp/prod/terraform.tfstate`
- Use `terraform fmt` and `terraform validate` in CI before `plan`
