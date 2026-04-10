# Module 1: Azure App Service — Assessment

---

## Knowledge Check Questions

### Question 1

**A production web application needs auto-scaling, deployment slots, and VNet integration. Which App Service Plan tier is the minimum required, and why?**

**Expected Answer**:

The minimum tier is **Premium v3**. Here's why each requirement maps to a tier:

- **Auto-scaling**: Available from Standard tier and above. Basic does not support auto-scaling.
- **Deployment slots**: Available from Standard (up to 5 slots) and above. Premium v3 supports up to 20 slots.
- **VNet integration**: Regional VNet integration is available on Standard and above, but **Premium v3** provides full VNet integration with outbound traffic routing through the VNet. Standard tier's VNet integration has limitations with certain private endpoint scenarios.

Standard S2 technically meets all three requirements, but Premium v3 P1v3 is the better choice because:
- Better price/performance ratio (newer Dv3 hardware)
- More deployment slots (20 vs. 5)
- Full VNet integration with `WEBSITE_VNET_ROUTE_ALL=1` support
- Lower cost with Reserved Instances compared to Standard

**Incorrect answers to watch for**:
- "Basic" — Basic does not support auto-scaling or deployment slots
- "Standard" — Technically correct for the minimum, but misses the VNet integration nuance
- "Isolated" — Correct but over-engineered for this scenario

---

### Question 2

**What is the difference between a slot-specific (sticky) setting and a regular app setting in Azure App Service? Give an example of each.**

**Expected Answer**:

**Regular app settings** swap with the deployment slot. When you swap staging to production, these settings move with the application code to production.

**Slot-specific (sticky) settings** stay with the slot regardless of swaps. They are bound to the slot, not the application version.

**Example of a slot-specific setting** (should NOT swap):
- `ASPNETCORE_ENVIRONMENT` = `Staging` on the staging slot, `Production` on the production slot
- Application Insights instrumentation key — you want staging telemetry to go to a separate App Insights resource, not mix with production data
- Slot-specific feature flags

**Example of a regular app setting** (SHOULD swap):
- `FeatureFlags__EnableNewCheckout` = `true` — this is a feature you're testing in staging and want to enable in production after the swap
- Third-party API endpoints that are the same across environments
- Application configuration values that are part of the release

**Why this matters**: If `ASPNETCORE_ENVIRONMENT` were not slot-specific, after a swap, the production slot would have `ASPNETCORE_ENVIRONMENT=Staging`, causing the app to behave as if it's in a staging environment in production — a serious misconfiguration.

---

### Question 3

**Explain the Azure Functions hosting plan options. A logistics company needs to process 500 orders per minute with no cold starts and requires VNet integration to access a private SQL endpoint. Which plan should they use and why?**

**Expected Answer**:

The correct answer is the **Premium plan (Elastic Premium)**.

**Plan comparison for this scenario:**

| Requirement | Consumption | Flex Consumption | Premium | Dedicated |
|-------------|-------------|-----------------|---------|-----------|
| No cold starts | ❌ | Partial | ✅ | ✅ |
| VNet integration | Limited | ✅ | ✅ | ✅ |
| 500 orders/min scale | ✅ | ✅ | ✅ | Manual |
| Cost at 500/min | Low | Low-Medium | Medium | High |

**Why Premium:**
- **No cold starts**: Premium keeps at least 1 instance always warm (pre-warmed instances)
- **Full VNet integration**: Can access private SQL endpoints via VNet
- **Auto-scale**: Scales from 1 to 100 instances based on queue depth
- **Unlimited execution duration**: No 10-minute timeout like Consumption

**Why not Consumption**: Cold starts of 5–15 seconds would cause timeouts when processing orders. VNet integration is also limited on Consumption.

**Why not Dedicated**: Would require manual scaling and doesn't auto-scale based on queue depth.

**Cost note**: Premium EP1 costs ~$125/month for the always-warm instance, plus additional instances during scale-out. For 500 orders/minute, this is justified by the reliability and latency requirements.

---

### Question 4

**A Web App is experiencing 503 errors intermittently. You check Application Insights and see that `HttpQueueLength` is consistently above 500. What does this indicate and what actions would you take?**

