# Module 7: Terraform Basics — Problem Statements

## Scenario A: Infrastructure Bootstrapping

### Business Context
A new project needs foundational Azure infrastructure (resource group, storage account, virtual network with subnets, NSGs) provisioned consistently across dev/staging/prod environments using Terraform with remote state.

### Technical Requirements
1. Terraform configuration for: Resource Group, Storage Account (remote state), VNet (10.0.0.0/16), 3 subnets (web/app/data), NSGs with appropriate rules
2. Remote state backend in Azure Storage with state locking
3. `terraform.tfvars` files for dev/staging/prod with different values
4. All resources tagged: environment, team, cost_center, managed_by=terraform
5. NSG rules: web subnet allows 443 inbound; app subnet allows traffic from web subnet only; data subnet allows traffic from app subnet only
6. `prevent_destroy = true` on resource group and storage account

### Success Criteria
1. `terraform plan` shows 0 changes after initial apply (idempotent)
2. State stored in Azure Storage, not local
3. Running `terraform apply` in dev and prod creates separate, isolated environments
4. All resources have required tags

---

## Scenario B: State Management Migration

### Business Context
A team has been using local Terraform state for 6 months. They now have 3 developers and state conflicts are causing issues. They need to migrate to remote state in Azure Storage without destroying and recreating resources.

### Technical Requirements
1. Create Azure Storage account for remote state
2. Migrate existing local state to remote backend without resource recreation
3. Configure state locking
4. Enable blob versioning for state file history (rollback capability)
5. Document the migration procedure for the team

### Success Criteria
1. `terraform state list` shows all existing resources after migration
2. No resources were destroyed and recreated during migration
3. State file exists in Azure Storage blob
4. Second developer can run `terraform plan` successfully (state locking works)
