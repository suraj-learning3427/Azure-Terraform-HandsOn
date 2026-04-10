# Module 1: Azure App Service — Theory

## Learning Objectives

By the end of this module, you will be able to:
- Select the appropriate App Service Plan tier for a given workload
- Configure Web Apps with runtime stacks, app settings, and connection strings
- Design Azure Functions using the right hosting plan, triggers, and bindings
- Implement deployment slots for zero-downtime releases and canary deployments
- Configure metric-based and schedule-based auto-scaling rules

---

## 1. App Service Plans

An App Service Plan defines the compute resources (CPU, memory, disk) that your App Service apps run on. All apps in the same plan share the same VM instances. Understanding plan tiers is critical for cost optimization and performance.

### 1.1 Tier Overview

| Tier | SKU Examples | vCPUs | RAM | Storage | Custom Domains | SSL | Auto-scale | SLA |
|------|-------------|-------|-----|---------|----------------|-----|------------|-----|
| Free | F1 | Shared | 1 GB | 1 GB | No | No | No | None |
| Shared | D1 | Shared | 1 GB | 1 GB | Yes | No | No | None |
| Basic | B1, B2, B3 | 1–4 | 1.75–7 GB | 10 GB | Yes | SNI SSL | No | 99.95% |
| Standard | S1, S2, S3 | 1–4 | 1.75–7 GB | 50 GB | Yes | SNI+IP SSL | Yes (up to 10) | 99.95% |
| Premium v3 | P1v3, P2v3, P3v3 | 2–8 | 8–32 GB | 250 GB | Yes | SNI+IP SSL | Yes (up to 30) | 99.95% |
| Isolated v2 | I1v2, I2v2, I3v2 | 2–8 | 8–32 GB | 1 TB | Yes | SNI+IP SSL | Yes (up to 100) | 99.95% |

**Key decision points:**
- **Free/Shared**: Dev/test only. No SLA, shared infrastructure, no custom domains on Free.
- **Basic**: Small production workloads with predictable traffic. No auto-scale.
- **Standard**: Most production workloads. Enables deployment slots (up to 5) and auto-scale.
- **Premium v3**: High-performance workloads, VNet integration, larger instances, up to 20 slots.
- **Isolated v2**: Runs in a dedicated Azure App Service Environment (ASE). Full network isolation, highest scale, compliance requirements (PCI-DSS, HIPAA).

### 1.2 App Service Environment (ASE)

ASE is a fully isolated, dedicated environment for running App Service apps at high scale. Use it when you need:
- Network isolation with a private VNet
- Inbound/outbound traffic control via NSGs
- Scale beyond standard limits (up to 200 total instances)
- Compliance requirements mandating dedicated infrastructure

```bash
# Create an App Service Plan (Standard S2)
az appservice plan create \
  --name myAppServicePlan \
  --resource-group myResourceGroup \
  --sku S2 \
  --is-linux

# Scale up to Premium v3
az appservice plan update \
  --name myAppServicePlan \
  --resource-group myResourceGroup \
  --sku P2v3
```

### 1.3 Terraform: App Service Plan

```hcl
resource "azurerm_service_plan" "main" {
  name                = "asp-myapp-prod"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = "P2v3"  # Premium v3 for production

  tags = {
    environment = "production"
    team        = "platform"
  }
}
```

---

## 2. Web Apps

Azure Web Apps (part of App Service) support multiple runtime stacks and provide a fully managed platform for hosting web applications.

### 2.1 Runtime Stacks

Supported stacks include:
- **.NET**: .NET 6, 7, 8 (LTS), .NET Framework 4.8 (Windows only)
- **Node.js**: 18 LTS, 20 LTS
- **Python**: 3.9, 3.10, 3.11, 3.12
- **Java**: Java 8, 11, 17, 21 (Tomcat, JBoss EAP, Java SE)
- **PHP**: 8.0, 8.1, 8.2
- **Ruby**: 3.2 (Linux only)
- **Custom containers**: Docker single-container or Docker Compose

