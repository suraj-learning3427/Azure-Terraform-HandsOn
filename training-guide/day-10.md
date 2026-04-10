# Day 10 — Apr 28 | Infrastructure + App Pipeline (Full POC 4)
**Presenters**: Vijay & Manju

---

## What You'll Learn Today
- OIDC federated identity for pipelines (no stored secrets)
- Key Vault + Service Principal + Azure Policy + Monitoring — all together
- Full pipeline: Terraform provisions infra → App deploys on top

---

## Part 1: OIDC Federated Identity for Azure DevOps

### Why OIDC?
Traditional approach: store service principal secret in Azure DevOps → secret expires, gets leaked, needs rotation.
OIDC approach: Azure DevOps pipeline gets a short-lived token from Microsoft's identity provider → Azure trusts it → no stored secrets.

### Setup
```bash
# 1. Create app registration
az ad app create --display-name "sp-terraform-pipeline"
APP_ID=$(az ad app list --display-name "sp-terraform-pipeline" --query "[0].appId" -o tsv)
az ad sp create --id $APP_ID
SP_OBJECT_ID=$(az ad sp show --id $APP_ID --query id -o tsv)

# 2. Add federated credential for Azure DevOps
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "ado-pipeline-prod",
    "issuer": "https://vstoken.dev.azure.com/myOrganization",
    "subject": "sc://myOrganization/myProject/MyServiceConnection",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# 3. Grant Contributor on subscription
az role assignment create \
  --role Contributor \
  --assignee $SP_OBJECT_ID \
  --scope /subscriptions/$(az account show --query id -o tsv)

# 4. In Azure DevOps: create service connection using Workload Identity Federation
# Project Settings → Service Connections → New → Azure Resource Manager
# → Workload Identity Federation (automatic)
# → Enter: Subscription, Resource Group, Service Principal App ID
```

### Use in Pipeline (No Secrets Needed)
```yaml
- task: AzureCLI@2
  inputs:
    azureSubscription: 'MyOIDCServiceConnection'  # Uses federated identity
    scriptType: bash
    inlineScript: |
      # This runs as the service principal — no password stored anywhere
      terraform init
      terraform plan -out=tfplan
      terraform apply tfplan
```

---

## Part 2: POC 4 — Full Infrastructure + App Pipeline

### What This POC Builds
```
Azure DevOps Pipeline (OIDC auth)
    ↓
Stage 1: Terraform Apply
    → Resource Group, VNet, Key Vault (RBAC)
    → Azure Policy Initiative (tagging + regions)
    → Log Analytics + Application Insights + Alerts
    → App Service with Managed Identity

Stage 2: App Deploy
    → Deploy app to staging slot
    → App reads secrets from Key Vault via Managed Identity
    → Swap to production
```

### Terraform Configuration
```hcl
# main.tf — POC 4 complete infrastructure

# Log Analytics
resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-poc4-prod"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "PerGB2018"
  retention_in_days   = 90
}

# Application Insights
resource "azurerm_application_insights" "main" {
  name                = "appi-poc4-prod"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"
}

# Key Vault with RBAC
resource "azurerm_key_vault" "main" {
  name                      = "kv-poc4-prod"
  resource_group_name       = azurerm_resource_group.main.name
  location                  = azurerm_resource_group.main.location
  tenant_id                 = data.azurerm_client_config.current.tenant_id
  sku_name                  = "standard"
  enable_rbac_authorization = true
  purge_protection_enabled  = true
}

# App Service with Managed Identity
resource "azurerm_linux_web_app" "main" {
  name                = "app-poc4-prod"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.main.id
  https_only          = true

  identity { type = "SystemAssigned" }

  site_config {
    application_stack { dotnet_version = "8.0" }
    application_insights_connection_string = azurerm_application_insights.main.connection_string
  }

  app_settings = {
    # Key Vault reference — no plaintext secrets
    "ConnectionStrings__Default" = "@Microsoft.KeyVault(VaultName=kv-poc4-prod;SecretName=SqlConnectionString)"
  }
}

# Grant App Service access to Key Vault
resource "azurerm_role_assignment" "app_kv" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app.main.identity[0].principal_id
}

# Azure Policy: require tags
resource "azurerm_policy_assignment" "require_env_tag" {
  name                 = "require-environment-tag"
  scope                = data.azurerm_subscription.current.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/96670d01-0a4d-4649-9c89-2d3abc0a5025"
  display_name         = "Require environment tag"
  parameters           = jsonencode({ tagName = { value = "environment" } })
}

# Alert: high error rate
resource "azurerm_monitor_metric_alert" "error_rate" {
  name                = "alert-error-rate"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_application_insights.main.id]
  severity            = 1

  criteria {
    metric_namespace = "microsoft.insights/components"
    metric_name      = "requests/failed"
    aggregation      = "Count"
    operator         = "GreaterThan"
    threshold        = 10
  }

  action { action_group_id = azurerm_monitor_action_group.ops.id }
  frequency   = "PT1M"
  window_size = "PT5M"
}
```

