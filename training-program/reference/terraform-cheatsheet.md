# Terraform Cheatsheet

## Core Commands
```bash
terraform init              # Initialize, download providers
terraform fmt -recursive    # Format all .tf files
terraform validate          # Check syntax
terraform plan -out=tfplan  # Preview changes, save plan
terraform apply tfplan      # Apply saved plan
terraform destroy           # Destroy all resources
terraform show              # Show current state
terraform state list        # List resources in state
terraform state mv old new  # Rename resource in state
terraform state rm resource # Remove from state (don't destroy)
terraform import addr id    # Import existing resource
terraform output            # Show outputs
terraform force-unlock id   # Release stuck state lock
```

## HCL Quick Reference
```hcl
# Variable types
variable "name"   { type = string }
variable "count"  { type = number }
variable "flag"   { type = bool }
variable "list"   { type = list(string) }
variable "map"    { type = map(string) }
variable "obj"    { type = object({ name = string, size = number }) }

# Locals
locals {
  prefix = "${var.env}-${var.project}"
  tags   = merge(var.tags, { managed_by = "terraform" })
}

# for_each on map
resource "azurerm_resource_group" "envs" {
  for_each = { dev = "eastus2", prod = "westus2" }
  name     = "rg-${each.key}"
  location = each.value
}

# Dynamic block
dynamic "security_rule" {
  for_each = var.rules
  content {
    name     = security_rule.value.name
    priority = security_rule.value.priority
  }
}

# Conditional
sku = var.env == "prod" ? "Premium" : "Standard"

# Lifecycle
lifecycle {
  prevent_destroy       = true
  create_before_destroy = true
  ignore_changes        = [tags["last_modified"]]
}
```

## Common Functions
```hcl
lower("MyApp")                    # "myapp"
upper("myapp")                    # "MYAPP"
replace("my app", " ", "-")       # "my-app"
format("st%s%03d", "app", 1)      # "stapp001"
merge(map1, map2)                 # Merge maps
toset(["a", "b", "a"])            # {"a", "b"}
tomap({a = 1, b = 2})             # map
flatten([[1,2],[3,4]])             # [1,2,3,4]
lookup(map, "key", "default")     # Get value or default
length(list)                      # Count elements
file("path/to/file.txt")          # Read file content
templatefile("tmpl.yaml", vars)   # Render template
```

## Remote State (Azure Storage)
```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stterraformstate"
    container_name       = "tfstate"
    key                  = "myapp/prod/terraform.tfstate"
  }
}
```

## Provider Version Constraints
```hcl
version = "~> 3.90"   # >= 3.90, < 4.0 (recommended)
version = ">= 3.0"    # Any 3.x or higher
version = "= 3.90.0"  # Exact version (pin for production)
```

## Decision Matrix: count vs for_each
| Scenario | Use |
|----------|-----|
| Optional resource (0 or 1) | `count = var.enabled ? 1 : 0` |
| Multiple identical resources | `count = var.num_instances` |
| Resources with distinct identities | `for_each = toset(var.names)` |
| Resources from a map | `for_each = var.config_map` |