```bash
# Create a .NET 8 Web App on Linux
az webapp create \
  --name myWebApp \
  --resource-group myResourceGroup \
  --plan myAppServicePlan \
  --runtime "DOTNETCORE:8.0"

# List available runtimes
az webapp list-runtimes --os-type linux
```

### 2.2 Application Settings and Connection Strings

App settings are environment variables injected into your app at runtime. They override values in `appsettings.json` (for .NET) or equivalent config files. **Never hardcode secrets in code or config files.**

```bash
# Set application settings
az webapp config appsettings set \
  --name myWebApp \
  --resource-group myResourceGroup \
  --settings \
    ASPNETCORE_ENVIRONMENT=Production \
    ApplicationInsights__InstrumentationKey=@Microsoft.KeyVault(SecretUri=https://myvault.vault.azure.net/secrets/AppInsightsKey/) \
    FeatureFlags__EnableNewCheckout=true

# Set connection strings (stored separately, encrypted at rest)
az webapp config connection-string set \
  --name myWebApp \
  --resource-group myResourceGroup \
  --connection-string-type SQLAzure \
  --settings DefaultConnection="Server=tcp:myserver.database.windows.net,1433;Database=mydb;Authentication=Active Directory Managed Identity;"
```

**Key Vault references** allow app settings to pull values directly from Key Vault without storing secrets in App Service:

```
@Microsoft.KeyVault(SecretUri=https://myvault.vault.azure.net/secrets/MySecret/version)
@Microsoft.KeyVault(VaultName=myvault;SecretName=MySecret)
```

For this to work, the Web App's Managed Identity must have `Key Vault Secrets User` role on the vault.

### 2.3 Configuration Best Practices

```hcl
# Terraform: Web App with Key Vault reference in app settings
resource "azurerm_linux_web_app" "main" {
  name                = "app-myapp-prod"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.main.id

  # Enable system-assigned managed identity for Key Vault access
  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      dotnet_version = "8.0"
    }
    always_on        = true   # Prevent cold starts on Basic+ tiers
    http2_enabled    = true
    minimum_tls_version = "1.2"
  }

  app_settings = {
    "ASPNETCORE_ENVIRONMENT"    = "Production"
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.main.name};SecretName=AppInsightsConnectionString)"
    "WEBSITE_RUN_FROM_PACKAGE"  = "1"  # Run app directly from zip package
  }

  connection_string {
    name  = "DefaultConnection"
    type  = "SQLAzure"
    value = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.main.name};SecretName=SqlConnectionString)"
  }

  logs {
    http_logs {
      retention_in_days = 7
    }
    application_logs {
      file_system_level = "Warning"
    }
  }
}
```

### 2.4 Startup Commands and Custom Containers

```bash
# Set startup command for Python app
az webapp config set \
  --name myWebApp \
  --resource-group myResourceGroup \
  --startup-file "gunicorn --bind=0.0.0.0 --timeout 600 app:app"

# Deploy a custom Docker container
az webapp config container set \
  --name myWebApp \
  --resource-group myResourceGroup \
  --docker-custom-image-name myregistry.azurecr.io/myapp:latest \
  --docker-registry-server-url https://myregistry.azurecr.io
```

---

## 3. Azure Functions

Azure Functions is a serverless compute service that lets you run event-driven code without managing infrastructure. Functions are ideal for event processing, scheduled tasks, and lightweight APIs.

### 3.1 Hosting Plans

| Plan | Cold Start | Scale | Max Duration | VNet Integration | Cost Model |
|------|-----------|-------|--------------|-----------------|------------|
| Consumption | Yes (seconds) | 0 → 200 instances | 10 min (default), 60 min (max) | Limited | Pay per execution |
| Flex Consumption | Minimal | 0 → 1000 instances | Unlimited | Yes | Pay per execution + provisioned |
| Premium | No | 1 → 100 instances | Unlimited | Yes | Per-second billing |
| Dedicated (App Service) | No | Manual/auto-scale | Unlimited | Yes | App Service Plan cost |

