# Module 9: Azure Infrastructure with Terraform — Theory

## 1. Virtual Machines

```hcl
resource "azurerm_linux_virtual_machine" "main" {
  name                = "vm-${var.name}-${count.index}"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = "Standard_D2s_v3"
  admin_username      = "azureuser"

  # Disable password auth — SSH keys only
  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 128
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  network_interface_ids = [azurerm_network_interface.main.id]

  identity {
    type = "SystemAssigned"
  }

  # Cloud-init for initial configuration
  custom_data = base64encode(templatefile("${path.module}/cloud-init.yaml", {
    hostname = "vm-${var.name}-${count.index}"
  }))

  lifecycle {
    ignore_changes = [custom_data]  # Don't recreate on cloud-init changes
  }
}
```

---

## 2. Virtual Machine Scale Sets (VMSS)

```hcl
resource "azurerm_linux_virtual_machine_scale_set" "main" {
  name                = "vmss-${var.name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Standard_D2s_v3"
  instances           = 2  # Initial count

  admin_username                  = "azureuser"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Premium_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    name    = "nic-vmss"
    primary = true

    ip_configuration {
      name                                   = "internal"
      primary                                = true
      subnet_id                              = var.subnet_id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.main.id]
    }
  }

  # Automatic OS image updates
  automatic_os_upgrade_policy {
    enable_automatic_os_upgrade = true
    disable_automatic_rollback  = false
  }

  lifecycle {
    ignore_changes = [instances]  # Let autoscale manage instance count
  }
}

# Autoscale for VMSS
resource "azurerm_monitor_autoscale_setting" "vmss" {
  name                = "autoscale-${var.name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.main.id

  profile {
    name = "default"
    capacity { default = 2; minimum = 2; maximum = 10 }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.main.id
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
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.main.id
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
```

---

## 3. AKS Cluster

```hcl
resource "azurerm_kubernetes_cluster" "main" {
  name                = "aks-${var.name}-prod"
  resource_group_name = var.resource_group_name
  location            = var.location
  dns_prefix          = var.name
  kubernetes_version  = "1.28"

  # System node pool (runs kube-system pods)
  default_node_pool {
    name                = "system"
    node_count          = 3
    vm_size             = "Standard_D4s_v3"
    vnet_subnet_id      = var.aks_subnet_id
    os_disk_size_gb     = 128
    type                = "VirtualMachineScaleSets"
    enable_auto_scaling = true
    min_count           = 3
    max_count           = 5
    node_labels         = { "nodepool-type" = "system" }
    node_taints         = ["CriticalAddonsOnly=true:NoSchedule"]
  }

  identity {
    type = "SystemAssigned"
  }

  # Azure CNI networking (required for private endpoints, advanced networking)
  network_profile {
    network_plugin    = "azure"
    network_policy    = "calico"
    load_balancer_sku = "standard"
    service_cidr      = "172.16.0.0/16"
    dns_service_ip    = "172.16.0.10"
  }

  # Azure AD integration
  azure_active_directory_role_based_access_control {
    managed            = true
    azure_rbac_enabled = true
  }

  # Container Insights monitoring
  oms_agent {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }

  lifecycle {
    ignore_changes = [
      default_node_pool[0].node_count,  # Managed by autoscaler
      kubernetes_version                 # Managed by upgrade policy
    ]
  }
}

# User node pool for application workloads
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = "Standard_D4s_v3"
  vnet_subnet_id        = var.aks_subnet_id
  enable_auto_scaling   = true
  min_count             = 2
  max_count             = 20
  node_labels           = { "nodepool-type" = "user" }
}
```

---

## 4. Networking: Application Gateway

```hcl
resource "azurerm_application_gateway" "main" {
  name                = "agw-${var.name}"
  resource_group_name = var.resource_group_name
  location            = var.location

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 2
  }

  waf_configuration {
    enabled          = true
    firewall_mode    = "Prevention"
    rule_set_type    = "OWASP"
    rule_set_version = "3.2"
  }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = var.agw_subnet_id
  }

  frontend_ip_configuration {
    name                 = "frontend-ip"
    public_ip_address_id = azurerm_public_ip.agw.id
  }

  frontend_port {
    name = "https-port"
    port = 443
  }

  backend_address_pool {
    name  = "aks-backend"
    fqdns = [azurerm_kubernetes_cluster.main.fqdn]
  }

  backend_http_settings {
    name                  = "https-settings"
    cookie_based_affinity = "Disabled"
    port                  = 443
    protocol              = "Https"
    request_timeout       = 60
  }

  http_listener {
    name                           = "https-listener"
    frontend_ip_configuration_name = "frontend-ip"
    frontend_port_name             = "https-port"
    protocol                       = "Https"
    ssl_certificate_name           = "app-cert"
  }

  request_routing_rule {
    name                       = "routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "https-listener"
    backend_address_pool_name  = "aks-backend"
    backend_http_settings_name = "https-settings"
    priority                   = 100
  }
}
```

---

## 5. 3-Tier Architecture Pattern

```
Internet → Application Gateway (WAF) → Web Tier (AKS/App Service)
                                      → App Tier (AKS/Functions)
                                      → Data Tier (SQL + Redis)
                                            ↑
                                      Private Endpoints
```

Key design decisions:
- Each tier in its own subnet with NSG rules
- No direct internet access to app or data tiers
- Private endpoints for SQL, Redis, Storage, Key Vault
- Application Gateway as the single ingress point with WAF
- Managed Identities for all service-to-service authentication
