# Module 7: Terraform Basics — Assessment

## Knowledge Checks

**Q1**: What is the difference between `terraform plan` and `terraform apply`?
**Answer**: `plan` shows what changes Terraform will make without making them — it's a dry run. `apply` executes the changes. Always run `plan` first and review the output before `apply`. In CI/CD, save the plan to a file (`terraform plan -out=tfplan`) and apply that exact plan (`terraform apply tfplan`) to ensure what you reviewed is what gets applied.

**Q2**: What does `~>` mean in a provider version constraint?
**Answer**: `~> 3.90` means "allow any version >= 3.90 and < 4.0" — it allows patch and minor updates but not major version upgrades. This prevents breaking changes from major version upgrades while still getting bug fixes and new features.

**Q3**: When would you use `terraform state rm`?
**Answer**: When you want to remove a resource from Terraform's state without destroying the actual Azure resource. Use cases: you're moving a resource to a different Terraform configuration, you want Terraform to "forget" about a resource that will be managed manually, or you're refactoring and will re-import the resource with a new address.

**Q4**: What is the purpose of `terraform.tfvars`?
**Answer**: A file that provides values for input variables. Terraform automatically loads `terraform.tfvars` if it exists. Use separate `.tfvars` files per environment: `dev.tfvars`, `prod.tfvars`. Never commit sensitive values (passwords, keys) to `.tfvars` — use environment variables (`TF_VAR_password`) or Key Vault references instead.

---

## Practical Task: Deploy Foundation Infrastructure

Deploy a VNet with 3 subnets and NSGs using Terraform with remote state.

```bash
# Validation
terraform init
terraform validate
terraform plan -out=tfplan
terraform apply tfplan

# Verify resources
az network vnet show --name vnet-myapp --resource-group rg-myapp-dev
az network nsg list --resource-group rg-myapp-dev --query "[].name"

# Verify remote state
az storage blob list \
  --account-name stterraformstate001 \
  --container-name tfstate \
  --query "[].name"
```

---

## Rubric

### Criterion 1: Terraform Configuration Quality
| Level | Description |
|-------|-------------|
| Exemplary (4) | Uses remote state with locking, pins provider versions, uses variables and locals, applies `prevent_destroy` on critical resources, uses `ignore_changes` appropriately, all resources tagged. |
| Proficient (3) | Uses remote state, variables, and tags. Provider version pinned. Minor gaps in lifecycle rules. |
| Developing (2) | Uses local state or remote state without locking. Hard-coded values instead of variables. |
| Beginning (1) | Cannot write valid HCL. Does not understand state or provider configuration. |