**When to use each:**
- **Consumption**: Sporadic, unpredictable workloads. Cost-effective for low-volume scenarios.
- **Flex Consumption**: High-scale event-driven workloads needing VNet integration without cold starts.
- **Premium**: Always-warm instances, VNet integration, longer execution times, VNET-triggered functions.
- **Dedicated**: When you already have an App Service Plan and want to co-locate functions.

### 3.2 Triggers and Bindings

Triggers define how a function is invoked. Bindings provide declarative connections to other services.

**Common Triggers:**
- `HttpTrigger`: HTTP requests (REST APIs, webhooks)
- `TimerTrigger`: CRON schedule
- `ServiceBusTrigger`: Azure Service Bus queue/topic messages
- `BlobTrigger`: New/updated blobs in Azure Storage
- `EventHubTrigger`: Azure Event Hub streams
- `CosmosDBTrigger`: Change feed from Cosmos DB
- `QueueTrigger`: Azure Storage Queue messages

**Example: Service Bus Trigger with Output Binding**

```csharp
// C# Azure Function: Process order from Service Bus, write to Cosmos DB
[FunctionName("ProcessOrder")]
public static async Task Run(
    [ServiceBusTrigger("orders-queue", Connection = "ServiceBusConnection")] 
    string orderMessage,
    [CosmosDB(
        databaseName: "OrdersDB",
        containerName: "ProcessedOrders",
        Connection = "CosmosDBConnection")]
    IAsyncCollector<ProcessedOrder> processedOrders,
    ILogger log)
{
    log.LogInformation($"Processing order: {orderMessage}");
    
    var order = JsonSerializer.Deserialize<Order>(orderMessage);
    var processed = new ProcessedOrder
    {
        Id = Guid.NewGuid().ToString(),
        OrderId = order.Id,
        ProcessedAt = DateTime.UtcNow,
        Status = "Completed"
    };
    
    await processedOrders.AddAsync(processed);
}
```

**host.json configuration for retry policies:**

```json
{
  "version": "2.0",
  "extensions": {
    "serviceBus": {
      "prefetchCount": 100,
      "messageHandlerOptions": {
        "autoComplete": false,
        "maxConcurrentCalls": 32,
        "maxAutoRenewDuration": "00:55:00"
      }
    }
  },
  "retry": {
    "strategy": "exponentialBackoff",
    "maxRetryCount": 5,
    "minimumInterval": "00:00:02",
    "maximumInterval": "00:15:00"
  }
}
```

### 3.3 Durable Functions

Durable Functions extend Azure Functions with stateful workflows using the orchestrator pattern. They solve the problem of coordinating long-running, multi-step processes.

**Patterns:**
- **Function Chaining**: Execute functions sequentially, passing output to the next
- **Fan-out/Fan-in**: Execute multiple functions in parallel, aggregate results
- **Async HTTP API**: Long-running operation with polling endpoint
- **Monitor**: Flexible recurring process (polling until condition met)
- **Human Interaction**: Workflow pauses waiting for external event (approval)

```csharp
// Orchestrator function: Fan-out/Fan-in pattern
[FunctionName("OrderFulfillmentOrchestrator")]
public static async Task<FulfillmentResult> RunOrchestrator(
    [OrchestrationTrigger] IDurableOrchestrationContext context)
{
    var order = context.GetInput<Order>();
    
    // Fan-out: run all checks in parallel
    var tasks = new List<Task<bool>>
    {
        context.CallActivityAsync<bool>("CheckInventory", order),
        context.CallActivityAsync<bool>("ValidatePayment", order),
        context.CallActivityAsync<bool>("CheckFraud", order)
    };
    
    // Fan-in: wait for all to complete
    var results = await Task.WhenAll(tasks);
    
    if (results.All(r => r))
    {
        // All checks passed — ship the order
        await context.CallActivityAsync("ShipOrder", order);
        return new FulfillmentResult { Success = true };
    }
    
    return new FulfillmentResult { Success = false, Reason = "Validation failed" };
}
```

