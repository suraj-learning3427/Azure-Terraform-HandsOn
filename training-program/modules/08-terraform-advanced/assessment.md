# Module 8: Terraform Advanced — Assessment

## Knowledge Checks

**Q1**: What is the purpose of `outputs.tf` in a Terraform module?
**Answer**: Outputs expose values from a module to the calling configuration. They allow the parent module to reference child module resources (e.g., `module.networking.subnet_ids`). Without outputs, the parent can't access any values from the child module. Outputs are also used to display important values after `terraform apply` (e.g., the public IP of a load balancer).

**Q2**: What does `templatefile()` do and when would you use it?
**Answer**: `templatefile()` reads a file and renders it as a template, substituting `${variable}` placeholders with provided values. Use it for: cloud-init scripts that need dynamic values (hostname, packages), Kubernetes manifests with environment-specific values, or any configuration file that needs to be parameterized. It's cleaner than `file()` + string interpolation for complex templates.

**Q3**: What is the difference between a data source and a resource in Terraform?
**Answer**: A `resource` block creates and manages an Azure resource — Terraform owns its lifecycle. A `data` source reads information about an existing resource that Terraform doesn't manage. Use data sources to reference shared infrastructure (existing VNets, Key Vaults, subscriptions) without importing them into your state. Data sources are read-only — they never create or modify resources.

**Q4**: When should you NOT use a Terraform provisioner?
**Answer**: Almost always. Provisioners run only on resource creation (not updates), don't integrate with Terraform's plan/apply lifecycle, can leave resources in inconsistent state if they fail, and make infrastructure harder to reason about. Prefer: cloud-init for VM initialization, Azure Custom Script Extension for post-deployment configuration, or configuration management tools (Ansible). Use provisioners only as a last resort when no native Terraform/Azure mechanism exists.

---

## Practical Task: Create a Reusable Networking Module

Create a `networking` module that accepts a map of subnets with NSG rules and deploys them using dynamic blocks.

```bash
# Validation
cd modules/networking
terraform init
terraform validate
terraform fmt -check

# Test with example
cd examples/basic
terraform init
terraform plan
# Expected: plan shows VNet + subnets + NSGs with correct rules
```

---

## Rubric

### Criterion 1: Module Design Quality
| Level | Description |
|-------|-------------|
| Exemplary (4) | Module has complete structure (main/variables/outputs/versions/README). Uses `for_each` for collections. Dynamic blocks for variable-length configurations. Input validation with `validation` blocks. Outputs expose all useful values. |
| Proficient (3) | Module has main/variables/outputs. Uses `for_each` correctly. Dynamic blocks work. Minor gaps in validation or documentation. |
| Developing (2) | Module exists but uses `count` instead of `for_each`. Missing outputs or variables. No dynamic blocks. |
| Beginning (1) | Cannot create a module. Copies resources directly instead of abstracting into a module. |
