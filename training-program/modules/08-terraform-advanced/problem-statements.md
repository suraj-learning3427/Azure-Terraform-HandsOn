# Module 8: Terraform Advanced — Problem Statements

## Scenario A: Reusable Module Library

### Business Context
A platform team needs to create a library of Terraform modules for common Azure patterns (networking, compute, database) that application teams can consume with minimal configuration and consistent standards.

### Technical Requirements
1. `networking` module: VNet + subnets + NSGs with dynamic rules from variable map
2. `compute` module: App Service Plan + Web App with configurable SKU and settings
3. `database` module: Azure SQL with configurable tier, TDE, and backup retention
4. Each module: `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, `README.md`
5. Module versioning: publish to Azure DevOps Artifacts or Terraform Registry
6. Example usage in `examples/` directory for each module
7. Input validation: use `validation` blocks to enforce naming conventions and valid SKUs

### Success Criteria
1. Application team can deploy a 3-tier app using 3 module calls (< 50 lines of code)
2. All modules pass `terraform validate` and `terraform fmt` checks
3. Module README documents all variables, outputs, and example usage
4. Breaking changes increment major version

---

## Scenario B: Dynamic NSG Rule Management

### Business Context
A security team needs to manage 50+ NSG rules across 5 environments using a single Terraform configuration with dynamic blocks driven by a YAML/JSON variable file. Rules must be auditable and version-controlled.

### Technical Requirements
1. NSG rules defined in `nsg_rules.yaml` (version-controlled)
2. Terraform reads YAML file using `yamldecode(file(...))`
3. Dynamic blocks generate NSG rules from the YAML data
4. `for_each` creates NSGs for each environment from a map
5. Rules tagged with: owner, ticket_number, expiry_date
6. Automated check: rules with `expiry_date` in the past trigger a Terraform plan warning

### Success Criteria
1. Adding a new NSG rule requires only editing the YAML file
2. `terraform plan` shows exactly which rules will be added/removed
3. All 50+ rules deployed correctly across all 5 environments
4. Expired rules identified in plan output
