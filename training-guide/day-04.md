# Day 4 — Apr 14 | DevOps Fundamentals + Terraform Modules
**Presenters**: Sabari & Shruthi

---

## What You'll Learn Today
- Agile, DORA metrics, Git workflows, branch policies, technical debt
- Terraform modules in depth, for_each patterns, multi-environment structure

---

## Part 1: DevOps Fundamentals

### DORA Metrics — Must Know for Every Interview

| Metric | What It Measures | Elite | Low |
|--------|-----------------|-------|-----|
| Deployment Frequency | How often you deploy to production | Multiple/day | < Monthly |
| Lead Time for Changes | Commit → production | < 1 hour | > 1 month |
| Change Failure Rate | % of deployments causing incidents | 0–5% | > 15% |
| Time to Restore | How long to recover from incidents | < 1 hour | > 1 week |

**Why they matter**: Research shows elite DORA performers have 2x better business outcomes. These metrics come up in almost every DevOps interview.

### Git Workflows

**Trunk-Based Development** (recommended for CI/CD):
- Everyone commits to `main` at least daily
- Feature branches live < 2 days
- Feature flags hide incomplete features in production
- Enables true continuous integration

**GitFlow** (traditional, scheduled releases):
```
main ──────────────────────── (production releases)
  └── develop ──────────────── (integration)
        ├── feature/login ──── (merged to develop)
        └── release/1.2 ────── (merged to main + develop)
```

**Rule**: Use trunk-based for teams doing CI/CD. Use GitFlow only for products with scheduled quarterly releases.

### Branch Policies in Azure DevOps
```bash
# Require 2 reviewers on main
az repos policy approver-count create \
  --repository-id <repo-id> \
  --branch main \
  --minimum-approver-count 2 \
  --creator-vote-counts false \
  --reset-on-source-push true \
  --project myProject \
  --org https://dev.azure.com/myOrg

# Require CI build to pass before merge
az repos policy build create \
  --repository-id <repo-id> \
  --branch main \
  --build-definition-id <pipeline-id> \
  --display-name "CI Build Validation" \
  --project myProject \
  --org https://dev.azure.com/myOrg
```

**PR Template** (add `.azuredevops/pull_request_template.md`):
```markdown
## What does this PR do?

## Checklist
- [ ] Unit tests written and passing
- [ ] Code coverage maintained or improved
- [ ] No hardcoded secrets or credentials
- [ ] Documentation updated
- [ ] Security implications considered
```

### Technical Debt
- Allocate **20% of each sprint** to debt reduction
- Track debt as work items tagged `TechDebt` in Azure Boards
- Use SonarCloud to measure: code smells, bugs, vulnerabilities, coverage
- **Quality gate**: 0 new bugs, 0 new vulnerabilities, coverage > 80% on new code

---

## Part 2: Terraform Modules Deep Dive

### Multi-Environment Structure (Best Practice)
```
infrastructure/
├── modules/
│   ├── networking/    # Reusable VNet + subnets + NSGs
│   ├── compute/       # Reusable App Service / VMSS
│   └── database/      # Reusable SQL + private endpoint
└── environments/
    ├── dev/
    │   ├── main.tf          # Calls modules
    │   ├── variables.tf
    │   └── terraform.tfvars # dev-specific values
    ├── staging/
    └── prod/
```

Each environment has its own state file:
- `myapp/dev/terraform.tfstate`
- `myapp/prod/terraform.tfstate`

### for_each with Maps — Create Multiple Environments
```hcl
# Create resource groups for all environments in one block
variable "environments" {
  type = map(string)
  default = {
    dev     = "eastus2"
    staging = "eastus2"
    prod    = "westus2"
  }
}

resource "azurerm_resource_group" "envs" {
  for_each = var.environments
  name     = "rg-myapp-${each.key}"
  location = each.value
  tags     = { environment = each.key }
}

# Reference: azurerm_resource_group.envs["prod"].name
```

