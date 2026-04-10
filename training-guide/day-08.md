# Day 8 — Apr 22 | Canary, A/B Testing + CI/CD to App Service (Complete)
**Presenters**: Murali & Venkat

---

## What You'll Learn Today
- Canary releases and dark launching
- A/B testing with Application Insights
- Complete CI/CD pipeline to Azure App Service with deployment slots

---

## Part 1: Advanced Release Patterns

### Automated Rollback with Application Insights Alert
```hcl
# Terraform: Alert that triggers rollback pipeline
resource "azurerm_monitor_metric_alert" "canary_error_rate" {
  name                = "alert-canary-error-rate"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_application_insights.main.id]
  severity            = 1
  description         = "Canary error rate exceeded threshold — trigger rollback"

  criteria {
    metric_namespace = "microsoft.insights/components"
    metric_name      = "requests/failed"
    aggregation      = "Count"
    operator         = "GreaterThan"
    threshold        = 10
  }

  action { action_group_id = azurerm_monitor_action_group.rollback.id }
  frequency   = "PT1M"
  window_size = "PT5M"
}

# Action group that triggers Azure DevOps pipeline (rollback)
resource "azurerm_monitor_action_group" "rollback" {
  name                = "ag-rollback"
  resource_group_name = var.resource_group_name
  short_name          = "rollback"

  azure_function_receiver {
    name                     = "trigger-rollback"
    function_app_resource_id = azurerm_linux_function_app.rollback.id
    function_name            = "TriggerRollback"
    http_trigger_url         = "https://func-rollback.azurewebsites.net/api/rollback"
    use_common_alert_schema  = true
  }
}
```

### A/B Testing Setup
```bash
# Create two App Configuration feature flags
az appconfig feature set --name appconfig-training --feature NewUI --yes
az appconfig feature set --name appconfig-training --feature LegacyUI --yes

# Enable NewUI for 50% of users
az appconfig feature filter add \
  --name appconfig-training \
  --feature NewUI \
  --filter-name Microsoft.Targeting \
  --filter-parameters '{"Audience":{"DefaultRolloutPercentage":50}}'

# Track in Application Insights (custom event)
# In your .NET code:
# telemetryClient.TrackEvent("CheckoutCompleted", new Dictionary<string, string>
# {
#     ["UIVariant"] = featureManager.IsEnabledAsync("NewUI").Result ? "new" : "legacy"
# });
```

**Measure A/B test results in Application Insights**:
```kusto
// KQL: Compare conversion rates between UI variants
customEvents
| where name == "CheckoutCompleted"
| extend variant = tostring(customDimensions["UIVariant"])
| summarize conversions = count() by variant, bin(timestamp, 1h)
| render timechart
```

### Dark Launching
Deploy new code to production but don't expose it to users yet. Test with real production data/load.

```csharp
// Dark launch: run new code path but return old result
if (await featureManager.IsEnabledAsync("NewPaymentProcessor"))
{
    // Run new processor in background (don't return its result yet)
    _ = Task.Run(() => newPaymentProcessor.ProcessAsync(order));
}
// Always return result from old processor
return await legacyPaymentProcessor.ProcessAsync(order);
```

---

## Part 2: Complete CI/CD Pipeline to App Service

