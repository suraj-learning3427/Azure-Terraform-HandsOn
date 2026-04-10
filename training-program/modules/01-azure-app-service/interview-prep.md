# Module 1: Azure App Service — Interview Preparation

---

## Question 1 (Conceptual): App Service Plan Tiers

**Question**: Walk me through the App Service Plan tiers and explain how you would choose the right tier for a production e-commerce application expecting 10,000 daily active users with occasional traffic spikes.

**Sample Answer**:

App Service Plans range from Free/Shared (dev/test only) through Basic, Standard, Premium v3, and Isolated v2. For a production e-commerce application, I'd immediately rule out Free and Shared — they have no SLA, run on shared infrastructure, and don't support custom domains on Free.

Basic is suitable for small production workloads with predictable traffic, but it doesn't support auto-scaling, which is a dealbreaker for an e-commerce site with spikes.

For 10,000 daily active users with spikes, I'd choose **Standard S2 or Premium v3 P1v3**. Here's my reasoning:

- Standard S2 gives you auto-scaling (up to 10 instances), deployment slots (up to 5), and a 99.95% SLA at roughly $100/month per instance. This works for moderate spikes.
- Premium v3 P1v3 gives you better price/performance (newer hardware), up to 20 deployment slots, VNet integration, and scales to 30 instances. At ~$73/month per instance with a 1-year reserved instance, it's actually cheaper than Standard S2 for sustained workloads.

I'd go with **Premium v3 P1v3** for this scenario because:
1. VNet integration lets us connect to Azure SQL via private endpoint
2. 20 deployment slots support multiple environments (dev, staging, UAT, prod)
3. Better performance per dollar on the newer Dv3 hardware
4. Scales to 30 instances for significant traffic spikes

If the application had compliance requirements (PCI-DSS, HIPAA) or needed full network isolation, I'd escalate to Isolated v2 in an App Service Environment.

**Follow-up Questions**:
- What's the difference between scale-out and scale-up, and when would you choose each?
- How does the App Service Plan affect deployment slot availability?
- What are the cost implications of running multiple apps on the same App Service Plan?

---

## Question 2 (Scenario): Zero-Downtime Deployment Strategy

**Question**: A client's current deployment process requires a 2-hour maintenance window every two weeks. They want to move to weekly releases with zero downtime. How would you design this using Azure App Service?

**Sample Answer**:

This is a classic deployment slot use case. Here's the architecture I'd implement:

**Slot Strategy:**
- Production slot: `myapp.azurewebsites.net` — live traffic
- Staging slot: `myapp-staging.azurewebsites.net` — new release target

**Deployment Flow:**
1. CI/CD pipeline builds and tests the application
2. Pipeline deploys the new version to the staging slot
3. Staging slot warms up (App Service sends HTTP requests to the health endpoint)
4. QA team validates on staging — runs smoke tests, checks Application Insights
5. Approval gate in Azure DevOps requires sign-off from QA lead
6. Pipeline executes a slot swap — staging becomes production atomically
7. Previous production is now in the staging slot (instant rollback available)

**Key Configuration Details:**