**Expected Answer**:

`HttpQueueLength` represents the number of HTTP requests waiting in the queue to be processed by the application. A value consistently above 500 indicates **the application cannot process requests fast enough** — requests are backing up.

**Root causes to investigate:**
1. **Insufficient instances**: The App Service Plan doesn't have enough instances to handle the load
2. **Slow application code**: Each request takes too long, blocking threads
3. **Database bottleneck**: Requests are waiting for slow SQL queries
4. **Thread pool exhaustion**: Synchronous blocking calls consuming all available threads

**Immediate actions:**
1. **Scale out immediately** to add more instances:
   ```bash
   az appservice plan update --name myPlan --resource-group myRG --number-of-workers 5
   ```
2. **Check auto-scale configuration** — is it configured? Is it triggering? Check the autoscale history.

**Investigation steps:**
1. Application Insights → Performance → check slowest operations
2. Application Insights → Dependencies → check SQL query durations
3. Enable Application Insights Profiler to capture CPU profiles
4. Check if `async/await` is used correctly (sync-over-async causes thread pool starvation)

**Long-term fix:**
- Configure auto-scaling with `HttpQueueLength > 100` as a scale-out trigger (in addition to CPU)
- Profile and optimize slow database queries
- Implement caching for frequently-read data

---

### Question 5

**What is the purpose of the `applicationInitialization` configuration in a Web App, and how does it relate to deployment slot swaps?**

**Expected Answer**:

`applicationInitialization` defines HTTP paths that App Service should request to warm up the application before completing a slot swap. It ensures the new version is fully initialized and ready to serve traffic before any production requests hit it.

**Without `applicationInitialization`:**
- App Service swaps slots as soon as the new instance starts
- The first real user requests hit a cold application, experiencing slow response times or errors during initialization

**With `applicationInitialization`:**
- App Service sends HTTP requests to the configured paths on the new slot
- The swap only completes after all initialization paths return 200
- Users never experience cold start latency

**Configuration example:**
```xml
<system.webServer>
  <applicationInitialization>
    <!-- Warm up the main page -->
    <add initializationPage="/" />
    <!-- Warm up the API (triggers DI container, DB connection pool) -->
    <add initializationPage="/api/health" />
    <!-- Warm up a specific feature that has heavy initialization -->
    <add initializationPage="/api/warmup/cache" />
  </applicationInitialization>
</system.webServer>
```

**Best practice**: The warmup endpoint should trigger all expensive initialization (database connection pool, cache population, DI container resolution) so the app is fully ready when the swap completes.

**Timeout consideration**: If warmup takes longer than the swap timeout (default 90 seconds), the swap fails and the original slot remains in production. Increase the timeout with `WEBSITE_SWAP_WARMUP_PING_STATUSES` and `WEBSITE_SWAP_WARMUP_PING_PATH` app settings.

---

## Practical Skill Tasks

### Task 1: Deploy a Web App with Deployment Slots and Auto-Scaling

**Objective**: Deploy a .NET web application to Azure App Service with a staging slot and auto-scaling configured.

**Prerequisites**:
- Azure subscription with Contributor access
- Azure CLI installed and authenticated
- .NET 8 SDK installed
- A sample .NET web application (or use `dotnet new webapp`)

**Steps**:

1. Create a resource group and Premium v3 App Service Plan
2. Create a Web App with system-assigned Managed Identity
3. Create a staging deployment slot
4. Configure slot-specific settings (environment name, App Insights key)
5. Deploy the application to the staging slot
6. Configure auto-scaling: scale out at CPU > 70%, scale in at CPU < 30%
7. Perform a slot swap from staging to production
8. Verify the application is running in production

**Validation Steps**:

