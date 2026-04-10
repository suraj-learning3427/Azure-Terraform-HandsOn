# Module 10: Security and Compliance — Theory

## 1. Secure DevOps (Shift-Left Security)

Shift-left means moving security earlier in the development lifecycle — catching issues in code review rather than in production.

### Security in CI/CD Pipeline
```yaml
# Azure Pipelines: security scanning stages
stages:
  - stage: SecurityScan
    jobs:
      - job: SAST
        steps:
          # Static Application Security Testing
          - task: SonarCloudAnalyze@1  # Code quality + security rules

      - job: DependencyScan
        steps:
          # Dependency vulnerability scanning
          - script: |
              # OWASP Dependency Check
              dependency-check --project myapp --scan . --format JSON \
                --out dependency-check-report.json
              # Fail if HIGH/CRITICAL CVEs found
              python check-cvss.py --threshold 7.0

      - job: ContainerScan
        steps:
          - script: docker build -t myapp:$(Build.BuildId) .
          - script: |
              # Trivy: container image vulnerability scanner
              trivy image \
                --exit-code 1 \
                --severity HIGH,CRITICAL \
                --ignore-unfixed \
                myapp:$(Build.BuildId)

      - job: IaCScan
        steps:
          - script: |
              # Checkov: Terraform security scanner
              checkov -d ./terraform \
                --framework terraform \
                --output junitxml \
                --output-file checkov-results.xml \
                --soft-fail-on MEDIUM
              # Fail on HIGH/CRITICAL IaC misconfigurations
```

### OWASP Top 10 (Must Know for Interviews)
1. Broken Access Control
2. Cryptographic Failures
3. Injection (SQL, NoSQL, OS command)
4. Insecure Design
5. Security Misconfiguration
6. Vulnerable and Outdated Components
7. Identification and Authentication Failures
8. Software and Data Integrity Failures
9. Security Logging and Monitoring Failures
10. Server-Side Request Forgery (SSRF)

---

## 2. Azure Monitor and Application Insights

### 2.1 Log Analytics Workspace
Central repository for all Azure diagnostic logs.

```hcl
resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-${var.name}-prod"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = 90  # 30 days free, then pay per GB
}

# Enable diagnostic settings on all resources
resource "azurerm_monitor_diagnostic_setting" "app_service" {
  name                       = "diag-appservice"
  target_resource_id         = azurerm_linux_web_app.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log { category = "AppServiceHTTPLogs" }
  enabled_log { category = "AppServiceConsoleLogs" }
  enabled_log { category = "AppServiceAppLogs" }
  metric { category = "AllMetrics" }
}
```

### 2.2 Application Insights
```hcl
resource "azurerm_application_insights" "main" {
  name                = "appi-${var.name}-prod"
  resource_group_name = var.resource_group_name
  location            = var.location
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"
}

# Availability test (synthetic monitoring)
resource "azurerm_application_insights_web_test" "health" {
  name                    = "health-check"
  resource_group_name     = var.resource_group_name
  application_insights_id = azurerm_application_insights.main.id
  kind                    = "ping"
  frequency               = 300  # Every 5 minutes
  timeout                 = 30
  enabled                 = true
  geo_locations           = ["us-ca-sjc-azr", "us-tx-sn1-azr", "us-il-ch1-azr"]

  configuration = <<XML
<WebTest Name="health-check" Enabled="True" Timeout="30" xmlns="http://microsoft.com/schemas/VisualStudio/TeamTest/2010">
  <Items>
    <Request Method="GET" Version="1.1" Url="https://myapp.azurewebsites.net/health" ThinkTime="0" Timeout="30" ParseDependentRequests="False" FollowRedirects="True" RecordResult="True" Cache="False" ResponseTimeGoal="0" Encoding="utf-8" ExpectedHttpStatusCode="200" />
  </Items>
</WebTest>
XML
}
```

### 2.3 Alert Rules
```hcl
resource "azurerm_monitor_metric_alert" "error_rate" {
  name                = "alert-high-error-rate"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_application_insights.main.id]
  severity            = 1  # Critical

  criteria {
    metric_namespace = "microsoft.insights/components"
    metric_name      = "requests/failed"
    aggregation      = "Count"
    operator         = "GreaterThan"
    threshold        = 10
  }

  action {
    action_group_id = azurerm_monitor_action_group.ops.id
  }

  frequency   = "PT1M"
  window_size = "PT5M"
}
```

---

## 3. Azure Policy

### 3.1 Policy Definitions
```hcl
# Built-in policy: require tags on resource groups
resource "azurerm_policy_assignment" "require_tags" {
  name                 = "require-tags"
  scope                = data.azurerm_subscription.current.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/96670d01-0a4d-4649-9c89-2d3abc0a5025"
  display_name         = "Require tags on resource groups"

  parameters = jsonencode({
    tagName = { value = "environment" }
  })
}

# Custom policy: deny public IP on VMs
resource "azurerm_policy_definition" "deny_vm_public_ip" {
  name         = "deny-vm-public-ip"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Deny public IP on virtual machines"

  policy_rule = jsonencode({
    if = {
      allOf = [
        { field = "type"; equals = "Microsoft.Network/networkInterfaces" },
        { count = { field = "Microsoft.Network/networkInterfaces/ipconfigurations[*].publicIpAddress.id" }; greater = 0 }
      ]
    }
    then = { effect = "Deny" }
  })
}

# Policy initiative (group of policies)
resource "azurerm_policy_set_definition" "governance" {
  name         = "governance-initiative"
  policy_type  = "Custom"
  display_name = "Governance Initiative"

  policy_definition_reference {
    policy_definition_id = azurerm_policy_definition.deny_vm_public_ip.id
  }
  policy_definition_reference {
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/..."
    parameter_values = jsonencode({ tagName = { value = "environment" } })
  }
}
```

---

## 4. Microsoft Defender for Cloud

- **Security Score**: 0-100 score based on implemented recommendations
- **Regulatory Compliance**: maps controls to SOC 2, ISO 27001, PCI-DSS, NIST
- **Defender Plans**: enable per resource type (Servers, SQL, Containers, App Service, Key Vault)
- **Security Alerts**: real-time threat detection (SQL injection, brute force, anomalous access)

```hcl
# Enable Defender for SQL
resource "azurerm_security_center_subscription_pricing" "sql" {
  tier          = "Standard"
  resource_type = "SqlServers"
}

resource "azurerm_security_center_subscription_pricing" "containers" {
  tier          = "Standard"
  resource_type = "Containers"
}
```

---

## 5. Compliance Frameworks

| Framework | Key Controls | Azure Mapping |
|-----------|-------------|---------------|
| SOC 2 Type II | Availability, Confidentiality, Security | Azure Monitor, Key Vault, RBAC |
| ISO 27001 | Information security management | Defender for Cloud, Policy |
| GDPR | Data residency, right to erasure | Azure regions, SQL data masking |
| PCI-DSS | Cardholder data protection | Always Encrypted, private endpoints |

---

## 6. Best Practices

- Enable Defender for Cloud on all subscriptions — free tier provides basic recommendations
- Implement Azure Policy at management group level for organization-wide governance
- Use Log Analytics workspace per environment — don't mix dev and prod logs
- Set up availability tests for all production endpoints
- Configure alert action groups with PagerDuty/Teams integration
- Review Security Score weekly and address high-impact recommendations
- Enable Just-In-Time (JIT) VM access — no permanent RDP/SSH open to internet