Slot-specific settings (sticky — don't swap):
- `ASPNETCORE_ENVIRONMENT` = Staging (so staging telemetry goes to a separate App Insights resource)
- Application Insights instrumentation key (separate resource for staging)

Settings that swap with the slot:
- Application code
- Non-environment-specific configuration
- Feature flags

**Rollback:**
If something goes wrong after the swap, rollback is a single CLI command:
```bash
az webapp deployment slot swap \
  --name myapp \
  --resource-group myRG \
  --slot staging \
  --target-slot production
```
This takes under 30 seconds — far better than a 2-hour maintenance window.

**Warm-up Configuration:**
I'd add an `applicationInitialization` section to `web.config` so App Service waits for the app to fully initialize before completing the swap:
```xml
<applicationInitialization>
  <add initializationPage="/health" />
  <add initializationPage="/api/warmup" />
</applicationInitialization>
```

This ensures the new version is fully warm before any production traffic hits it.

**Follow-up Questions**:
- What happens to in-flight requests during a slot swap?
- How would you implement a canary deployment where only 10% of users see the new version?
- What are slot-specific settings and why do they matter?

---

## Question 3 (Troubleshooting): Application Performance Degradation

**Question**: A production Web App on Azure App Service is experiencing intermittent 503 errors and high response times. Users are complaining. Walk me through your diagnostic approach.

**Sample Answer**:

I'd approach this systematically, starting with the fastest checks and working toward deeper investigation.

**Step 1: Check App Service Health (2 minutes)**
```bash
# Check if the app is running
az webapp show --name myapp --resource-group myRG --query state

# Check recent activity log for any platform events
az monitor activity-log list \
  --resource-group myRG \
  --start-time 2024-01-01T00:00:00Z \
  --query "[?resourceType=='Microsoft.Web/sites']"
```

**Step 2: Application Insights — Failures Blade (5 minutes)**
- Open Application Insights → Failures → check exception types and counts
- Look at the dependency failures tab — is SQL, Redis, or an external API timing out?
- Check the Performance blade for slow operations

**Step 3: Check Instance Health and Scaling**
- Is auto-scaling triggering? Check the autoscale history in Azure Monitor
- Are all instances healthy? Check the App Service → Diagnose and Solve Problems blade
- Is the App Service Plan CPU/memory maxed out? Check metrics

**Step 4: Check for Memory Leaks or Thread Pool Exhaustion**
- Enable Application Insights Profiler to capture CPU profiles
- Check the `HttpQueueLength` metric — if it's growing, the app can't keep up with requests
- Look for `ThreadPool` starvation in Application Insights exceptions

**Step 5: Check Dependencies**
- 503s often come from downstream dependencies timing out
- Check SQL Database DTU/vCore utilization
- Check if any external APIs are slow or returning errors

**Common Root Causes I've Seen:**
1. **Auto-scale not configured** — single instance gets overwhelmed
2. **Database connection pool exhaustion** — too many concurrent requests, not enough connections
3. **Memory leak** — app consumes all available RAM, GC pressure causes slowdowns
4. **Cold starts** — `Always On` not enabled, app spins down and takes 10+ seconds to restart
5. **Downstream dependency failure** — external API or database is the bottleneck

**Immediate Mitigation:**
If the app is down, I'd manually scale out to more instances immediately while investigating root cause:
```bash
az appservice plan update --name myPlan --resource-group myRG --number-of-workers 5
```

**Follow-up Questions**:
- How would you use Application Insights Live Metrics to diagnose a live incident?
- What's the difference between a 503 from App Service vs. a 503 from the application itself?
- How would you set up proactive alerting to catch this before users notice?

---

## Question 4 (Design): Cost Optimization for Azure App Service

**Question**: A client is spending $15,000/month on Azure App Service. Their CTO wants to reduce costs by 40% without impacting performance or reliability. What's your approach?

**Sample Answer**:

A 40% reduction ($6,000/month savings) is achievable with the right combination of strategies. I'd start with a cost analysis before making any changes.

**Step 1: Understand the Current Spend**
```bash
# Get cost breakdown by resource
az consumption usage list \
  --start-date 2024-01-01 \
  --end-date 2024-01-31 \
  --query "[?contains(instanceName, 'asp-')]"
```

**Step 2: Right-Size App Service Plans**
The biggest savings usually come from right-sizing. I'd check CPU and memory utilization over the past 30 days:
- If average CPU < 30% and memory < 40%, the plan is over-provisioned
- Downsize from P3v3 to P2v3, or P2v3 to P1v3
- Potential savings: 30–50% per plan

**Step 3: Reserved Instances**
For predictable workloads, Reserved Instances offer 35–55% savings:
- 1-year reserved: ~35% discount
- 3-year reserved: ~55% discount
- Only commit to the baseline instance count; let auto-scale handle peaks on pay-as-you-go

**Step 4: Consolidate Apps onto Fewer Plans**
Multiple small apps on separate plans can often be consolidated:
- Apps sharing a plan share compute resources
- Risk: a noisy neighbor app can impact others — monitor carefully
- Savings: eliminate entire plan costs

**Step 5: Optimize Auto-Scale Rules**
- Aggressive scale-in during off-hours (nights, weekends)
- Scheduled profiles to scale down to minimum during known low-traffic periods
- Example: scale from 5 instances to 2 instances between 10 PM and 6 AM

**Step 6: Migrate Appropriate Workloads to Functions**
- Background jobs, scheduled tasks, and event processors are often better on Consumption plan Functions
- A job running 1 hour/day on a dedicated App Service Plan costs ~$100/month
- The same job on Consumption Functions costs ~$0.20/month

**Step 7: Dev/Test Environments**
- Dev environments don't need Premium plans — use Basic or Standard
- Use auto-shutdown for dev environments during off-hours
- Consider Azure Dev/Test pricing (up to 55% discount for eligible subscriptions)

**Expected Savings Breakdown:**
| Action | Monthly Savings |
|--------|----------------|
| Right-size 3 plans (P3v3 → P2v3) | ~$2,000 |
| Reserved Instances on 5 baseline instances | ~$1,500 |
| Consolidate 4 dev apps onto 1 plan | ~$800 |
| Aggressive scale-in (nights/weekends) | ~$600 |
| Migrate 2 background jobs to Functions | ~$200 |
| **Total** | **~$5,100 (34%)** |

Combined with dev/test pricing, 40% is achievable.

**Follow-up Questions**:
- What are the risks of consolidating multiple apps onto a single App Service Plan?
- How do Reserved Instances work with auto-scaling?
- When would you recommend Azure Container Apps instead of App Service for cost optimization?

---

## Question 5 (Security): Securing an App Service Application

**Question**: A security audit found that a production Web App has database passwords stored as plaintext in app settings and is accessible over HTTP. What steps would you take to remediate this?

**Sample Answer**:

This is a critical security issue. I'd treat it as an incident and remediate immediately, then implement controls to prevent recurrence.

**Immediate Remediation (Day 1):**

1. **Rotate all compromised credentials** — assume the passwords are already compromised
2. **Enable HTTPS-only** immediately:
```bash
az webapp update \
  --name myapp \
  --resource-group myRG \
  --https-only true
```

3. **Migrate secrets to Key Vault:**
```bash
# Create Key Vault
az keyvault create --name kv-myapp-prod --resource-group myRG --sku standard

# Store the rotated password
az keyvault secret set --vault-name kv-myapp-prod --name SqlPassword --value "new-rotated-password"

# Enable Managed Identity on the Web App
az webapp identity assign --name myapp --resource-group myRG

# Grant the Web App access to Key Vault
PRINCIPAL_ID=$(az webapp identity show --name myapp --resource-group myRG --query principalId -o tsv)
az role assignment create \
  --role "Key Vault Secrets User" \
  --assignee $PRINCIPAL_ID \
  --scope $(az keyvault show --name kv-myapp-prod --query id -o tsv)

# Update app setting to use Key Vault reference
az webapp config appsettings set \
  --name myapp \
  --resource-group myRG \
  --settings "ConnectionStrings__Default=@Microsoft.KeyVault(VaultName=kv-myapp-prod;SecretName=SqlConnectionString)"
```

4. **Set minimum TLS version:**
```bash
az webapp config set \
  --name myapp \
  --resource-group myRG \
  --min-tls-version 1.2
```

**Preventive Controls:**

1. **Azure Policy**: Deny creation of App Service apps without HTTPS-only enabled
2. **Defender for App Service**: Enable for threat detection and security recommendations
3. **Secret scanning in CI/CD**: Add a pre-commit hook and pipeline step to scan for secrets (using tools like `detect-secrets` or GitHub Advanced Security)
4. **Access reviews**: Quarterly review of who has access to App Service configuration
5. **Key Vault audit logging**: Enable diagnostic logs to detect unauthorized secret access

**Architecture Pattern Going Forward:**
- All secrets → Key Vault
- App accesses Key Vault via Managed Identity (no credentials needed)
- Connection strings use `Authentication=Active Directory Managed Identity` for SQL
- No human ever needs to know the database password

**Follow-up Questions**:
- What's the difference between a system-assigned and user-assigned Managed Identity? When would you use each?
- How would you handle secret rotation without application downtime?
- What Azure Policy built-in definitions would you assign to enforce these security controls?

---

## Question 6 (Design): Scalability Architecture for High-Traffic Event

**Question**: A client is launching a product on a major TV show. They expect 100,000 concurrent users for 30 minutes, then traffic drops back to normal (5,000 concurrent users). How would you design the App Service architecture to handle this?

**Sample Answer**:

This is a classic "flash crowd" scenario — a predictable, massive, short-duration spike. The key insight is that reactive auto-scaling won't be fast enough; we need to pre-scale.

**Architecture Design:**

**Tier Selection**: Premium v3 P2v3
- 2 vCPU, 8 GB RAM per instance
- Supports up to 30 instances
- VNet integration for secure database access

**Pre-Scaling Strategy:**
Since we know the exact time of the TV show, I'd use a scheduled auto-scale profile:
```bash
# Pre-scale to 20 instances 30 minutes before the show
az monitor autoscale profile create \
  --autoscale-name autoscale-myapp \
  --name "TVShowEvent" \
  --timezone "Eastern Standard Time" \
  --start "2024-03-15T19:30:00" \
  --end "2024-03-15T21:00:00" \
  --min-count 20 \
  --max-count 30 \
  --count 20
```

**Capacity Planning:**
- 100,000 concurrent users / 20 instances = 5,000 users per instance
- P2v3 can handle ~3,000–5,000 concurrent connections depending on app behavior
- I'd load test to validate this assumption before the event

**Supporting Architecture:**
1. **Azure Front Door** in front of App Service:
   - Global CDN for static assets (reduces App Service load by 60–70%)
   - WAF to block malicious traffic during high-profile events
   - Health probes to route away from unhealthy instances

2. **Azure Cache for Redis**:
   - Cache product catalog, pricing, and inventory data
   - Reduces database load by 80%+ for read-heavy scenarios

3. **Database scaling**:
   - Pre-scale Azure SQL to higher DTU/vCore tier before the event
   - Enable read replicas for reporting queries

4. **Application Insights**:
   - Live Metrics stream open during the event
   - Alert if error rate > 1% or p95 latency > 2 seconds

**Post-Event Scale-Down:**
After the event, the scheduled profile ends and the default profile takes over, scaling back to 2 instances. I'd also set a scale-in rule to gradually reduce instances as traffic drops.

**Load Testing:**
Before the event, I'd run a load test with Azure Load Testing simulating 100,000 concurrent users to validate the architecture holds up and identify bottlenecks.

**Follow-up Questions**:
- How would you handle the database becoming a bottleneck during the spike?
- What's the difference between Azure Front Door and Azure CDN for this scenario?
- How would you communicate the scaling plan to the client and get their approval?

---

## Question 7 (Troubleshooting): Azure Functions Cold Start Issues

**Question**: A client's Azure Functions on the Consumption plan are experiencing 8–12 second cold starts, causing timeouts in their API. How would you diagnose and resolve this?

**Sample Answer**:

Cold starts on Consumption plan are a well-known issue, especially for .NET functions. Here's my approach:

**Diagnosis:**
First, confirm it's actually cold starts and not something else:
```kusto
// Application Insights KQL: identify cold start requests
requests
| where timestamp > ago(24h)
| where duration > 5000  // > 5 seconds
| extend isColdStart = tostring(customDimensions["ColdStart"])
| summarize count(), avg(duration) by isColdStart, bin(timestamp, 1h)
```

**Root Causes of Long Cold Starts:**
1. **Large deployment package** — .NET apps with many dependencies take longer to load
2. **Dependency injection setup** — complex DI container initialization
3. **Static initializers** — heavy work in static constructors
4. **Missing pre-compiled binaries** — using `dotnet run` instead of pre-compiled

**Solutions (in order of cost/complexity):**

**Option 1: Optimize the Function (Free)**
- Use `WEBSITE_RUN_FROM_PACKAGE=1` to run from a zip package (faster startup)
- Minimize dependencies — remove unused NuGet packages
- Move heavy initialization to lazy loading
- Use .NET isolated worker model (faster startup than in-process)

**Option 2: Premium Plan (~$125/month)**
The most reliable solution for latency-sensitive APIs:
```hcl
resource "azurerm_service_plan" "premium" {
  name     = "asp-functions-premium"
  sku_name = "EP1"  # Premium Elastic Plan 1
  # Always-warm instances eliminate cold starts
}
```
Premium plan keeps at least 1 instance always warm. No cold starts.

**Option 3: Flex Consumption Plan (Preview)**
New plan that offers per-second billing like Consumption but with pre-provisioned instances to eliminate cold starts. Good middle ground between Consumption and Premium.

**Option 4: "Always Ready" Instances**
On Premium plan, configure always-ready instances:
```json
{
  "functionAppScaleLimit": 20,
  "minimumElasticInstanceCount": 1
}
```

**My Recommendation:**
For an API with latency requirements, I'd move to the Premium EP1 plan. The $125/month cost is justified by eliminating 8–12 second cold starts that are causing timeouts. The Consumption plan is designed for workloads that can tolerate cold starts (background jobs, event processing).

**Follow-up Questions**:
- When is the Consumption plan the right choice despite cold starts?
- How does the Durable Functions extension affect cold start times?
- What's the difference between Premium EP1, EP2, and EP3?

---

## Question 8 (Design): Multi-Region App Service Architecture

**Question**: A financial services client needs their web application to be available even if an entire Azure region goes down. How would you design a multi-region App Service architecture?

**Sample Answer**:

Multi-region active-active or active-passive architectures for App Service require several components working together. Here's the design I'd recommend:

**Architecture: Active-Active with Azure Front Door**

```
Users → Azure Front Door (Global) → App Service (East US 2) [Primary]
                                  → App Service (West US 2) [Secondary]
                                  → Azure SQL (East US 2) [Primary]
                                  → Azure SQL (West US 2) [Secondary, read replica]
```

**Components:**

1. **Azure Front Door Premium**:
   - Global load balancer with health probes to both regions
   - Routes traffic to the nearest healthy region
   - Automatic failover if a region becomes unhealthy
   - WAF policy applied globally

2. **App Service in Two Regions**:
   - Identical App Service Plans in East US 2 and West US 2
   - Same application code deployed to both (via CI/CD pipeline)
   - Each region has its own deployment slots for zero-downtime deployments

3. **Azure SQL with Failover Groups**:
   - Primary in East US 2, secondary in West US 2
   - Automatic failover with < 30-second RTO
   - Read replicas in West US 2 for reporting queries

4. **Azure Cache for Redis (Geo-Replication)**:
   - Session state and cache replicated between regions
   - Prevents session loss during failover

**Terraform Snippet:**
```hcl
# Front Door with two origins
resource "azurerm_cdn_frontdoor_origin_group" "main" {
  name                     = "app-origin-group"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id

  health_probe {
    interval_in_seconds = 30
    path                = "/health"
    protocol            = "Https"
    request_type        = "GET"
  }

  load_balancing {
    sample_size                 = 4
    successful_samples_required = 2
  }
}

resource "azurerm_cdn_frontdoor_origin" "eastus2" {
  name                          = "app-eastus2"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.main.id
  host_name                     = azurerm_linux_web_app.eastus2.default_hostname
  priority                      = 1
  weight                        = 1000
}

resource "azurerm_cdn_frontdoor_origin" "westus2" {
  name                          = "app-westus2"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.main.id
  host_name                     = azurerm_linux_web_app.westus2.default_hostname
  priority                      = 2  # Secondary — used only if primary fails
  weight                        = 1000
}
```

**RTO/RPO Targets:**
- RTO (Recovery Time Objective): < 2 minutes (Front Door detects failure in ~30 seconds, reroutes traffic)
- RPO (Recovery Point Objective): < 5 seconds (SQL failover group replication lag)

**Cost Considerations:**
- Running two full App Service Plans doubles compute costs
- For cost-sensitive clients, consider active-passive: secondary region runs on Basic plan (no auto-scale) and scales up only during failover
- Azure Front Door Premium: ~$330/month base + data transfer costs

**Follow-up Questions**:
- What's the difference between Azure Front Door and Azure Traffic Manager for multi-region routing?
- How would you handle database writes during a regional failover?
- What are the compliance implications of data replicating to a secondary region?
