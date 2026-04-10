# Day 1 — Apr 7 | Azure App Service + Terraform Basics
**Presenters**: Varsha & Gowtham

---

## What You'll Learn Today
- Azure App Service Plans, Web Apps, Azure Functions, Deployment Slots, Auto-scaling
- Terraform HCL syntax, providers, remote state, core workflow

---

## Part 1: Azure App Service

### App Service Plan Tiers (Pick the Right One)

| Tier | Auto-Scale | Slots | VNet | Use For |
|------|-----------|-------|------|---------|
| Free/Basic | ❌ | ❌ | ❌ | Dev/test only |
| Standard | ✅ (10 instances) | ✅ (5) | Limited | Small production |
| Premium v3 | ✅ (30 instances) | ✅ (20) | ✅ Full | Enterprise production |
| Isolated v2 | ✅ (100 instances) | ✅ (20) | ✅ Dedicated | Compliance (PCI, HIPAA) |

**Rule**: For production with auto-scale + VNet → use **Premium v3 P1v3** minimum.

### Create a Web App
```bash
# Create resource group
az group create --name rg-training-dev --location eastus2

# Create Premium v3 App Service Plan
az appservice plan create \
  --name asp-training-dev \
  --resource-group rg-training-dev \
  --sku P1v3 \
  --is-linux

# Create Web App (.NET 8)
az webapp create \
  --name app-training-dev \
  --resource-group rg-training-dev \
  --plan asp-training-dev \
  --runtime "DOTNETCORE:8.0"

# Enable Managed Identity (no passwords!)
az webapp identity assign \
  --name app-training-dev \
  --resource-group rg-training-dev
```

### Deployment Slots (Zero-Downtime Deployments)
```bash
# Create staging slot
az webapp deployment slot create \
  --name app-training-dev \
  --resource-group rg-training-dev \
  --slot staging

# Set slot-specific settings (these DON'T swap with the app)
az webapp config appsettings set \
  --name app-training-dev \
  --resource-group rg-training-dev \
  --slot staging \
  --slot-settings ASPNETCORE_ENVIRONMENT=Staging

# Deploy to staging, then swap to production
az webapp deployment slot swap \
  --name app-training-dev \
  --resource-group rg-training-dev \
  --slot staging \
  --target-slot production

# Rollback: swap back
az webapp deployment slot swap \
  --name app-training-dev \
  --resource-group rg-training-dev \
  --slot production \
  --target-slot staging
```

**Key concept**: Slot-specific settings stay with the slot. Regular settings swap with the app.
- ✅ Slot-specific: `ASPNETCORE_ENVIRONMENT`, App Insights key
- ✅ Swaps with app: feature flags, API endpoints, app config

### Auto-Scaling
```bash
# Enable auto-scale
az monitor autoscale create \
  --resource-group rg-training-dev \
  --resource asp-training-dev \
  --resource-type Microsoft.Web/serverfarms \
  --name autoscale-training \
  --min-count 2 --max-count 10 --count 2

# Scale OUT when CPU > 70% for 5 minutes
az monitor autoscale rule create \
  --resource-group rg-training-dev \
  --autoscale-name autoscale-training \
  --condition "Percentage CPU > 70 avg 5m" \
  --scale out 2

# Scale IN when CPU < 30% for 10 minutes
az monitor autoscale rule create \
  --resource-group rg-training-dev \
  --autoscale-name autoscale-training \
  --condition "Percentage CPU < 30 avg 10m" \
  --scale in 1
```

### Azure Functions — When to Use Which Plan

| Plan | Cold Start | VNet | Cost | Use When |
|------|-----------|------|------|----------|
| Consumption | Yes (5-15s) | Limited | Pay per call | Sporadic, can tolerate cold starts |
| Premium (EP1) | No | ✅ | ~$125/month | API, needs VNet, no cold starts |
| Dedicated | No | ✅ | App Service Plan | Already have a plan |

---

## Part 2: Terraform Basics

### HCL Syntax
```hcl
# variables.tf
variable "location"    { type = string; default = "eastus2" }
variable "environment" { type = string; default = "dev" }

# locals.tf
locals {
  prefix = "${var.environment}-training"
  tags   = { environment = var.environment; managed_by = "terraform" }
}

# main.tf
resource "azurerm_resource_group" "main" {
  name     = "rg-${local.prefix}"
  location = var.location
  tags     = local.tags
}

# outputs.tf
output "resource_group_name" {
  value = azurerm_resource_group.main.name
}
```