```bash
# 1. Verify the App Service Plan is Premium v3
az appservice plan show \
  --name $PLAN \
  --resource-group $RG \
  --query "sku.name" -o tsv
# Expected output: P1v3 (or P2v3, P3v3)

# 2. Verify the staging slot exists
az webapp deployment slot list \
  --name $APP \
  --resource-group $RG \
  --query "[].name" -o tsv
# Expected output: staging

# 3. Verify the production app returns 200
curl -s -o /dev/null -w "%{http_code}" https://$APP.azurewebsites.net/health
# Expected output: 200

# 4. Verify auto-scaling is configured
az monitor autoscale show \
  --name "autoscale-$APP" \
  --resource-group $RG \
  --query "profiles[0].rules | length(@)"
# Expected output: 2 (one scale-out, one scale-in rule)

# 5. Verify Managed Identity is enabled
az webapp identity show \
  --name $APP \
  --resource-group $RG \
  --query "type" -o tsv
# Expected output: SystemAssigned

# 6. Verify HTTPS-only is enabled
az webapp show \
  --name $APP \
  --resource-group $RG \
  --query "httpsOnly" -o tsv
# Expected output: true
```

**Expected Outcome**: The application is accessible at `https://<appname>.azurewebsites.net`, the staging slot is accessible at `https://<appname>-staging.azurewebsites.net`, and auto-scaling rules are visible in Azure Monitor.

---

### Task 2: Implement Azure Functions with Service Bus Trigger and Dead-Letter Handling

**Objective**: Create an Azure Function that processes messages from a Service Bus queue with retry logic and dead-letter queue monitoring.

**Prerequisites**:
- Azure subscription with Contributor access
- Azure Functions Core Tools v4 installed
- .NET 8 SDK installed
- Azure Service Bus namespace (Standard tier)

**Steps**:

1. Create a Service Bus namespace and queue with dead-letter queue enabled
2. Create a Premium Function App with system-assigned Managed Identity
3. Grant the Function App's identity `Azure Service Bus Data Receiver` role on the namespace
4. Implement a Service Bus-triggered function with:
   - Structured logging with correlation IDs
   - Idempotency check (skip if already processed)
   - Explicit message completion/abandonment/dead-lettering
5. Configure `host.json` with exponential backoff retry (5 retries, 2s–15min)
6. Implement a second function triggered by the dead-letter queue that logs an alert
7. Deploy both functions to Azure
8. Send test messages and verify processing

**Validation Steps**:

```bash
# 1. Verify Function App is running on Premium plan
az functionapp show \
  --name $FUNC_APP \
  --resource-group $RG \
  --query "sku" -o tsv
# Expected: ElasticPremium

# 2. Verify Managed Identity has Service Bus role
az role assignment list \
  --assignee $(az functionapp identity show --name $FUNC_APP --resource-group $RG --query principalId -o tsv) \
  --query "[].roleDefinitionName" -o tsv
# Expected output includes: Azure Service Bus Data Receiver

# 3. Send a test message and verify it's processed
az servicebus message send \
  --namespace-name $SB_NAMESPACE \
  --queue-name orders-processing \
  --body '{"orderId":"TEST-001","clientId":"CLIENT-A","amount":99.99}'

# Wait 30 seconds, then check Application Insights for the log entry
# (Check via Azure Portal → Application Insights → Logs)

# 4. Send a message that will fail (invalid JSON) and verify it lands in DLQ
az servicebus message send \
  --namespace-name $SB_NAMESPACE \
  --queue-name orders-processing \
  --body 'invalid-json'

# After max retries, check DLQ message count
az servicebus queue show \
  --namespace-name $SB_NAMESPACE \
  --name orders-processing \
  --resource-group $RG \
  --query "countDetails.deadLetterMessageCount"
# Expected: 1

# 5. Verify no plaintext credentials in app settings
az functionapp config appsettings list \
  --name $FUNC_APP \
  --resource-group $RG \
  --query "[?contains(value, 'Endpoint=sb://')]"
# Expected: empty array (connection string should be a Key Vault reference)
```

**Expected Outcome**: Valid messages are processed and logged in Application Insights. Invalid messages are retried 5 times with exponential backoff and then moved to the dead-letter queue. The DLQ processor function logs an alert when a message arrives in the DLQ.

---

## Assessment Rubric

### Criterion 1: Azure App Service Architecture Design

