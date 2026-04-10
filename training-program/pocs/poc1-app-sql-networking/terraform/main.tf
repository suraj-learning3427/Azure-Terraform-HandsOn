# POC 1: Foundation Infrastructure
# Deploys: Resource Group, VNet, Subnets, NSGs, Azure SQL, App Service, Key Vault

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm"; version = "~> 3.90" }
  }
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stterraformstatepoc1"
    container_name       = "tfstate"
    key                  = "poc1/terraform.tfstate"
  }
}

provider "azurerm" { features {} }

data "azurerm_client_config" "current" {}

locals {
  prefix = "${var.environment}-${var.project}"
  tags = {
    environment = var.environment
    project     = var.project
    team        = var.team
    cost_center = var.cost_center
    managed_by  = "terraform"
  }
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "rg-${local.prefix}"
  location = var.location
  tags     = local.tags
  lifecycle { prevent_destroy = true }
}

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${local.prefix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = ["10.0.0.0/16"]
  tags                = local.tags
}

# Subnets
resource "azurerm_subnet" "web" {
  name                 = "snet-web"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
  # App Service VNet integration requires delegation
  delegation {
    name = "app-service-delegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_subnet" "data" {
  name                 = "snet-data"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
  # Disable private endpoint network policies
  private_endpoint_network_policies_enabled = false
}

# NSG: Web subnet — allow HTTPS inbound
resource "azurerm_network_security_group" "web" {
  name                = "nsg-web-${local.prefix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.tags

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

resource "azurerm_subnet_network_security_group_association" "web" {
  subnet_id                 = azurerm_subnet.web.id
  network_security_group_id = azurerm_network_security_group.web.id
}

# Key Vault
resource "azurerm_key_vault" "main" {
  name                      = "kv-${local.prefix}"
  resource_group_name       = azurerm_resource_group.main.name
  location                  = azurerm_resource_group.main.location
  tenant_id                 = data.azurerm_client_config.current.tenant_id
  sku_name                  = "standard"
  enable_rbac_authorization = true
  purge_protection_enabled  = true
  tags                      = local.tags
}

# App Service Plan
resource "azurerm_service_plan" "main" {
  name                = "asp-${local.prefix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = var.app_service_sku
  tags                = local.tags
}

# App Service
resource "azurerm_linux_web_app" "main" {
  name                = "app-${local.prefix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.main.id
  https_only          = true
  tags                = local.tags

  identity { type = "SystemAssigned" }

  site_config {
    always_on = true
    application_stack { dotnet_version = "8.0" }
    minimum_tls_version = "1.2"
  }

  app_settings = {
    "ASPNETCORE_ENVIRONMENT"                = "Production"
    "ConnectionStrings__DefaultConnection"  = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.main.name};SecretName=SqlConnectionString)"
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.main.name};SecretName=AppInsightsConnectionString)"
  }

  # VNet integration
  virtual_network_subnet_id = azurerm_subnet.web.id
}

# Staging deployment slot
resource "azurerm_linux_web_app_slot" "staging" {
  name           = "staging"
  app_service_id = azurerm_linux_web_app.main.id
  https_only     = true

  identity { type = "SystemAssigned" }

  site_config {
    always_on = true
    application_stack { dotnet_version = "8.0" }
  }

  app_settings = {
    # Slot-specific: stays with staging slot after swap
    "ASPNETCORE_ENVIRONMENT" = "Staging"
  }
}

# Grant App Service Managed Identity access to Key Vault
resource "azurerm_role_assignment" "app_kv" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app.main.identity[0].principal_id
}

# Azure SQL Server
resource "azurerm_mssql_server" "main" {
  name                         = "sql-${local.prefix}"
  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_username
  administrator_login_password = var.sql_admin_password
  minimum_tls_version          = "1.2"
  # Disable public network access — private endpoint only
  public_network_access_enabled = false
  tags                          = local.tags

  azuread_administrator {
    login_username = "AzureAD Admin"
    object_id      = data.azurerm_client_config.current.object_id
  }
}

# Azure SQL Database
resource "azurerm_mssql_database" "main" {
  name         = "sqldb-${local.prefix}"
  server_id    = azurerm_mssql_server.main.id
  collation    = "SQL_Latin1_General_CP1_CI_AS"
  sku_name     = "GP_Gen5_2"  # General Purpose, 2 vCores
  license_type = "LicenseIncluded"
  tags         = local.tags

  # TDE enabled by default on Azure SQL
  transparent_data_encryption_enabled = true

  # Backup retention
  short_term_retention_policy {
    retention_days           = 35
    backup_interval_in_hours = 12
  }
}

# Dynamic Data Masking rules
resource "azurerm_mssql_server_microsoft_support_auditing_policy" "main" {
  server_id = azurerm_mssql_server.main.id
  enabled   = true
}

# Private endpoint for SQL
resource "azurerm_private_endpoint" "sql" {
  name                = "pe-sql-${local.prefix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  subnet_id           = azurerm_subnet.data.id
  tags                = local.tags

  private_service_connection {
    name                           = "sql-connection"
    private_connection_resource_id = azurerm_mssql_server.main.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }
}

# Auto-scaling
resource "azurerm_monitor_autoscale_setting" "main" {
  name                = "autoscale-${local.prefix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  target_resource_id  = azurerm_service_plan.main.id

  profile {
    name = "default"
    capacity { default = 2; minimum = 2; maximum = 10 }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.main.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 70
      }
      scale_action { direction = "Increase"; type = "ChangeCount"; value = "2"; cooldown = "PT5M" }
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.main.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT10M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 30
      }
      scale_action { direction = "Decrease"; type = "ChangeCount"; value = "1"; cooldown = "PT10M" }
    }
  }
}