### Terraform Functions Quick Reference
```hcl
locals {
  # String
  app_name = lower(replace(var.project, " ", "-"))  # "my app" → "my-app"
  env_tag  = upper(var.environment)                  # "dev" → "DEV"

  # Collections
  all_tags = merge(var.common_tags, { environment = var.env })
  subnet_set = toset(["web", "app", "data"])

  # Conditional
  sku = var.environment == "prod" ? "P2v3" : "B1"

  # Format
  storage_name = format("st%s%s", var.project, var.environment)
}
```

---

## POC 2: CI Pipeline Setup + VMSS Infrastructure

### Step 1: Create Azure DevOps Project and Pipeline
1. Go to dev.azure.com → New Project
2. Create a repo and push your code
3. Set branch policy on `main`: require 2 reviewers + build validation

### Step 2: Terraform for VMSS
```hcl
# Using the networking module from Day 3
module "networking" {
  source              = "../../modules/networking"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  vnet_name           = "vnet-poc2-dev"
  address_space       = ["10.1.0.0/16"]
  subnets             = { web = "10.1.1.0/24", data = "10.1.2.0/24" }
}

# VMSS
resource "azurerm_linux_virtual_machine_scale_set" "main" {
  name                = "vmss-poc2-dev"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Standard_D2s_v3"
  instances           = 2

  admin_username                  = "azureuser"
  disable_password_authentication = true
  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  source_image_reference {
    publisher = "Canonical"; offer = "0001-com-ubuntu-server-jammy"
    sku = "22_04-lts-gen2"; version = "latest"
  }

  os_disk { storage_account_type = "Premium_LRS"; caching = "ReadWrite" }

  network_interface {
    name    = "nic"
    primary = true
    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = module.networking.subnet_ids["web"]
    }
  }

  lifecycle { ignore_changes = [instances] }  # Let autoscale manage count
}
```

### Step 3: Validate
```bash
terraform apply
az vmss list-instances --name vmss-poc2-dev --resource-group rg-poc2-dev \
  --query "length(@)" -o tsv
# Expected: 2
```

---

## Interview Q&A — Day 4 Topics

**Q: What are the four DORA metrics?**
A: Deployment Frequency (how often you deploy to production), Lead Time for Changes (time from commit to production), Change Failure Rate (% of deployments causing incidents), and Time to Restore Service (how long to recover). Elite teams deploy multiple times per day with < 1 hour lead time, < 5% failure rate, and < 1 hour recovery time.

**Q: Compare trunk-based development with GitFlow.**
A: Trunk-based: everyone commits to main daily, short-lived branches (< 2 days), feature flags for incomplete work. Enables true CI/CD. GitFlow: long-lived branches (develop, release, hotfix), suited for scheduled releases. Trunk-based is better for teams doing continuous deployment — it eliminates merge conflicts and keeps the codebase always deployable.

**Q: How do you structure Terraform for multiple environments?**
A: Separate directories per environment (`environments/dev/`, `environments/prod/`) each with their own state file. Shared logic goes in `modules/`. Each environment calls the same modules with different variable values. This gives complete isolation — a mistake in dev can't affect prod state. Never use Terraform workspaces for environment isolation — they share the same backend and are harder to manage.

**Q: What is a blameless post-mortem?**
A: A post-incident review that focuses on systemic causes rather than blaming individuals. The goal is to identify what failed in the process or system and how to prevent recurrence. Psychological safety is essential — people must feel safe reporting mistakes. Output: timeline of events, root cause analysis, action items with owners and due dates.

**Q: How do you manage technical debt without stopping feature development?**
A: Allocate 20% of each sprint to debt reduction (the "20% rule"). Track debt as work items in Azure Boards with a `TechDebt` tag. Use SonarCloud to quantify debt objectively. Set a quality gate: no new issues can be introduced in any PR. This way debt doesn't grow while you gradually reduce existing debt.
