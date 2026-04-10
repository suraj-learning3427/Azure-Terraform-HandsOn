# Day 7 — Apr 21 | Release Strategies + AKS with Terraform
**Presenters**: Vijay & Manju

---

## What You'll Learn Today
- Blue-green, canary, A/B testing, feature flags, automated rollback
- AKS provisioning with Terraform, Application Gateway, private endpoints

---

## Part 1: Release Strategies

### Blue-Green Deployment
Deploy new version (green) alongside old (blue). Switch traffic atomically. Instant rollback.

```bash
# Deploy new version to staging slot (green)
az webapp deployment source config-zip \
  --name myapp --resource-group myRG \
  --slot staging --src app-v2.zip

# Smoke test staging
curl -f https://myapp-staging.azurewebsites.net/health

# Swap: staging (green) becomes production
az webapp deployment slot swap \
  --name myapp --resource-group myRG \
  --slot staging --target-slot production

# Rollback: swap back (takes < 30 seconds)
az webapp deployment slot swap \
  --name myapp --resource-group myRG \
  --slot production --target-slot staging
```

**Database migrations with blue-green**: Use the **expand-contract pattern**:
1. **Expand**: Add new column as nullable (both old and new code work)
2. **Deploy**: New code writes to new column
3. **Contract**: Add NOT NULL constraint, remove old code paths

Never add a NOT NULL column without a default in a single deployment — it breaks the old app version.

### Canary Deployment
Gradually shift traffic. Monitor metrics. Rollback if metrics degrade.

```bash
# Route 10% to staging (canary)
az webapp traffic-routing set \
  --name myapp --resource-group myRG \
  --distribution staging=10

# After 15 minutes, check error rate in App Insights
# If OK, increase to 50%
az webapp traffic-routing set \
  --name myapp --resource-group myRG \
  --distribution staging=50

# Full rollout: swap to production
az webapp deployment slot swap \
  --name myapp --resource-group myRG \
  --slot staging --target-slot production

# Rollback: clear routing (100% back to production)
az webapp traffic-routing clear \
  --name myapp --resource-group myRG
```

**Rollback trigger criteria** (define BEFORE deployment):
- Error rate > 1% (baseline: 0.1%)
- p95 latency > 2000ms (baseline: 500ms)
- HTTP 5xx rate > 0.5%

### Feature Flags with Azure App Configuration
```bash
# Create App Configuration
az appconfig create \
  --name appconfig-training \
  --resource-group rg-training-dev \
  --sku Standard

# Create feature flag
az appconfig feature set \
  --name appconfig-training \
  --feature NewCheckoutFlow \
  --yes

# Enable for 10% of users
az appconfig feature filter add \
  --name appconfig-training \
  --feature NewCheckoutFlow \
  --filter-name Microsoft.Targeting \
  --filter-parameters '{"Audience":{"DefaultRolloutPercentage":10}}'
```

```csharp
// .NET: Check feature flag
if (await featureManager.IsEnabledAsync("NewCheckoutFlow"))
    return RedirectToAction("NewCheckout");
return RedirectToAction("LegacyCheckout");
```

**Feature flag lifecycle**:
1. Create flag (disabled) → deploy code
2. Enable for internal users → validate
3. Enable for 10% → monitor
4. Enable for 100% → full rollout
5. Remove flag from code → cleanup

### Deployment Rings

| Ring | Audience | Purpose |
|------|----------|---------|
| Ring 0 | Internal team | Catch obvious bugs |
| Ring 1 | Early adopters (1%) | Real user validation |
| Ring 2 | Broad users (10%) | Scale validation |
| Ring 3 | All users (100%) | Full rollout |

---

## Part 2: AKS with Terraform + Application Gateway

