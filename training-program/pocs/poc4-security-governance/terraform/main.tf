# POC 4: Security and Governance Infrastructure
# Key Vault + SPN + Azure Policy + Log Analytics + Application Insights + Alerts

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm"; version = "~> 3.90" }
    azuread = { source = "hashicorp/azuread"; version = "~> 2.47" }
  }
}

provider "azurerm" { features { key_vault { purge_soft_delete_on_destroy = false } } }
provider "azuread" {}

data "azurerm_client_config" "current" {}
data "azurerm_subscription" "current" {}

resource "azurerm_resource_group" "main" {
  name     = "rg-poc4-security"
  location = var.location
  tags     = local.tags
}

locals {
  tags = { environment = "prod"; project = "poc4"; managed_by = "terraform" }
}

# ── Log Analytics Workspace ────────────────────────────────────────────────────
resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-poc4-prod"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "PerGB2018"
  retention_in_days   = 90
  tags                = local.tags
}

# ── Application Insights ───────────────────────────────────────────────────────
resource "azurerm_application_insights" "main" {
  name                = "appi-poc4-prod"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"
  tags                = local.tags
}

# Availability test
resource "azurerm_application_insights_web_test" "health" {
  name                    = "health-check"
  resource_group_name     = azurerm_resource_group.main.name
  application_insights_id = azurerm_application_insights.main.id
  kind                    = "ping"
  frequency               = 300
  timeout                 = 30
  enabled                 = true
  geo_locations           = ["us-ca-sjc-azr", "us-tx-sn1-azr"]
  configuration           = <<XML
<WebTest Name="health-check" Enabled="True" Timeout="30" xmlns="http://microsoft.com/schemas/VisualStudio/TeamTest/2010">
  <Items>
    <Request Method="GET" Version="1.1" Url="${var.app_url}/health" ThinkTime="0" Timeout="30" ParseDependentRequests="False" FollowRedirects="True" RecordResult="True" Cache="False" ResponseTimeGoal="0" Encoding="utf-8" ExpectedHttpStatusCode="200" />
  </Items>
</WebTest>
XML
}

# ── Key Vault with RBAC ────────────────────────────────────────────────────────
resource "azurerm_key_vault" "main" {
  name                      = "kv-poc4-prod"
  resource_group_name       = azurerm_resource_group.main.name
  location                  = azurerm_resource_group.main.location
  tenant_id                 = data.azurerm_client_config.current.tenant_id
  sku_name                  = "standard"
  enable_rbac_authorization = true
  purge_protection_enabled  = true
  tags                      = local.tags

  # Diagnostic settings → Log Analytics
  lifecycle { prevent_destroy = true }
}

resource "azurerm_monitor_diagnostic_setting" "kv" {
  name                       = "diag-kv"
  target_resource_id         = azurerm_key_vault.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  enabled_log { category = "AuditEvent" }
  metric { category = "AllMetrics" }
}

# ── Service Principal with Federated Identity (OIDC for Azure DevOps) ─────────
resource "azuread_application" "terraform_pipeline" {
  display_name = "sp-terraform-pipeline"
}

resource "azuread_service_principal" "terraform_pipeline" {
  client_id = azuread_application.terraform_pipeline.client_id
}

# Federated credential: Azure DevOps pipeline can authenticate without secrets
resource "azuread_application_federated_identity_credential" "pipeline" {
  application_id = azuread_application.terraform_pipeline.id
  display_name   = "azure-devops-pipeline"
  description    = "Azure DevOps pipeline OIDC authentication"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://vstoken.dev.azure.com/${var.ado_organization}"
  subject        = "sc://${var.ado_organization}/${var.ado_project}/${var.ado_service_connection}"
}

# Grant SPN Contributor on subscription for Terraform
resource "azurerm_role_assignment" "terraform_contributor" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.terraform_pipeline.object_id
}

# ── Azure Policy Initiative ────────────────────────────────────────────────────
resource "azurerm_policy_set_definition" "governance" {
  name         = "governance-initiative"
  policy_type  = "Custom"
  display_name = "POC4 Governance Initiative"
  description  = "Enforce tagging, regions, and diagnostic settings"

  # Require environment tag
  policy_definition_reference {
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/96670d01-0a4d-4649-9c89-2d3abc0a5025"
    parameter_values     = jsonencode({ tagName = { value = "environment" } })
  }

  # Allowed locations
  policy_definition_reference {
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c"
    parameter_values     = jsonencode({ listOfAllowedLocations = { value = ["eastus2", "westus2", "westeurope"] } })
  }
}

resource "azurerm_subscription_policy_assignment" "governance" {
  name                 = "governance-assignment"
  subscription_id      = data.azurerm_subscription.current.id
  policy_definition_id = azurerm_policy_set_definition.governance.id
  display_name         = "Governance Initiative Assignment"
}

# ── Alert Rules ────────────────────────────────────────────────────────────────
resource "azurerm_monitor_action_group" "ops" {
  name                = "ag-ops-team"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "ops"

  email_receiver {
    name          = "ops-team"
    email_address = var.ops_email
  }
}

resource "azurerm_monitor_metric_alert" "error_rate" {
  name                = "alert-high-error-rate"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_application_insights.main.id]
  severity            = 1
  description         = "Alert when error rate exceeds threshold"

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
