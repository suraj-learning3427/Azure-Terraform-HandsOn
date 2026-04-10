# POC 2: Compute Infrastructure with Reusable Modules
# Deploys: Networking module + VMSS compute module + SQL database module

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm"; version = "~> 3.90" }
  }
}

provider "azurerm" { features {} }

resource "azurerm_resource_group" "main" {
  name     = "rg-poc2-${var.environment}"
  location = var.location
  tags     = local.tags
}

locals {
  tags = {
    environment = var.environment
    project     = "poc2"
    managed_by  = "terraform"
  }
}

# ── Networking Module ──────────────────────────────────────────────────────────
module "networking" {
  source              = "./modules/networking"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  vnet_name           = "vnet-poc2-${var.environment}"
  address_space       = ["10.1.0.0/16"]
  tags                = local.tags

  subnets = {
    web  = { address_prefix = "10.1.1.0/24" }
    data = { address_prefix = "10.1.2.0/24" }
  }

  # Dynamic NSG rules from variable
  nsg_rules = var.nsg_rules
}

# ── Compute Module (VMSS) ──────────────────────────────────────────────────────
module "compute" {
  source              = "./modules/compute"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  name                = "poc2-${var.environment}"
  subnet_id           = module.networking.subnet_ids["web"]
  vm_size             = "Standard_D2s_v3"
  min_instances       = 2
  max_instances       = 10
  tags                = local.tags
}

# ── Database Module ────────────────────────────────────────────────────────────
module "database" {
  source              = "./modules/database"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  name                = "poc2-${var.environment}"
  subnet_id           = module.networking.subnet_ids["data"]
  sku_name            = "GP_Gen5_2"
  tags                = local.tags
}
