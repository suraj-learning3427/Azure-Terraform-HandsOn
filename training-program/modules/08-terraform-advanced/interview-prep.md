# Module 8: Terraform Advanced — Interview Preparation

## Q1 (Conceptual): count vs for_each
**Question**: When would you use `count` vs `for_each`? What's the risk of using `count` for a list of resources?

**Sample Answer**: Use `for_each` for almost everything. The problem with `count` is index instability: if you have 3 VMs at indexes 0, 1, 2 and remove the middle one, Terraform sees index 1 as changed (now points to what was index 2) and index 2 as deleted. This causes unnecessary destroy/recreate of resources. `for_each` uses stable keys — removing "worker-b" only affects that resource. Use `count` only for truly identical resources where you don't care about individual identity (e.g., `count = var.enable_feature ? 1 : 0` for optional resources).

---

## Q2 (Scenario): Module Versioning Strategy
**Question**: Your platform team publishes Terraform modules. A breaking change is needed in the networking module. How do you handle versioning?

**Sample Answer**: Follow semantic versioning: breaking changes = major version bump. Process: 1) Create a new major version branch (`v2`). 2) Update the module with breaking changes. 3) Publish as `v2.0.0`. 4) Update the module README with migration guide from v1 to v2. 5) Notify consuming teams — give them a deprecation window (e.g., 3 months). 6) Keep v1 available for teams that haven't migrated. In consuming configurations: `source = "git::https://dev.azure.com/myorg/modules//networking?ref=v2.0.0"`. Teams pin to a specific version and upgrade on their own schedule.

---

## Q3 (Design): Terraform for Multi-Region Deployment
**Question**: How would you use Terraform to deploy the same infrastructure to 3 Azure regions?

**Sample Answer**: Use `for_each` on a map of regions with a module call:
```hcl
locals {
  regions = {
    eastus2   = { location = "East US 2",   short = "eus2" }
    westus2   = { location = "West US 2",   short = "wus2" }
    westeurope = { location = "West Europe", short = "weu"  }
  }
}

module "regional_infra" {
  for_each = local.regions
  source   = "./modules/regional"
  location = each.value.location
  name_suffix = each.value.short
}
```
Each region gets its own state key: `myapp/prod/eastus2/terraform.tfstate`. This approach is clean, DRY, and easy to add/remove regions by editing the map.

---

## Q4 (Troubleshooting): Terraform Plan Shows Resource Recreation
**Question**: After upgrading the AzureRM provider from 3.85 to 3.90, `terraform plan` shows your AKS cluster will be destroyed and recreated. How do you handle this?

**Sample Answer**: 1) Check the AzureRM provider changelog for 3.85→3.90 — look for breaking changes to `azurerm_kubernetes_cluster`. 2) If it's a known provider issue, check GitHub issues for workarounds. 3) Use `ignore_changes` for the specific attribute causing the recreation: `lifecycle { ignore_changes = [specific_attribute] }`. 4) If the recreation is unavoidable, plan a maintenance window and use `create_before_destroy = true` to minimize downtime. 5) For production, always test provider upgrades in dev first. Pin provider versions in production: `version = "= 3.85.0"` (exact pin) until you've validated the upgrade.