| Level | Score | Description |
|-------|-------|-------------|
| Exemplary | 4 | Selects the optimal App Service Plan tier with clear justification based on requirements (auto-scale, slots, VNet, SLA). Designs a complete deployment slot strategy with slot-specific settings correctly identified. Configures auto-scaling with both scale-out and scale-in rules, appropriate cooldown periods, and scheduled profiles for known traffic patterns. Addresses cost optimization with Reserved Instances and right-sizing. |
| Proficient | 3 | Selects an appropriate App Service Plan tier with reasonable justification. Implements deployment slots with a working swap strategy. Configures auto-scaling with scale-out and scale-in rules. Minor gaps in cost optimization or slot-specific settings configuration. |
| Developing | 2 | Selects a valid App Service Plan tier but without clear justification. Implements deployment slots but may not correctly identify slot-specific settings. Configures auto-scaling but missing scale-in rules or cooldown periods. Limited consideration of cost. |
| Beginning | 1 | Selects an inappropriate tier (e.g., Basic for a workload requiring auto-scale) or cannot justify the selection. Does not implement deployment slots or implements them incorrectly. Auto-scaling is missing or misconfigured. No cost considerations. |

---

### Criterion 2: Security Implementation

| Level | Score | Description |
|-------|-------|-------------|
| Exemplary | 4 | All secrets stored in Key Vault with Key Vault references in app settings. Managed Identity used for all Azure service authentication (no passwords or connection strings with credentials). HTTPS-only enabled with TLS 1.2 minimum. VNet integration configured for private endpoint access. Defender for App Service enabled. Can articulate the difference between system-assigned and user-assigned Managed Identity and when to use each. |
| Proficient | 3 | Secrets stored in Key Vault with Key Vault references. Managed Identity configured for Key Vault access. HTTPS-only enabled. Minor gaps such as missing VNet integration or Defender for App Service. |
| Developing | 2 | Attempts to use Key Vault but may have configuration errors (e.g., incorrect Key Vault reference syntax). Managed Identity configured but not correctly granted access. HTTPS-only may not be enabled. |
| Beginning | 1 | Secrets stored as plaintext in app settings or pipeline variables. No Managed Identity configured. HTTP access not restricted. Cannot explain why Managed Identity is preferred over connection strings with passwords. |

---

### Criterion 3: Azure Functions Design and Implementation

| Level | Score | Description |
|-------|-------|-------------|
| Exemplary | 4 | Selects the correct hosting plan (Premium vs. Consumption) with clear justification based on cold start, VNet, and scale requirements. Implements correct trigger and binding types. Configures retry policy with exponential backoff in `host.json`. Implements idempotency to handle at-least-once delivery. Handles message completion, abandonment, and dead-lettering explicitly. Implements structured logging with correlation IDs for end-to-end tracing. |
| Proficient | 3 | Selects an appropriate hosting plan with reasonable justification. Implements correct trigger type. Configures retry policy. Implements basic idempotency. Handles message completion and dead-lettering. Structured logging present but may lack correlation IDs. |
| Developing | 2 | Selects a hosting plan but cannot fully justify the choice. Implements the trigger but may use auto-complete (losing control over message settlement). Retry policy configured but may use fixed interval instead of exponential backoff. Idempotency not implemented. |
| Beginning | 1 | Cannot select an appropriate hosting plan or justify the choice. Trigger type incorrect or missing. No retry policy. No idempotency. Uses auto-complete without understanding the implications. No structured logging. |

---

## Module Completion Checklist

Before marking this module complete, verify:

- [ ] Can explain the difference between all App Service Plan tiers and select the appropriate one for a given scenario
- [ ] Can create a Web App with deployment slots using Azure CLI and Terraform
- [ ] Can configure slot-specific settings and explain why they matter
- [ ] Can perform a slot swap and explain the warm-up process
- [ ] Can configure metric-based and schedule-based auto-scaling rules
- [ ] Can explain the difference between Azure Functions hosting plans and select the right one
- [ ] Can implement a Service Bus-triggered function with retry logic and dead-letter handling
- [ ] Can implement Managed Identity authentication for Key Vault and Azure SQL
- [ ] Can diagnose common App Service issues using Application Insights and Azure Monitor
- [ ] Can design a cost-optimized App Service architecture using Reserved Instances and right-sizing