### 3.4 Terraform: Azure Function App

```hcl
resource "azurerm_linux_function_app" "main" {
  name                = "func-orderprocessor-prod"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  storage_account_name       = azurerm_storage_account.functions.name
  storage_account_access_key = azurerm_storage_account.functions.primary_access_key
  service_plan_id            = azurerm_service_plan.premium.id

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      dotnet_version              = "8.0"
      use_dotnet_isolated_runtime = true
    }
    application_insights_connection_string = azurerm_application_insights.main.connection_string
  }

  app_settings = {
    "ServiceBusConnection"  = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.main.name};SecretName=ServiceBusConnectionString)"
    "CosmosDBConnection"    = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.main.name};SecretName=CosmosDBConnectionString)"
    "FUNCTIONS_WORKER_RUNTIME" = "dotnet-isolated"
  }
}
```

---

## 4. Deployment Slots

Deployment slots are live environments within a single App Service app. They allow you to deploy and test changes in a staging environment before swapping to production — enabling zero-downtime deployments.

### 4.1 How Slots Work

- Each slot is a fully functional app with its own hostname (e.g., `myapp-staging.azurewebsites.net`)
- Slots share the same App Service Plan (same compute resources)
- A **swap** exchanges the content and configuration between two slots
- During a swap, App Service warms up the target slot before routing traffic — eliminating cold starts

**Available from Standard tier and above:**
- Standard: up to 5 slots
- Premium: up to 20 slots
- Isolated: up to 20 slots

### 4.2 Slot-Specific Settings

Some settings should NOT be swapped (they are environment-specific). Mark them as **slot settings** (sticky settings):

```bash
# Create a staging slot
az webapp deployment slot create \
  --name myWebApp \
  --resource-group myResourceGroup \
  --slot staging

# Set a slot-specific setting (won't swap with production)
az webapp config appsettings set \
  --name myWebApp \
  --resource-group myResourceGroup \
  --slot staging \
  --slot-settings \
    ASPNETCORE_ENVIRONMENT=Staging \
    ApplicationInsights__InstrumentationKey=staging-key-here

# Settings that SHOULD swap (not slot-specific):
# - Application code
# - Connection strings to the same database
# - Feature flags
```

**Settings that should be slot-specific (sticky):**
- Environment name (`ASPNETCORE_ENVIRONMENT`)
- Application Insights keys (so staging telemetry goes to a separate resource)
- Slot-specific feature flags
- External service endpoints that differ per environment

**Settings that should swap with the slot:**
- Database connection strings (if using the same DB per environment)
- API keys for third-party services
- Application configuration values

### 4.3 Performing a Slot Swap

```bash
# Swap staging to production (with preview)
az webapp deployment slot swap \
  --name myWebApp \
  --resource-group myResourceGroup \
  --slot staging \
  --target-slot production

# Auto-swap: automatically swap when code is deployed to staging
az webapp deployment slot auto-swap \
  --name myWebApp \
  --resource-group myResourceGroup \
  --slot staging \
  --auto-swap-slot production
```

### 4.4 Traffic Routing (Canary Deployments)

Route a percentage of production traffic to a slot for canary testing:

```bash
# Route 10% of traffic to staging slot
az webapp traffic-routing set \
  --name myWebApp \
  --resource-group myResourceGroup \
  --distribution staging=10

# Remove traffic routing (100% to production)
az webapp traffic-routing clear \
  --name myWebApp \
  --resource-group myResourceGroup
```

### 4.5 Terraform: Deployment Slots

