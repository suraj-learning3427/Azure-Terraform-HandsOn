# Networking Module: VNet + Subnets + NSGs with dynamic rules

resource "azurerm_virtual_network" "main" {
  name                = var.vnet_name
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = var.address_space
  tags                = var.tags
}

resource "azurerm_subnet" "main" {
  for_each             = var.subnets
  name                 = each.key
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [each.value.address_prefix]
}

resource "azurerm_network_security_group" "main" {
  name                = "nsg-${var.vnet_name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  # Dynamic NSG rules from variable — no hardcoded rules
  dynamic "security_rule" {
    for_each = var.nsg_rules
    content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      direction                  = security_rule.value.direction
      access                     = security_rule.value.access
      protocol                   = security_rule.value.protocol
      source_port_range          = security_rule.value.source_port_range
      destination_port_range     = security_rule.value.destination_port_range
      source_address_prefix      = security_rule.value.source_address_prefix
      destination_address_prefix = "*"
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "web" {
  subnet_id                 = azurerm_subnet.main["web"].id
  network_security_group_id = azurerm_network_security_group.main.id
}
