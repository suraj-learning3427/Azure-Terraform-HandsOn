# Module 8: Terraform Advanced — Theory

## 1. Modules

### 1.1 Module Structure
```
modules/networking/
├── main.tf        # Resources
├── variables.tf   # Input variables
├── outputs.tf     # Output values
├── versions.tf    # Provider requirements
└── README.md      # Usage documentation
```

### 1.2 Creating a Reusable Networking Module
```hcl
# modules/networking/variables.tf
variable "resource_group_name" { type = string }
variable "location"            { type = string }
variable "vnet_name"           { type = string }
variable "address_space"       { type = list(string) }
variable "subnets" {
  type = map(object({
    address_prefix = string
    nsg_rules      = list(object({
      name                   = string
      priority               = number
      direction              = string
      access                 = string
      protocol               = string
      source_port_range      = string
      destination_port_range = string
      source_address_prefix  = string
    }))
  }))
}

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
  address_prefixes     = [each.value.address_prefix]
}

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
    web  = { address_prefix = "10.0.1.0/24", nsg_rules = [] }
    app  = { address_prefix = "10.0.2.0/24", nsg_rules = [] }
    data = { address_prefix = "10.0.3.0/24", nsg_rules = [] }
  }
}
```

---

## 2. Dynamic Blocks

```hcl
# Dynamic NSG rules from a variable map
variable "nsg_rules" {
  type = list(object({
    name                   = string
    priority               = number
    direction              = string
    access                 = string
    protocol               = string
    source_port_range      = string
    destination_port_range = string
    source_address_prefix  = string
  }))
  default = []
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
      protocol                   = security_rule.value.protocol
      source_port_range          = security_rule.value.source_port_range
      destination_port_range     = security_rule.value.destination_port_range
      source_address_prefix      = security_rule.value.source_address_prefix
      destination_address_prefix = "*"
    }
  }
}
```

---

## 3. Terraform Functions

```hcl
locals {
  # String functions
  app_name    = lower(replace(var.project_name, " ", "-"))
  env_upper   = upper(var.environment)
  
  # Collection functions
  all_subnets = flatten([
    module.networking_eastus.subnet_ids,
    module.networking_westus.subnet_ids
  ])
  
  subnet_map = tomap({
    for subnet in var.subnets : subnet.name => subnet.address_prefix
  })
  
  # Merge maps
  all_tags = merge(var.common_tags, {
    environment = var.environment
    managed_by  = "terraform"
  })
  
  # Conditional
  sku = var.environment == "prod" ? "Premium" : "Standard"
  
  # Lookup with default
  region_code = lookup(var.region_codes, var.location, "unknown")
  
  # Format string
  storage_name = format("st%s%s%03d", local.app_name, var.environment, var.instance_number)
  
  # File content
  init_script = file("${path.module}/scripts/init.sh")
  
  # Template file with variables
  cloud_init = templatefile("${path.module}/templates/cloud-init.yaml", {
    hostname = var.vm_name
    packages = var.packages
  })
}
```

---

## 4. Data Sources

```hcl
# Reference existing resources without managing them
data "azurerm_resource_group" "existing" {
  name = "rg-shared-services"
}

data "azurerm_virtual_network" "shared" {
  name                = "vnet-shared"
  resource_group_name = data.azurerm_resource_group.existing.name
}

data "azurerm_key_vault" "shared" {
  name                = "kv-shared-prod"
  resource_group_name = data.azurerm_resource_group.existing.name
}

data "azurerm_key_vault_secret" "db_password" {
  name         = "DatabasePassword"
  key_vault_id = data.azurerm_key_vault.shared.id
}

# Use in resource
resource "azurerm_linux_web_app" "main" {
  # ...
  app_settings = {
    "DB_PASSWORD" = data.azurerm_key_vault_secret.db_password.value
  }
}

# Get current subscription info
data "azurerm_subscription" "current" {}
data "azurerm_client_config" "current" {}

output "subscription_id" {
  value = data.azurerm_subscription.current.subscription_id
}
```

---

## 5. count vs for_each

```hcl
# count: use for identical resources (index-based)
resource "azurerm_virtual_machine" "workers" {
  count = 3
  name  = "vm-worker-${count.index}"
  # ...
}
# Problem: removing vm-worker-1 shifts indexes, causing vm-worker-2 to be destroyed and recreated

# for_each: use for distinct resources (key-based, stable)
resource "azurerm_virtual_machine" "workers" {
  for_each = toset(["worker-a", "worker-b", "worker-c"])
  name     = "vm-${each.key}"
  # ...
}
# Removing "worker-b" only destroys that VM, others unchanged

# for_each with map
resource "azurerm_resource_group" "environments" {
  for_each = {
    dev     = "eastus2"
    staging = "eastus2"
    prod    = "westus2"
  }
  name     = "rg-myapp-${each.key}"
  location = each.value
}
```

---

## 6. Provisioners (Use Sparingly)

```hcl
resource "azurerm_linux_virtual_machine" "main" {
  # ...

  # local-exec: runs on the machine running Terraform
  provisioner "local-exec" {
    command = "echo ${self.private_ip_address} >> inventory.txt"
  }

  # remote-exec: runs on the remote VM via SSH
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y nginx"
    ]
    connection {
      type        = "ssh"
      user        = "azureuser"
      private_key = file("~/.ssh/id_rsa")
      host        = self.public_ip_address
    }
  }
}
```

**Warning**: Provisioners are a last resort. Prefer cloud-init, custom script extensions, or configuration management tools (Ansible, Chef). Provisioners don't run on subsequent applies and can leave resources in inconsistent state.
