# POC 5: Complete 3-Tier Architecture
# App Gateway (WAF) → AKS → SQL + Redis + ACR + Key Vault + Monitor

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm"; version = "~> 3.90" }
  }
}

provider "azurerm" { features {} }
data "azurerm_client_config" "current" {}

locals {
  name = "poc5-prod"
  tags = { environment = "prod"; project = "poc5"; managed_by = "terraform" }
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.name}"
  location = var.location
  tags     = local.tags
}

# ── Networking ─────────────────────────────────────────────────────────────────
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${local.name}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = ["10.2.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "agw"  { name = "snet-agw";  resource_group_name = azurerm_resource_group.main.name; virtual_network_name = azurerm_virtual_network.main.name; address_prefixes = ["10.2.1.0/24"] }
resource "azurerm_subnet" "aks"  { name = "snet-aks";  resource_group_name = azurerm_resource_group.main.name; virtual_network_name = azurerm_virtual_network.main.name; address_prefixes = ["10.2.2.0/23"]; private_endpoint_network_policies_enabled = false }
resource "azurerm_subnet" "data" { name = "snet-data"; resource_group_name = azurerm_resource_group.main.name; virtual_network_name = azurerm_virtual_network.main.name; address_prefixes = ["10.2.4.0/24"]; private_endpoint_network_policies_enabled = false }

# ── Log Analytics ──────────────────────────────────────────────────────────────
resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-${local.name}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "PerGB2018"
  retention_in_days   = 90
  tags                = local.tags
}

# ── ACR (geo-replicated) ───────────────────────────────────────────────────────
resource "azurerm_container_registry" "main" {
  name                = "acrpoc5prod"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Premium"  # Required for geo-replication
  admin_enabled       = false      # Use Managed Identity, not admin credentials
  tags                = local.tags

  georeplications {
    location                = "westus2"
    zone_redundancy_enabled = false
  }
}

# ── AKS Cluster ────────────────────────────────────────────────────────────────
resource "azurerm_kubernetes_cluster" "main" {
  name                = "aks-${local.name}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  dns_prefix          = "poc5"
  kubernetes_version  = "1.28"
  tags                = local.tags

  default_node_pool {
    name                = "system"
    node_count          = 3
    vm_size             = "Standard_D4s_v3"
    vnet_subnet_id      = azurerm_subnet.aks.id
    enable_auto_scaling = true
    min_count           = 3
    max_count           = 5
    node_taints         = ["CriticalAddonsOnly=true:NoSchedule"]
  }

  identity { type = "SystemAssigned" }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "calico"
    load_balancer_sku = "standard"
    service_cidr      = "172.16.0.0/16"
    dns_service_ip    = "172.16.0.10"
  }

  azure_active_directory_role_based_access_control {
    managed            = true
    azure_rbac_enabled = true
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  lifecycle { ignore_changes = [default_node_pool[0].node_count, kubernetes_version] }
}

# User node pool for application workloads
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = "Standard_D4s_v3"
  vnet_subnet_id        = azurerm_subnet.aks.id
  enable_auto_scaling   = true
  min_count             = 2
  max_count             = 20
  tags                  = local.tags
}

# Grant AKS pull access to ACR
resource "azurerm_role_assignment" "aks_acr" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

# ── Azure SQL with Private Endpoint ───────────────────────────────────────────
resource "azurerm_mssql_server" "main" {
  name                          = "sql-${local.name}"
  resource_group_name           = azurerm_resource_group.main.name
  location                      = azurerm_resource_group.main.location
  version                       = "12.0"
  administrator_login           = var.sql_admin_username
  administrator_login_password  = var.sql_admin_password
  public_network_access_enabled = false
  minimum_tls_version           = "1.2"
  tags                          = local.tags
}

resource "azurerm_mssql_database" "main" {
  name      = "sqldb-${local.name}"
  server_id = azurerm_mssql_server.main.id
  sku_name  = "GP_Gen5_4"
  tags      = local.tags
}

resource "azurerm_private_endpoint" "sql" {
  name                = "pe-sql-${local.name}"
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

# ── Azure Cache for Redis with Private Endpoint ────────────────────────────────
resource "azurerm_redis_cache" "main" {
  name                          = "redis-${local.name}"
  resource_group_name           = azurerm_resource_group.main.name
  location                      = azurerm_resource_group.main.location
  capacity                      = 1
  family                        = "P"
  sku_name                      = "Premium"
  public_network_access_enabled = false
  tags                          = local.tags
}

resource "azurerm_private_endpoint" "redis" {
  name                = "pe-redis-${local.name}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  subnet_id           = azurerm_subnet.data.id
  tags                = local.tags

  private_service_connection {
    name                           = "redis-connection"
    private_connection_resource_id = azurerm_redis_cache.main.id
    subresource_names              = ["redisCache"]
    is_manual_connection           = false
  }
}

# ── Application Gateway (WAF v2) ───────────────────────────────────────────────
resource "azurerm_public_ip" "agw" {
  name                = "pip-agw-${local.name}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_application_gateway" "main" {
  name                = "agw-${local.name}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.tags

  sku { name = "WAF_v2"; tier = "WAF_v2"; capacity = 2 }

  waf_configuration {
    enabled          = true
    firewall_mode    = "Prevention"
    rule_set_type    = "OWASP"
    rule_set_version = "3.2"
  }

  gateway_ip_configuration { name = "gw-ip"; subnet_id = azurerm_subnet.agw.id }
  frontend_ip_configuration { name = "frontend"; public_ip_address_id = azurerm_public_ip.agw.id }
  frontend_port { name = "http"; port = 80 }

  backend_address_pool { name = "aks-backend" }
  backend_http_settings { name = "http-settings"; cookie_based_affinity = "Disabled"; port = 80; protocol = "Http"; request_timeout = 60 }
  http_listener { name = "http-listener"; frontend_ip_configuration_name = "frontend"; frontend_port_name = "http"; protocol = "Http" }
  request_routing_rule { name = "rule"; rule_type = "Basic"; http_listener_name = "http-listener"; backend_address_pool_name = "aks-backend"; backend_http_settings_name = "http-settings"; priority = 100 }
}