### Complete AKS + App Gateway Setup
```hcl
# Application Gateway (WAF v2) as ingress
resource "azurerm_public_ip" "agw" {
  name                = "pip-agw-prod"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_application_gateway" "main" {
  name                = "agw-prod"
  resource_group_name = var.resource_group_name
  location            = var.location

  sku { name = "WAF_v2"; tier = "WAF_v2"; capacity = 2 }

  waf_configuration {
    enabled          = true
    firewall_mode    = "Prevention"
    rule_set_type    = "OWASP"
    rule_set_version = "3.2"
  }

  gateway_ip_configuration { name = "gw-ip"; subnet_id = var.agw_subnet_id }
  frontend_ip_configuration { name = "frontend"; public_ip_address_id = azurerm_public_ip.agw.id }
  frontend_port { name = "http"; port = 80 }
  backend_address_pool { name = "aks-backend" }
  backend_http_settings { name = "http-settings"; cookie_based_affinity = "Disabled"; port = 80; protocol = "Http"; request_timeout = 60 }
  http_listener { name = "listener"; frontend_ip_configuration_name = "frontend"; frontend_port_name = "http"; protocol = "Http" }
  request_routing_rule { name = "rule"; rule_type = "Basic"; http_listener_name = "listener"; backend_address_pool_name = "aks-backend"; backend_http_settings_name = "http-settings"; priority = 100 }
}
```

---

## POC 3: CI/CD to App Service with Deployment Slots

### Pipeline with Canary
```yaml
stages:
  - stage: Build
    jobs:
      - job: Build
        steps:
          - script: docker build -t $(ACR_NAME).azurecr.io/myapp:$(Build.BuildId) .
          - script: trivy image --exit-code 1 --severity HIGH,CRITICAL $(ACR_NAME).azurecr.io/myapp:$(Build.BuildId)
          - task: AzureCLI@2
            inputs:
              scriptType: bash
              inlineScript: |
                az acr login --name $(ACR_NAME)
                docker push $(ACR_NAME).azurecr.io/myapp:$(Build.BuildId)

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
                    appName: app-poc3-prod
                    slotName: staging
                    imageName: $(ACR_NAME).azurecr.io/myapp:$(Build.BuildId)

  - stage: Canary_10
    dependsOn: Deploy_Staging
    jobs:
      - job: RouteCanary
        steps:
          - task: AzureCLI@2
            inputs:
              scriptType: bash
              inlineScript: |
                az webapp traffic-routing set \
                  --name app-poc3-prod --resource-group rg-poc3-prod \
                  --distribution staging=10
                sleep 900  # Monitor for 15 minutes

  - stage: Swap_Production
    dependsOn: Canary_10
    jobs:
      - deployment: SwapProd
        environment: production   # Requires approval
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureAppServiceManage@0
                  inputs:
                    Action: 'Swap Slots'
                    WebAppName: app-poc3-prod
                    ResourceGroupName: rg-poc3-prod
                    SourceSlot: staging
```

---

## Interview Q&A — Day 7 Topics

**Q: When would you choose blue-green over canary deployment?**
A: Blue-green for: atomic switchover needed, database migrations that aren't backward compatible (though risky), or when you need the simplest rollback (just swap back). Canary for: validating with real production traffic before full rollout, measuring business metrics (conversion rate), or when you can tolerate a small % of users experiencing issues. For most feature releases, canary is safer. For infrastructure upgrades, blue-green is cleaner.

**Q: How do you handle database migrations in a zero-downtime deployment?**
A: Use the expand-contract pattern: Phase 1 (Expand) — add new column as nullable, both old and new code work. Phase 2 (Deploy) — deploy new code that writes to the new column. Phase 3 (Contract) — add NOT NULL constraint, remove old code paths. This takes 3 deployments but ensures zero downtime and safe rollback at each step.

**Q: What metrics should trigger an automated canary rollback?**
A: Define thresholds before deployment: error rate (HTTP 5xx), p95/p99 latency, business metrics (conversion rate, order completion). Example: rollback if error rate > 1% (baseline 0.1%) or p95 latency > 2x baseline for 5 consecutive minutes. Automate with Application Insights alerts → Azure DevOps pipeline trigger.

**Q: What is a feature flag kill switch?**
A: A feature flag that can be disabled instantly (without redeployment) to turn off a problematic feature for all users. Essential for risky features — if something goes wrong in production, you disable the flag and the feature is gone within seconds. Azure App Configuration propagates flag changes within 30 seconds.

**Q: What is the difference between a deployment ring and canary?**
A: Canary routes a random percentage of traffic to the new version. Rings target specific user groups (internal → early adopters → broad users → all users) — the audience is controlled, not random. Rings are better for enterprise software where you want specific teams to validate before broader rollout.