### Remote State (Always Use in Teams)
```hcl
# versions.tf
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm"; version = "~> 3.90" }
  }
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stterraformstate001"
    container_name       = "tfstate"
    key                  = "training/dev/terraform.tfstate"
  }
}
```

### Core Workflow
```bash
terraform init      # Download providers, configure backend
terraform fmt       # Format code
terraform validate  # Check syntax
terraform plan -out=tfplan  # Preview changes
terraform apply tfplan      # Apply changes
terraform destroy           # Destroy everything
```

---

## POC 1: Deploy App Service + Networking with Terraform

### What You'll Build
- Resource Group, VNet (10.0.0.0/16), 2 subnets, NSG
- App Service Plan (P1v3) + Web App with staging slot
- Remote state in Azure Storage

### Step 1: Bootstrap State Storage
```bash
az group create --name rg-terraform-state --location eastus2
az storage account create \
  --name stterraformstate001 \
  --resource-group rg-terraform-state \
  --sku Standard_LRS
az storage container create \
  --name tfstate \
  --account-name stterraformstate001
```

### Step 2: Create Terraform Config
```hcl
# main.tf
resource "azurerm_resource_group" "main" {
  name     = "rg-poc1-dev"
  location = "eastus2"
  tags     = { environment = "dev"; managed_by = "terraform" }
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-poc1-dev"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "web" {
  name                 = "snet-web"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "web" {
  name                = "nsg-web-poc1"
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
}

resource "azurerm_service_plan" "main" {
  name                = "asp-poc1-dev"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = "P1v3"
}

resource "azurerm_linux_web_app" "main" {
  name                = "app-poc1-dev"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.main.id
  https_only          = true

  identity { type = "SystemAssigned" }
  site_config { application_stack { dotnet_version = "8.0" } }
}

resource "azurerm_linux_web_app_slot" "staging" {
  name           = "staging"
  app_service_id = azurerm_linux_web_app.main.id
  site_config    { application_stack { dotnet_version = "8.0" } }
  app_settings   = { "ASPNETCORE_ENVIRONMENT" = "Staging" }
}
```

### Step 3: Deploy
```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### Step 4: Validate
```bash
# App Service running
az webapp show --name app-poc1-dev --resource-group rg-poc1-dev --query state -o tsv
# Expected: Running

# Staging slot exists
az webapp deployment slot list --name app-poc1-dev --resource-group rg-poc1-dev --query "[].name" -o tsv
# Expected: staging

# State in Azure Storage
az storage blob list --account-name stterraformstate001 --container-name tfstate --query "[].name" -o tsv
# Expected: training/dev/terraform.tfstate
```

---

## Interview Q&A — Day 1 Topics

**Q: What App Service Plan tier would you choose for a production app needing auto-scale and VNet integration?**
A: Premium v3 P1v3 minimum. Standard supports auto-scale but has limited VNet integration. Premium v3 gives full VNet integration, up to 20 deployment slots, and better price/performance on newer hardware. With 1-year Reserved Instance it's ~35% cheaper than pay-as-you-go.

**Q: What is the difference between a slot-specific setting and a regular app setting?**
A: Slot-specific settings stay with the slot after a swap — they're bound to the environment, not the app version. Example: `ASPNETCORE_ENVIRONMENT=Staging` should be slot-specific so it doesn't become "Staging" in production after a swap. Regular settings swap with the app code — use these for feature flags or config that's part of the release.

**Q: When would you use Azure Functions Premium plan instead of Consumption?**
A: When you need: no cold starts (API with latency requirements), VNet integration (access private SQL/Redis), execution time > 10 minutes, or always-warm instances. Consumption is fine for background jobs and event processing that can tolerate 5-15 second cold starts.

**Q: What is Terraform state and why is remote state important?**
A: State is a JSON file mapping your Terraform config to real Azure resources. Without it, Terraform can't know what already exists. Remote state (Azure Storage) is essential for teams because: it prevents conflicts when multiple people run Terraform, provides state locking (blob leases prevent concurrent applies), and gives a shared source of truth. Never use local state in a team.

**Q: What does `terraform plan` do?**
A: Shows exactly what changes Terraform will make — creates, updates, or destroys — without making them. Always run `plan` before `apply` and review every change. In CI/CD, save the plan (`-out=tfplan`) and apply that exact plan to ensure what you reviewed is what gets applied.