### Full Pipeline with All Stages
```yaml
# azure-pipelines.yml — Complete POC 3 pipeline
trigger:
  branches:
    include: [main]

variables:
  - group: poc3-secrets          # Key Vault linked variable group
  - name: appName
    value: app-poc3-prod
  - name: resourceGroup
    value: rg-poc3-prod

stages:
  # ── 1. Build + Test + Scan ──────────────────────────────────────────────────
  - stage: Build
    jobs:
      - job: BuildTestScan
        pool:
          vmImage: ubuntu-latest
        steps:
          - task: DotNetCoreCLI@2
            displayName: Build and test
            inputs:
              command: test
              arguments: '--configuration Release --collect:"XPlat Code Coverage"'

          - task: PublishCodeCoverageResults@1
            inputs:
              codeCoverageTool: Cobertura
              summaryFileLocation: '**/coverage.cobertura.xml'

          - script: |
              docker build -t $(acrName).azurecr.io/myapp:$(Build.BuildId) .
              trivy image --exit-code 1 --severity HIGH,CRITICAL \
                $(acrName).azurecr.io/myapp:$(Build.BuildId)
            displayName: Build and scan container

          - task: AzureCLI@2
            displayName: Push to ACR
            inputs:
              azureSubscription: 'MyServiceConnection'
              scriptType: bash
              inlineScript: |
                az acr login --name $(acrName)
                docker push $(acrName).azurecr.io/myapp:$(Build.BuildId)

  # ── 2. Deploy to Staging Slot ───────────────────────────────────────────────
  - stage: Deploy_Staging
    dependsOn: Build
    jobs:
      - deployment: DeployStaging
        environment: staging
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureWebAppContainer@1
                  inputs:
                    azureSubscription: 'MyServiceConnection'
                    appName: $(appName)
                    slotName: staging
                    imageName: $(acrName).azurecr.io/myapp:$(Build.BuildId)

                - script: |
                    sleep 30
                    STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
                      https://$(appName)-staging.azurewebsites.net/health)
                    [ "$STATUS" = "200" ] || exit 1
                  displayName: Smoke test

  # ── 3. Canary: 10% traffic ──────────────────────────────────────────────────
  - stage: Canary
    dependsOn: Deploy_Staging
    jobs:
      - job: Canary
        steps:
          - task: AzureCLI@2
            inputs:
              azureSubscription: 'MyServiceConnection'
              scriptType: bash
              inlineScript: |
                az webapp traffic-routing set \
                  --name $(appName) --resource-group $(resourceGroup) \
                  --distribution staging=10
                echo "Canary at 10% — waiting 15 minutes"
                sleep 900

  # ── 4. Swap to Production (requires approval) ───────────────────────────────
  - stage: Production
    dependsOn: Canary
    jobs:
      - deployment: SwapToProduction
        environment: production
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureAppServiceManage@0
                  inputs:
                    azureSubscription: 'MyServiceConnection'
                    Action: 'Swap Slots'
                    WebAppName: $(appName)
                    ResourceGroupName: $(resourceGroup)
                    SourceSlot: staging
```

### Validate POC 3
```bash
# Verify image in ACR
az acr repository show-tags --name myacrprod --repository myapp --query "[-1]" -o tsv

# Verify staging slot deployed
az webapp show --name app-poc3-prod --resource-group rg-poc3-prod \
  --query "state" -o tsv

# Verify traffic routing (canary)
az webapp traffic-routing show --name app-poc3-prod --resource-group rg-poc3-prod

# Verify production swap completed
curl -s https://app-poc3-prod.azurewebsites.net/health
```

---

## Interview Q&A — Day 8 Topics

**Q: What is dark launching and when would you use it?**
A: Dark launching deploys new code to production but doesn't expose it to users — you run the new code path in the background to test it with real production data and load, but return results from the old code path. Use it when: you want to validate performance/correctness of new code with real data before exposing it, or when you're replacing a critical system and need confidence before switching.

**Q: How do you measure the success of an A/B test?**
A: Define the hypothesis and success metric before starting (e.g., "New checkout UI will increase conversion rate by 5%"). Track custom events in Application Insights. Use KQL to compare conversion rates between variants. Ensure statistical significance (enough sample size, typically 1-2 weeks of data). Only declare a winner when the difference is statistically significant — don't stop early because one variant looks better.

**Q: What happens to in-flight requests during a slot swap?**
A: App Service drains in-flight requests before completing the swap. Requests that started on the old slot complete on the old slot. New requests after the swap go to the new slot. The swap is atomic from the user's perspective — there's no period where some requests go to old and some to new (unlike canary). This is why blue-green with slots is truly zero-downtime.

**Q: How do you implement a rollback pipeline triggered by an Application Insights alert?**
A: 1) Create an Application Insights metric alert (e.g., error rate > 1%). 2) Create an Action Group that calls an Azure Function or webhook. 3) The Function calls the Azure DevOps REST API to trigger a rollback pipeline. 4) The rollback pipeline runs `az webapp traffic-routing clear` (for canary) or `az webapp deployment slot swap` (for blue-green). The whole chain should complete in < 2 minutes.

**Q: What is the difference between `az webapp traffic-routing set` and `az webapp deployment slot swap`?**
A: `traffic-routing set` splits traffic between slots without swapping — both slots run simultaneously, a percentage of users go to each. Used for canary. `deployment slot swap` atomically exchanges the content and configuration of two slots — all traffic goes to the new version. Used for blue-green. Canary → swap is the typical full rollout sequence.