```hcl
# Production slot (the main app)
resource "azurerm_linux_web_app" "main" {
  name                = "app-myapp-prod"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.main.id

  site_config {
    application_stack {
      dotnet_version = "8.0"
    }
  }

  app_settings = {
    "ASPNETCORE_ENVIRONMENT" = "Production"
  }
}

# Staging deployment slot
resource "azurerm_linux_web_app_slot" "staging" {
  name           = "staging"
  app_service_id = azurerm_linux_web_app.main.id

  site_config {
    application_stack {
      dotnet_version = "8.0"
    }
  }

  app_settings = {
    # This setting is slot-specific — it stays with the staging slot after swap
    "ASPNETCORE_ENVIRONMENT" = "Staging"
  }
}
```

### 4.6 Swap Mechanics Deep Dive

When you initiate a swap, App Service performs these steps:

1. **Apply slot-specific settings** from the target slot to the source slot's workers
2. **Warm up the source slot** by sending HTTP requests to the app's root path
3. **Wait for all instances** to complete warm-up (respects `applicationInitialization` config)
4. **Complete the swap** by routing traffic to the warmed-up instances
5. **Move the previous production** content to the staging slot

```xml
<!-- web.config: Configure initialization paths for warm-up -->
<system.webServer>
  <applicationInitialization>
    <add initializationPage="/health" hostName="myapp.azurewebsites.net" />
    <add initializationPage="/api/warmup" hostName="myapp.azurewebsites.net" />
  </applicationInitialization>
</system.webServer>
```

---

## 5. Auto-Scaling

Auto-scaling allows App Service to automatically adjust the number of instances based on demand. This is available on Standard tier and above.

### 5.1 Scale-Out vs. Scale-Up

| Approach | Description | When to Use |
|----------|-------------|-------------|
| Scale-out (horizontal) | Add more instances of the same size | Handle increased concurrent requests |
| Scale-in | Remove instances when demand drops | Reduce cost during low traffic |
| Scale-up (vertical) | Move to a larger instance size | Need more CPU/RAM per request |
| Scale-down | Move to a smaller instance size | Reduce cost when over-provisioned |

**Best practice**: Prefer scale-out over scale-up. Horizontal scaling is more resilient (no single point of failure) and more cost-effective.

### 5.2 Metric-Based Auto-Scaling

Configure rules that trigger scaling based on metrics like CPU percentage, memory, HTTP queue length, or custom metrics from Application Insights.

```bash
# Enable auto-scaling on an App Service Plan
az monitor autoscale create \
  --resource-group myResourceGroup \
  --resource myAppServicePlan \
  --resource-type Microsoft.Web/serverfarms \
  --name autoscale-myapp \
  --min-count 2 \
  --max-count 10 \
  --count 2

# Add scale-out rule: scale out when CPU > 70% for 5 minutes
az monitor autoscale rule create \
  --resource-group myResourceGroup \
  --autoscale-name autoscale-myapp \
  --condition "Percentage CPU > 70 avg 5m" \
  --scale out 2

# Add scale-in rule: scale in when CPU < 30% for 10 minutes
az monitor autoscale rule create \
  --resource-group myResourceGroup \
  --autoscale-name autoscale-myapp \
  --condition "Percentage CPU < 30 avg 10m" \
  --scale in 1
```

**Important**: Always pair scale-out rules with scale-in rules. Without scale-in rules, your instance count will only grow.

### 5.3 Schedule-Based Auto-Scaling

Pre-scale for known traffic patterns (business hours, marketing campaigns, seasonal events):

```bash
# Add a scheduled profile: scale to 5 instances during business hours
az monitor autoscale profile create \
  --resource-group myResourceGroup \
  --autoscale-name autoscale-myapp \
  --name "BusinessHours" \
  --timezone "Eastern Standard Time" \
  --recurrence week mon tue wed thu fri \
  --start 08:00 \
  --end 18:00 \
  --min-count 5 \
  --max-count 20 \
  --count 5
```

### 5.4 Terraform: Auto-Scaling Configuration

