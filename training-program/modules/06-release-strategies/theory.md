# Module 6: Release Strategies — Theory

## 1. Blue-Green Deployment

Deploy new version (green) alongside old version (blue). Switch traffic atomically. Instant rollback by switching back.

```bash
# Azure App Service: blue = production slot, green = staging slot
# Deploy new version to staging (green)
az webapp deployment slot swap \
  --name myapp --resource-group myRG \
  --slot staging --target-slot production

# Rollback: swap back
az webapp deployment slot swap \
  --name myapp --resource-group myRG \
  --slot production --target-slot staging
```

**Pros**: Zero downtime, instant rollback, full testing before go-live
**Cons**: Requires 2x infrastructure cost during deployment, database migrations need careful handling

---

## 2. Canary Deployment

Gradually shift traffic from old version to new version. Monitor metrics at each step. Rollback if metrics degrade.

```bash
# Route 10% of traffic to staging slot (canary)
az webapp traffic-routing set \
  --name myapp --resource-group myRG \
  --distribution staging=10

# Increase to 50% after validation
az webapp traffic-routing set \
  --name myapp --resource-group myRG \
  --distribution staging=50

# Complete rollout: 100% to new version
az webapp deployment slot swap \
  --name myapp --resource-group myRG \
  --slot staging --target-slot production
```

**Rollback trigger criteria** (automate with Azure Monitor alerts):
- Error rate > 1% (baseline: 0.1%)
- p95 latency > 2000ms (baseline: 500ms)
- HTTP 5xx rate > 0.5%

---

## 3. A/B Testing

Route specific user segments to different versions to test hypotheses.

```yaml
# Azure App Configuration feature flag
{
  "id": "NewCheckoutFlow",
  "enabled": true,
  "conditions": {
    "client_filters": [
      {
        "name": "Microsoft.Targeting",
        "parameters": {
          "Audience": {
            "Groups": [{"Name": "BetaUsers", "RolloutPercentage": 100}],
            "DefaultRolloutPercentage": 10
          }
        }
      }
    ]
  }
}
```

---

## 4. Feature Flags

Decouple feature releases from code deployments. Enable/disable features without redeployment.

```csharp
// .NET: Azure App Configuration feature flag
var featureManager = serviceProvider.GetRequiredService<IFeatureManager>();

if (await featureManager.IsEnabledAsync("NewCheckoutFlow"))
{
    return RedirectToAction("NewCheckout");
}
return RedirectToAction("LegacyCheckout");
```

**Feature flag lifecycle**:
1. Create flag (disabled) → deploy code
2. Enable for internal users → validate
3. Enable for 10% → monitor
4. Enable for 100% → full rollout
5. Remove flag from code → cleanup

---

## 5. Deployment Rings

| Ring | Audience | Purpose |
|------|----------|---------|
| Ring 0 | Internal team | Catch obvious bugs |
| Ring 1 | Early adopters (1%) | Real user validation |
| Ring 2 | Broad users (10%) | Scale validation |
| Ring 3 | All users (100%) | Full rollout |

---

## 6. Automated Rollback Pipeline

```yaml
# Azure Pipelines: monitor and auto-rollback
- stage: Monitor
  jobs:
    - job: WatchMetrics
      steps:
        - script: |
            # Check error rate for 10 minutes post-deployment
            ERROR_RATE=$(az monitor metrics list \
              --resource $APP_INSIGHTS_ID \
              --metric "requests/failed" \
              --interval PT1M \
              --query "value[0].timeseries[0].data[-1].average")
            
            if (( $(echo "$ERROR_RATE > 1.0" | bc -l) )); then
              echo "Error rate $ERROR_RATE% exceeds threshold. Triggering rollback."
              exit 1
            fi
          
- stage: Rollback
  dependsOn: Monitor
  condition: failed()
  jobs:
    - job: SwapBack
      steps:
        - task: AzureAppServiceManage@0
          inputs:
            Action: 'Swap Slots'
            WebAppName: myapp
            SourceSlot: staging
```

---

## 7. Best Practices

- Always have a tested rollback procedure before deploying
- Define rollback criteria before deployment (not after something goes wrong)
- Use feature flags for risky features — decouple deployment from release
- Monitor business metrics (conversion rate, order completion) not just technical metrics
- Keep canary deployments running for at least 30 minutes before full rollout
- Database migrations must be backward compatible (old code must work with new schema)
