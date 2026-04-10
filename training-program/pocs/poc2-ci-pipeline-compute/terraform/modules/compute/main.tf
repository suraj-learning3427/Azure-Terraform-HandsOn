# Compute Module: VMSS + Load Balancer + Autoscale

resource "azurerm_public_ip" "lb" {
  name                = "pip-lb-${var.name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_lb" "main" {
  name                = "lb-${var.name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Standard"
  tags                = var.tags

  frontend_ip_configuration {
    name                 = "frontend"
    public_ip_address_id = azurerm_public_ip.lb.id
  }
}

resource "azurerm_lb_backend_address_pool" "main" {
  loadbalancer_id = azurerm_lb.main.id
  name            = "backend-pool"
}

resource "azurerm_lb_probe" "health" {
  loadbalancer_id = azurerm_lb.main.id
  name            = "health-probe"
  protocol        = "Http"
  port            = 80
  request_path    = "/health"
}

resource "azurerm_lb_rule" "http" {
  loadbalancer_id                = azurerm_lb.main.id
  name                           = "http-rule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.main.id]
  probe_id                       = azurerm_lb_probe.health.id
}

resource "azurerm_linux_virtual_machine_scale_set" "main" {
  name                = "vmss-${var.name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.vm_size
  instances           = var.min_instances
  tags                = var.tags

  admin_username                  = "azureuser"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = var.ssh_public_key
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
    name    = "nic"
    primary = true
    ip_configuration {
      name                                   = "internal"
      primary                                = true
      subnet_id                              = var.subnet_id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.main.id]
    }
  }

  identity { type = "SystemAssigned" }

  lifecycle { ignore_changes = [instances] }
}

resource "azurerm_monitor_autoscale_setting" "main" {
  name                = "autoscale-${var.name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.main.id

  profile {
    name = "default"
    capacity { default = var.min_instances; minimum = var.min_instances; maximum = var.max_instances }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.main.id
        time_grain         = "PT1M"; statistic = "Average"; time_window = "PT5M"
        time_aggregation   = "Average"; operator = "GreaterThan"; threshold = 70
      }
      scale_action { direction = "Increase"; type = "ChangeCount"; value = "2"; cooldown = "PT5M" }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.main.id
        time_grain         = "PT1M"; statistic = "Average"; time_window = "PT10M"
        time_aggregation   = "Average"; operator = "LessThan"; threshold = 30
      }
      scale_action { direction = "Decrease"; type = "ChangeCount"; value = "1"; cooldown = "PT10M" }
    }
  }
}