```hcl
resource "azurerm_monitor_autoscale_setting" "main" {
  name                = "autoscale-myapp-prod"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  target_resource_id  = azurerm_service_plan.main.id
  enabled             = true

  profile {
    name = "default"

    capacity {
      default = 2
      minimum = 2
      maximum = 10
    }

    # Scale-out rule: CPU > 70% for 5 minutes → add 2 instances
    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.main.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 70
      }
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "2"
        cooldown  = "PT5M"  # Wait 5 min before next scale action
      }
    }

    # Scale-in rule: CPU < 30% for 10 minutes → remove 1 instance
    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.main.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT10M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 30
      }
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT10M"
      }
    }
  }

  # Scheduled profile: pre-scale for Black Friday
  profile {
    name = "BlackFriday"

    capacity {
      default = 20
      minimum = 20
      maximum = 50
    }

    recurrence {
      timezone = "Eastern Standard Time"
      days     = ["Friday"]
      hours    = [0]
      minutes  = [0]
    }
  }

  notification {
    email {
      send_to_subscription_administrator    = true
      send_to_subscription_co_administrator = false
      custom_emails                         = ["platform-team@company.com"]
    }
  }
}
```

### 5.5 Auto-Scaling Best Practices

1. **Set a minimum of 2 instances** for production workloads — single instance means no HA.
2. **Use cooldown periods** to prevent scale thrashing (rapid scale-out/in cycles).
3. **Monitor HTTP queue length** in addition to CPU — a backed-up queue indicates the app can't keep up.
4. **Test your scaling rules** by generating load with tools like Azure Load Testing or k6.
5. **Set scale-in conservatively** — scale in slowly (remove 1 at a time) but scale out aggressively (add 2-3 at a time).
6. **Use Application Insights custom metrics** for business-level scaling (e.g., scale based on orders per minute).
7. **Pre-scale before known events** using scheduled profiles rather than reacting to load.

---

## 6. Best Practices Summary

### Security
- Always use Managed Identity instead of connection strings with passwords
- Store all secrets in Key Vault; reference them via Key Vault references in app settings
- Enable HTTPS-only and set minimum TLS version to 1.2
- Use VNet integration to restrict outbound traffic to private resources
- Enable Defender for App Service for threat detection

### Reliability
- Run at least 2 instances in production (never single-instance)
- Use deployment slots for zero-downtime deployments
- Configure health check endpoints (`/health`) so App Service can detect unhealthy instances
- Enable Application Insights for distributed tracing and availability monitoring

### Cost Optimization
- Use Reserved Instances (1-year or 3-year) for predictable workloads — up to 55% savings
- Scale in aggressively during off-hours using scheduled profiles
- Use Consumption plan for Azure Functions with sporadic traffic
- Right-size your App Service Plan — monitor CPU/memory utilization and downsize if consistently below 30%
- Consider Premium v3 over Premium v2 — better price/performance ratio

### Performance
- Enable `Always On` to prevent cold starts (Basic tier and above)
- Use `WEBSITE_RUN_FROM_PACKAGE=1` to run apps directly from zip packages — faster startup
- Enable HTTP/2 for improved multiplexing
- Use Azure CDN or Front Door in front of App Service for static asset caching
- Configure ARR affinity only when needed (session affinity) — disable it for stateless apps to improve load distribution

---

## 7. Common Anti-Patterns

| Anti-Pattern | Problem | Solution |
|-------------|---------|----------|
| Hardcoded connection strings | Security risk, no rotation | Use Key Vault references |
| Single instance in production | No HA, single point of failure | Minimum 2 instances |
| No deployment slots | Downtime during deployments | Use staging slot + swap |
| Auto-scale without scale-in rules | Runaway costs | Always pair scale-out with scale-in |
| Storing state in app instance | Breaks with multiple instances | Use Redis Cache or SQL for session state |
| Ignoring cold starts | Poor user experience | Enable Always On or use Premium plan |
| No health check endpoint | App Service can't detect failures | Implement `/health` endpoint |
| ARR affinity enabled for stateless apps | Uneven load distribution | Disable ARR affinity |