### Full Pipeline YAML
```yaml
# azure-pipelines.yml — POC 4: Infra + App
trigger:
  branches:
    include: [main]

stages:
  # ── Stage 1: Provision Infrastructure with Terraform ────────────────────────
  - stage: Infra
    displayName: Provision Infrastructure
    jobs:
      - job: TerraformApply
        pool:
          vmImage: ubuntu-latest
        steps:
          - task: AzureCLI@2
            displayName: Terraform Init + Plan + Apply
            inputs:
              azureSubscription: 'MyOIDCServiceConnection'
              scriptType: bash
              addSpnToEnvironment: true  # Injects ARM_CLIENT_ID etc.
              inlineScript: |
                export ARM_USE_OIDC=true
                export ARM_OIDC_TOKEN=$idToken
                export ARM_TENANT_ID=$tenantId
                export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
                export ARM_CLIENT_ID=$servicePrincipalId

                cd terraform
                terraform init
                terraform plan -out=tfplan
                terraform apply tfplan

  # ── Stage 2: Deploy Application ─────────────────────────────────────────────
  - stage: Deploy
    displayName: Deploy Application
    dependsOn: Infra
    jobs:
      - deployment: DeployApp
        environment: production
        pool:
          vmImage: ubuntu-latest
        strategy:
          runOnce:
            deploy:
              steps:
                - task: DotNetCoreCLI@2
                  inputs:
                    command: publish
                    arguments: '--configuration Release --output $(Build.ArtifactStagingDirectory)'

                - task: AzureWebApp@1
                  inputs:
                    azureSubscription: 'MyOIDCServiceConnection'
                    appName: app-poc4-prod
                    deployToSlotOrASE: true
                    slotName: staging
                    package: $(Build.ArtifactStagingDirectory)/**/*.zip

                - task: AzureAppServiceManage@0
                  inputs:
                    azureSubscription: 'MyOIDCServiceConnection'
                    Action: 'Swap Slots'
                    WebAppName: app-poc4-prod
                    ResourceGroupName: rg-poc4-prod
                    SourceSlot: staging
```

### Validate POC 4
```bash
# No stored credentials in pipeline
# (Verify by checking Azure DevOps service connection — should show "Workload Identity Federation")

# Key Vault audit log shows app access
az monitor activity-log list \
  --resource-group rg-poc4-prod \
  --resource-type Microsoft.KeyVault/vaults \
  --query "[?operationName.value=='Microsoft.KeyVault/vaults/secrets/read']" \
  --output table

# Policy compliance
az policy state list \
  --resource-group rg-poc4-prod \
  --query "[?complianceState=='NonCompliant'].{resource:resourceId,policy:policyDefinitionName}" \
  --output table

# Alert rule active
az monitor metrics alert show \
  --name alert-error-rate \
  --resource-group rg-poc4-prod \
  --query "enabled" -o tsv
```

---

## Interview Q&A — Day 10 Topics

**Q: What is OIDC federated identity and why is it better than service principal secrets?**
A: OIDC allows Azure DevOps pipelines to authenticate to Azure using short-lived tokens — no credentials stored anywhere. Azure trusts Azure DevOps's OIDC issuer and issues access tokens based on the pipeline's identity (organization + project + service connection). No secrets to rotate, no risk of credential leakage. Traditional service principal secrets expire, can be leaked from pipeline logs, and require manual rotation.

**Q: How do you use Terraform in a CI/CD pipeline securely?**
A: 1) Use OIDC federated identity — no stored ARM credentials. 2) Store state in Azure Storage with state locking. 3) Run `terraform plan` in CI (PR validation) — fail if plan shows unexpected changes. 4) Run `terraform apply` only on main branch after approval. 5) Use separate state files per environment. 6) Never run `terraform destroy` in automated pipelines — require manual execution.

**Q: What is the difference between Azure Monitor and Application Insights?**
A: Azure Monitor is the umbrella platform for all monitoring in Azure — it collects metrics, logs, and alerts from Azure resources (VMs, App Service, SQL, etc.). Application Insights is a feature of Azure Monitor specifically for application performance monitoring — it provides distributed tracing, request/dependency tracking, custom events, and availability tests. Use both: Azure Monitor for infrastructure metrics, Application Insights for application-level observability.

**Q: How do you implement a "no stored credentials" policy across your entire Azure DevOps organization?**
A: 1) Migrate all service connections to Workload Identity Federation (OIDC). 2) Use variable groups linked to Key Vault (not plain variable groups with secrets). 3) Enable secret scanning in pipelines to detect hardcoded credentials. 4) Azure Policy: audit App Service apps for plaintext connection strings. 5) Regular access reviews: quarterly review of service connections and their permissions. 6) Defender for Cloud: enable credential scanning recommendations.

**Q: What happens if Terraform apply fails halfway through?**
A: Some resources are created, some aren't — partial state. Terraform records what was created in state. Run `terraform plan` to see what's missing. Usually safe to re-run `terraform apply` — Terraform will only create the missing resources. For resources that partially created (e.g., VM with no extensions), you may need to `terraform destroy` that specific resource and re-apply. Always check the state with `terraform state list` after a failed apply.
