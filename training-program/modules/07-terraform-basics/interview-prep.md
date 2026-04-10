# Module 7: Terraform Basics — Interview Preparation

## Q1 (Conceptual): Terraform State
**Question**: What is Terraform state and why is it important?

**Sample Answer**: Terraform state is a JSON file that maps your Terraform configuration to real-world resources. It tracks resource IDs, attributes, and dependencies. Without state, Terraform can't know what already exists — it would try to create everything from scratch on every apply. State is critical for: tracking resource metadata (IDs, attributes), detecting drift (differences between config and reality), planning changes (what to create/update/destroy), and managing dependencies between resources. In teams, remote state (Azure Storage, Terraform Cloud) is essential — local state causes conflicts when multiple people run Terraform.

---

## Q2 (Scenario): Terraform Plan Shows Unexpected Destroy
**Question**: You run `terraform plan` and it shows it will destroy and recreate your production database. You didn't change anything. What do you do?

**Sample Answer**: Don't panic and don't apply. First, understand why: 1) Check the plan output carefully — what attribute changed? 2) Common causes: provider version upgrade changed a default value, someone manually changed the resource in Azure (drift), a required attribute was added to the provider. 3) If it's drift: use `terraform import` to sync state, or use `ignore_changes` for the drifted attribute. 4) If it's a provider change: check the provider changelog for breaking changes. 5) If the destroy is truly unexpected: add `prevent_destroy = true` to the resource as a safety net. Never apply a plan that destroys production databases without understanding exactly why.

---

## Q3 (Design): Multi-Environment Terraform Structure
**Question**: How do you structure Terraform code for dev/staging/prod environments?

**Sample Answer**: I use workspaces or separate state files per environment. My preferred approach — separate directories with shared modules:
```
infrastructure/
├── modules/
│   ├── networking/
│   ├── compute/
│   └── database/
├── environments/
│   ├── dev/
│   │   ├── main.tf      # calls modules
│   │   ├── variables.tf
│   │   └── terraform.tfvars
│   ├── staging/
│   └── prod/
```
Each environment has its own state file: `myapp/dev/terraform.tfstate`, `myapp/prod/terraform.tfstate`. This provides complete isolation — a mistake in dev can't affect prod state. Modules are reused across environments with different variable values.

---

## Q4 (Troubleshooting): State Lock Not Released
**Question**: A CI pipeline crashed mid-apply and now Terraform state is locked. How do you resolve this?

**Sample Answer**: 1) Verify the lock is stale — check if any Terraform process is actually running. 2) Get the lock ID from the error message or from the Azure Storage blob lease. 3) Release the lock: `terraform force-unlock <lock-id>`. 4) Verify the state is consistent: `terraform plan` should show the expected state. 5) If the apply was partially complete, some resources may have been created — `terraform plan` will show what's missing. 6) Prevention: set pipeline timeouts so crashed pipelines release locks, use `terraform apply -lock-timeout=5m` to wait for locks instead of failing immediately.
