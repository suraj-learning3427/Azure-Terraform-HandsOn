# Day 9 — Apr 23 | Security, Compliance + Secure Pipelines
**Presenters**: Sabari & Shruthi

---

## What You'll Learn Today
- Shift-left security, OWASP Top 10, security scanning tools
- Azure Monitor, Application Insights, Azure Policy
- Secure CI/CD pipeline implementation

---

## Part 1: Shift-Left Security

**Shift-left** = catch security issues in development, not in production.

### Security at Each Stage

| Stage | Tool | What It Catches |
|-------|------|----------------|
| IDE | SonarLint | Code smells, security hotspots |
| Pre-commit | detect-secrets / gitleaks | Hardcoded secrets |
| PR / CI | SonarCloud (SAST) | Vulnerabilities in code |
| CI | OWASP Dependency Check | CVEs in dependencies |
| CI | Trivy | CVEs in container images |
| CI | Checkov | Misconfigurations in Terraform |
| Staging | OWASP ZAP (DAST) | Runtime vulnerabilities |
| Production | Defender for Cloud | Threats, recommendations |

### OWASP Top 10 — Must Know
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

### Security Scanning in Pipeline
```yaml
stages:
  - stage: SecurityScan
    jobs:
      - job: SAST
        steps:
          - task: SonarCloudPrepare@1
            inputs:
              SonarCloud: 'SonarCloud'
              organization: 'myorg'
              scannerMode: 'MSBuild'
              projectKey: 'myproject'
          - script: dotnet build
          - task: SonarCloudAnalyze@1
          - task: SonarCloudPublish@1
            inputs:
              pollingTimeoutSec: '300'

      - job: DependencyScan
        steps:
          - script: |
              pip install checkov
              checkov -d ./terraform --framework terraform \
                --output junitxml --output-file checkov-results.xml
            displayName: Checkov IaC scan

          - script: |
              trivy image --exit-code 1 --severity HIGH,CRITICAL \
                --ignore-unfixed myapp:$(Build.BuildId)
            displayName: Trivy container scan

      - job: SecretScan
        steps:
          - script: |
              pip install detect-secrets
              detect-secrets scan --baseline .secrets.baseline
              detect-secrets audit .secrets.baseline
            displayName: Secret scanning
```

---

## Part 2: Azure Monitor + Application Insights

### Log Analytics Workspace
```hcl
resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-training-prod"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = 90
}

# Enable diagnostic settings on all resources
resource "azurerm_monitor_diagnostic_setting" "app_service" {
  name                       = "diag-appservice"
  target_resource_id         = azurerm_linux_web_app.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log { category = "AppServiceHTTPLogs" }
  enabled_log { category = "AppServiceAppLogs" }
  metric { category = "AllMetrics" }
}
```

### Application Insights Alerts
```hcl
resource "azurerm_application_insights" "main" {
  name                = "appi-training-prod"
  resource_group_name = var.resource_group_name
  location            = var.location
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"
}

resource "azurerm_monitor_action_group" "ops" {
  name                = "ag-ops-team"
  resource_group_name = var.resource_group_name
  short_name          = "ops"
  email_receiver {
    name          = "ops-team"
    email_address = "ops@mycompany.com"
  }
}

resource "azurerm_monitor_metric_alert" "error_rate" {
  name                = "alert-high-error-rate"
  resource_group_name = var.resource_group_name
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

---

## Part 3: Azure Policy

### Policy Effects

| Effect | What It Does | Use When |
|--------|-------------|----------|
| Audit | Logs non-compliant resources | Visibility without disruption |
| Deny | Blocks creation of non-compliant resources | Hard security requirements |
| DeployIfNotExists | Auto-deploys remediation | Auto-remediation |
| Modify | Changes resource properties | Auto-fix (e.g., enable HTTPS) |

### Create Policy Initiative with Terraform
```hcl
# Policy initiative: require tags + allowed regions + deny public IPs on VMs
resource "azurerm_policy_set_definition" "governance" {
  name         = "governance-initiative"
  policy_type  = "Custom"
  display_name = "Governance Initiative"

  # Require environment tag
  policy_definition_reference {
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/96670d01-0a4d-4649-9c89-2d3abc0a5025"
    parameter_values     = jsonencode({ tagName = { value = "environment" } })
  }

  # Allowed locations only
  policy_definition_reference {
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c"
    parameter_values     = jsonencode({
      listOfAllowedLocations = { value = ["eastus2", "westus2", "westeurope"] }
    })
  }
}

resource "azurerm_subscription_policy_assignment" "governance" {
  name                 = "governance-assignment"
  subscription_id      = data.azurerm_subscription.current.id
  policy_definition_id = azurerm_policy_set_definition.governance.id
  display_name         = "Governance Initiative"
}
```

---

## Hands-On: Add Security Scanning to POC 2 Pipeline

Add these stages to your existing pipeline:
1. Trivy scan on the container image
2. Checkov scan on the Terraform directory
3. Fail the pipeline if HIGH/CRITICAL issues found

---

## Interview Q&A — Day 9 Topics

**Q: What does "shift-left security" mean?**
A: Moving security checks earlier in the development lifecycle — from production (far right) to development (far left). Instead of finding vulnerabilities in production, you catch them in the IDE, code review, or CI pipeline. The cost of fixing a vulnerability in development is 10x cheaper than in production. Implementation: IDE plugins → pre-commit hooks → PR checks (SAST, dependency scan) → CI (container scan, IaC scan) → staging (DAST) → production (Defender for Cloud).

**Q: What is the difference between Checkov and Trivy?**
A: Checkov scans Infrastructure as Code (Terraform, ARM, Kubernetes YAML) for security misconfigurations — e.g., storage account with public access enabled, NSG allowing all inbound traffic. Trivy scans container images and filesystems for known CVEs in OS packages and application dependencies. Use both: Checkov in the IaC pipeline stage, Trivy in the container build stage.

**Q: What Azure Policy effects are available and when do you use each?**
A: Audit: logs non-compliant resources but doesn't block them — good for visibility without disruption. Deny: blocks creation/update of non-compliant resources — use for hard security requirements (no public IPs on VMs). DeployIfNotExists: automatically deploys a remediation resource when non-compliant — use for auto-remediation (enable diagnostic settings on new resources). Modify: changes resource properties — use for auto-fix (enable HTTPS-only on App Service).

**Q: How do you respond to a Defender for Cloud security alert?**
A: 1) Isolate immediately — apply NSG rule to block suspicious traffic. 2) Preserve evidence — snapshot VM disk before changes. 3) Investigate — check Activity Log, VM login history, running processes. 4) Determine scope — is this one resource or multiple? 5) Remediate — rebuild from clean image (don't try to clean a compromised VM). 6) Post-mortem — how did attacker get in? Patch the vulnerability. 7) Improve — add to Firewall deny list, enable JIT VM access.

**Q: How do you improve Azure Security Score quickly?**
A: Focus on recommendations with highest "Max Score" impact. Typical quick wins: 1) Enable MFA for all users (often 10+ points). 2) Enable Defender for Cloud plans. 3) Apply system updates to VMs. 4) Restrict RDP/SSH (use JIT or Bastion). 5) Enable disk encryption on VMs. 6) Enable Azure AD authentication for SQL. Export recommendations to CSV, sort by Max Score, work through top 10 — usually gets from 45 to 70+ in a week.
