# Module 1: Azure App Service — Problem Statements

---

## Scenario A: E-commerce Platform Migration

### Business Context

RetailCo is a mid-sized online retailer with $50M annual revenue. Their flagship .NET 6 web application currently runs on-premises on two Windows Server 2019 VMs behind a hardware load balancer. The application handles product browsing, cart management, and checkout for approximately 50,000 daily active users.

The business faces two critical challenges:

1. **Seasonal traffic spikes**: Black Friday and Cyber Monday generate 10x normal traffic (500,000 concurrent users). Last year, the site went down for 4 hours on Black Friday due to infrastructure overload, costing an estimated $800,000 in lost revenue.

2. **Deployment risk**: The current deployment process requires a 2-hour maintenance window every two weeks. The business wants to release features weekly with zero downtime.

The CTO has approved a migration to Azure App Service with a 90-day timeline. The platform team must design and implement the solution while the development team continues shipping features.

### Technical Requirements

1. Migrate the existing .NET 6 web application to Azure App Service with no code changes required
2. Implement zero-downtime deployments using deployment slots (staging → production swap)
3. Configure auto-scaling to handle 10x traffic spikes automatically (baseline: 2 instances, peak: 20 instances)
4. Establish a staging environment for QA validation before every production release
5. Migrate all database connection strings and API keys to Azure Key Vault
6. Implement Application Insights for real-time performance monitoring and alerting
7. Configure custom domain (`www.retailco.com`) with SSL/TLS certificate
8. Ensure the application can connect to the existing Azure SQL Database via private endpoint
9. Implement health check endpoints so App Service can detect and replace unhealthy instances
10. Set up Azure DevOps CI/CD pipeline that deploys to staging slot and requires manual approval before production swap

### Constraints

- Zero downtime during migration — the site must remain available throughout
- The .NET 6 application cannot be rewritten; only configuration changes are permitted
- Production database must remain in the existing Azure SQL instance (no migration)
- Total Azure spend for App Service infrastructure must not exceed $3,000/month at baseline
- The staging environment must be isolated from production data (separate Application Insights resource)
- All secrets must be stored in Key Vault — no plaintext credentials in app settings or pipeline variables
- Deployment to production requires approval from at least one member of the QA team
- The solution must achieve 99.95% SLA

### Success Criteria

1. Application is live on Azure App Service with zero downtime during cutover
2. Deployment pipeline successfully deploys to staging slot and swaps to production in under 10 minutes
3. Auto-scaling triggers within 3 minutes of CPU exceeding 70% and scales to handle 10x load
4. All secrets are stored in Key Vault with no plaintext credentials anywhere in the system
5. Application Insights shows end-to-end request tracing with < 500ms p95 response time at baseline load
6. Health check endpoint returns 200 within 5 seconds; unhealthy instances are replaced automatically
7. Staging environment is accessible at `staging.retailco.com` with Basic Auth protection
8. Black Friday load test (500,000 simulated users) completes with < 1% error rate
9. Monthly Azure cost at baseline load is within the $3,000 budget
10. Rollback to previous version can be completed in under 2 minutes by swapping slots back

### Azure Services

#### Azure App Service (Premium v3 P2v3)
- **Service Tier**: Premium v3 P2v3 (2 vCPU, 8 GB RAM per instance)
- **Scaling Requirements**:
  - Minimum instances: 2 (for HA)
  - Maximum instances: 20 (for Black Friday peak)
  - Scale-out trigger: CPU > 70% for 5 minutes → add 2 instances
  - Scale-in trigger: CPU < 30% for 10 minutes → remove 1 instance
  - Scheduled pre-scale: November 25–30 → minimum 10 instances
- **Cost Considerations**:
  - P2v3 Linux: ~$146/month per instance
  - Baseline (2 instances): ~$292/month
  - Peak (20 instances): ~$2,920/month
  - Reserved Instance (1-year): ~$95/month per instance → 35% savings at baseline
  - Deployment slots: included in plan cost (no additional charge)

#### Azure Key Vault (Standard)
- **Service Tier**: Standard
- **Scaling Requirements**: No scaling needed; Key Vault handles up to 2,000 transactions/10 seconds
- **Cost Considerations**: ~$0.03 per 10,000 operations; negligible for this workload (~$5/month)

#### Application Insights
- **Service Tier**: Pay-as-you-go (first 5 GB/month free)
- **Scaling Requirements**: Sampling at 10% for high-traffic periods to control ingestion costs
- **Cost Considerations**: ~$2.30/GB after free tier; estimated $50–100/month at production scale

#### Azure DevOps (Basic + Pipelines)
- **Service Tier**: Basic plan with Microsoft-hosted agents
- **Scaling Requirements**: Parallel jobs for simultaneous staging and production pipelines
- **Cost Considerations**: First 5 users free; Microsoft-hosted agents: $40/month per parallel job

---

### Implementation Guide

#### Step 1: Create the App Service Plan and Web App

```bash
# Variables
RG="rg-retailco-prod"
LOCATION="eastus2"
PLAN="asp-retailco-prod"
APP="app-retailco-prod"
KV="kv-retailco-prod"

# Create resource group
az group create --name $RG --location $LOCATION

# Create Premium v3 App Service Plan
az appservice plan create \
  --name $PLAN \
  --resource-group $RG \
  --sku P2v3 \
  --is-linux \
  --location $LOCATION

# Create Web App with .NET 8 runtime
az webapp create \
  --name $APP \
  --resource-group $RG \
  --plan $PLAN \
  --runtime "DOTNETCORE:8.0"

# Enable system-assigned managed identity
az webapp identity assign \
  --name $APP \
  --resource-group $RG
```

#### Step 2: Create Staging Slot

```bash
# Create staging deployment slot
az webapp deployment slot create \
  --name $APP \
  --resource-group $RG \
  --slot staging \
  --configuration-source $APP

# Configure slot-specific settings (these stay with the slot, not the app)
az webapp config appsettings set \
  --name $APP \
  --resource-group $RG \
  --slot staging \
  --slot-settings \
    ASPNETCORE_ENVIRONMENT=Staging \
    APPLICATIONINSIGHTS_CONNECTION_STRING="InstrumentationKey=staging-key"
```

#### Step 3: Configure Key Vault and Managed Identity

```bash
# Create Key Vault
az keyvault create \
  --name $KV \
  --resource-group $RG \
  --location $LOCATION \
  --sku standard

# Get the Web App's managed identity principal ID
PRINCIPAL_ID=$(az webapp identity show \
  --name $APP \
  --resource-group $RG \
  --query principalId -o tsv)

# Grant the Web App's identity access to Key Vault secrets
az role assignment create \
  --role "Key Vault Secrets User" \
  --assignee $PRINCIPAL_ID \
  --scope $(az keyvault show --name $KV --query id -o tsv)

# Store the SQL connection string in Key Vault
az keyvault secret set \
  --vault-name $KV \
  --name "SqlConnectionString" \
  --value "Server=tcp:myserver.database.windows.net,1433;Database=RetailDB;Authentication=Active Directory Managed Identity;"

# Reference Key Vault secret in app settings
az webapp config appsettings set \
  --name $APP \
  --resource-group $RG \
  --settings \
    "ConnectionStrings__DefaultConnection=@Microsoft.KeyVault(VaultName=${KV};SecretName=SqlConnectionString)"
```

#### Step 4: Configure Auto-Scaling

```bash
# Enable auto-scaling
az monitor autoscale create \
  --resource-group $RG \
  --resource $PLAN \
  --resource-type Microsoft.Web/serverfarms \
  --name "autoscale-retailco" \
  --min-count 2 \
  --max-count 20 \
  --count 2

# Scale-out rule
az monitor autoscale rule create \
  --resource-group $RG \
  --autoscale-name "autoscale-retailco" \
  --condition "Percentage CPU > 70 avg 5m" \
  --scale out 2

# Scale-in rule
az monitor autoscale rule create \
  --resource-group $RG \
  --autoscale-name "autoscale-retailco" \
  --condition "Percentage CPU < 30 avg 10m" \
  --scale in 1
```

#### Step 5: CI/CD Pipeline (Azure DevOps YAML)

```yaml
# azure-pipelines.yml
trigger:
  branches:
    include:
      - main

stages:
  - stage: Build
    jobs:
      - job: BuildAndTest
        pool:
          vmImage: ubuntu-latest
        steps:
          - task: DotNetCoreCLI@2
            displayName: Restore dependencies
            inputs:
              command: restore
              projects: '**/*.csproj'

          - task: DotNetCoreCLI@2
            displayName: Build
            inputs:
              command: build
              arguments: '--configuration Release'

          - task: DotNetCoreCLI@2
            displayName: Run unit tests
            inputs:
              command: test
              arguments: '--configuration Release --collect:"XPlat Code Coverage"'

          - task: DotNetCoreCLI@2
            displayName: Publish
            inputs:
              command: publish
              publishWebProjects: true
              arguments: '--configuration Release --output $(Build.ArtifactStagingDirectory)'

          - publish: $(Build.ArtifactStagingDirectory)
            artifact: webapp

  - stage: DeployStaging
    dependsOn: Build
    jobs:
      - deployment: DeployToStaging
        environment: staging
        pool:
          vmImage: ubuntu-latest
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureWebApp@1
                  displayName: Deploy to staging slot
                  inputs:
                    azureSubscription: 'RetailCo-Azure-ServiceConnection'
                    appType: webAppLinux
                    appName: app-retailco-prod
                    deployToSlotOrASE: true
                    resourceGroupName: rg-retailco-prod
                    slotName: staging
                    package: $(Pipeline.Workspace)/webapp/**/*.zip

  - stage: SwapToProduction
    dependsOn: DeployStaging
    jobs:
      - deployment: SwapSlots
        environment: production  # Requires manual approval gate
        pool:
          vmImage: ubuntu-latest
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureAppServiceManage@0
                  displayName: Swap staging to production
                  inputs:
                    azureSubscription: 'RetailCo-Azure-ServiceConnection'
                    Action: 'Swap Slots'
                    WebAppName: app-retailco-prod
                    ResourceGroupName: rg-retailco-prod
                    SourceSlot: staging
```

---

## Scenario B: Serverless Order Processing

### Business Context

LogiCo is a third-party logistics company processing 2 million order events per day for 50 e-commerce clients. Their current order processing system is a monolithic .NET application running on a dedicated VM. The system has several pain points:

1. **Reliability**: The VM crashes approximately twice per month, causing order processing delays of 30–90 minutes. Each incident costs $15,000–$50,000 in SLA penalties.
2. **Scalability**: During peak periods (evenings, weekends), the queue backs up and orders take 45+ minutes to process instead of the target 5 minutes.
3. **Observability**: When orders fail, the team has no visibility into why — they only discover failures when clients complain.
4. **Cost**: The dedicated VM runs 24/7 at $800/month even though 60% of processing happens in a 6-hour window.

The engineering team wants to migrate to Azure Functions with Service Bus for reliable, scalable, observable order processing.

### Technical Requirements

1. Implement an Azure Function triggered by Azure Service Bus queue messages to process order events
2. Configure retry logic with exponential backoff (max 5 retries, 2-second initial delay, 15-minute max delay)
3. Implement dead-letter queue (DLQ) handling — failed orders after max retries must be routed to a DLQ and trigger an alert
4. Create a separate Azure Function to process DLQ messages and notify the operations team via email
5. Implement idempotency — processing the same order twice must not create duplicate records
6. Deploy on Premium plan to eliminate cold starts and support VNet integration
7. Connect to Azure SQL Database via private endpoint using Managed Identity (no passwords)
8. Create an Application Insights dashboard showing: orders processed per minute, processing latency p50/p95/p99, error rate, DLQ depth
9. Configure alerts: error rate > 1% for 5 minutes → PagerDuty notification; DLQ depth > 100 → email alert
10. Implement structured logging with correlation IDs so every log entry for an order can be traced end-to-end

### Constraints

- Maximum order processing latency: 5 minutes from queue arrival to database write (p95)
- Zero message loss — every order must be processed exactly once or land in the DLQ
- The solution must handle 10x traffic spikes (up to 20,000 orders/minute) without manual intervention
- All credentials must use Managed Identity — no connection strings with passwords
- Monthly cost must not exceed $2,000 at baseline (2M orders/day)
- The DLQ processor must send alerts within 2 minutes of a message landing in the DLQ
- Compliance: order data must remain in the East US 2 region (data residency requirement)
- The Function App must be deployed in a VNet to access the private SQL endpoint

### Success Criteria

1. Orders are processed within 5 minutes of arriving in the Service Bus queue (p95) under normal load
2. Under 10x load (20,000 orders/minute), processing latency stays below 10 minutes (p95)
3. Failed orders are retried 5 times with exponential backoff before landing in the DLQ
4. DLQ messages trigger an alert within 2 minutes and are visible in the Application Insights dashboard
5. Processing the same order ID twice results in exactly one database record (idempotency verified)
6. Zero message loss demonstrated by comparing Service Bus message count to database record count over 24 hours
7. Application Insights dashboard shows real-time metrics with < 30-second delay
8. Monthly cost at 2M orders/day baseline is within the $2,000 budget
9. No plaintext credentials exist anywhere in the system (verified by Key Vault audit logs)
10. End-to-end trace for any order is retrievable in Application Insights using the order's correlation ID

### Azure Services

#### Azure Service Bus (Standard)
- **Service Tier**: Standard (supports topics, subscriptions, and dead-letter queues)
- **Scaling Requirements**:
  - Queue: `orders-processing` with 5-minute lock duration, 5 max delivery count
  - Dead-letter queue: automatically created by Service Bus
  - Message TTL: 7 days
  - Partitioning: enabled for higher throughput
- **Cost Considerations**:
  - Standard tier: $0.10 per million operations
  - At 2M orders/day: ~$6/month
  - Premium tier needed only if >80 GB message storage or >1,000 connections

#### Azure Functions (Premium EP2)
- **Service Tier**: Premium EP2 (2 vCPU, 7 GB RAM)
- **Scaling Requirements**:
  - Minimum instances: 1 (always warm)
  - Maximum instances: 20
  - Scale trigger: Service Bus queue depth > 100 messages
  - `prefetchCount`: 100 (batch processing for throughput)
- **Cost Considerations**:
  - EP2 Premium: ~$0.173/hour per instance
  - Baseline (1 instance): ~$125/month
  - Peak (20 instances): ~$2,500/month (short-duration spikes)
  - Estimated average: ~$400/month with auto-scale

#### Azure SQL Database (General Purpose, 4 vCores)
- **Service Tier**: General Purpose, 4 vCores (serverless with auto-pause disabled)
- **Scaling Requirements**: Read replicas for reporting queries; write path on primary only
- **Cost Considerations**: ~$370/month for 4 vCore General Purpose; serverless option ~$200/month if auto-pause acceptable

#### Application Insights
- **Service Tier**: Pay-as-you-go
- **Scaling Requirements**: Adaptive sampling enabled; custom metrics for business KPIs
- **Cost Considerations**: ~$50–80/month at 2M orders/day with sampling

---

### Implementation Guide

#### Azure Function: Order Processor

```csharp
// OrderProcessor.cs
[FunctionName("ProcessOrder")]
public async Task Run(
    [ServiceBusTrigger(
        queueName: "orders-processing",
        Connection = "ServiceBusConnection")]
    ServiceBusReceivedMessage message,
    ServiceBusMessageActions messageActions,
    ILogger log)
{
    var correlationId = message.CorrelationId ?? message.MessageId;
    
    using var scope = log.BeginScope(new Dictionary<string, object>
    {
        ["CorrelationId"] = correlationId,
        ["MessageId"] = message.MessageId,
        ["DeliveryCount"] = message.DeliveryCount
    });

    try
    {
        log.LogInformation("Processing order {MessageId}", message.MessageId);
        
        var order = JsonSerializer.Deserialize<OrderEvent>(message.Body);
        
        // Idempotency check: skip if already processed
        if (await _orderRepository.ExistsAsync(order.OrderId))
        {
            log.LogWarning("Order {OrderId} already processed — skipping (idempotency)", order.OrderId);
            await messageActions.CompleteMessageAsync(message);
            return;
        }
        
        // Process the order
        await _orderService.ProcessAsync(order);
        
        // Complete the message (remove from queue)
        await messageActions.CompleteMessageAsync(message);
        
        log.LogInformation("Order {OrderId} processed successfully", order.OrderId);
        _metrics.TrackEvent("OrderProcessed", new Dictionary<string, string>
        {
            ["OrderId"] = order.OrderId,
            ["ClientId"] = order.ClientId
        });
    }
    catch (TransientException ex)
    {
        // Transient errors: abandon message so Service Bus retries with backoff
        log.LogWarning(ex, "Transient error processing order {MessageId} — abandoning for retry", message.MessageId);
        await messageActions.AbandonMessageAsync(message);
    }
    catch (Exception ex)
    {
        // Permanent errors: dead-letter the message immediately
        log.LogError(ex, "Permanent error processing order {MessageId} — dead-lettering", message.MessageId);
        await messageActions.DeadLetterMessageAsync(message, 
            deadLetterReason: ex.GetType().Name,
            deadLetterErrorDescription: ex.Message);
    }
}
```

#### host.json: Retry and Concurrency Configuration

```json
{
  "version": "2.0",
  "extensions": {
    "serviceBus": {
      "prefetchCount": 100,
      "messageHandlerOptions": {
        "autoComplete": false,
        "maxConcurrentCalls": 16,
        "maxAutoRenewDuration": "00:05:00"
      }
    }
  },
  "retry": {
    "strategy": "exponentialBackoff",
    "maxRetryCount": 5,
    "minimumInterval": "00:00:02",
    "maximumInterval": "00:15:00"
  },
  "logging": {
    "applicationInsights": {
      "samplingSettings": {
        "isEnabled": true,
        "maxTelemetryItemsPerSecond": 20
      }
    }
  }
}
```

#### Terraform: Function App with VNet Integration

```hcl
# Premium Function App with VNet integration
resource "azurerm_linux_function_app" "order_processor" {
  name                = "func-orderprocessor-prod"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  storage_account_name       = azurerm_storage_account.functions.name
  storage_account_access_key = azurerm_storage_account.functions.primary_access_key
  service_plan_id            = azurerm_service_plan.premium.id

  # VNet integration for private SQL endpoint access
  virtual_network_subnet_id = azurerm_subnet.functions.id

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      dotnet_version              = "8.0"
      use_dotnet_isolated_runtime = true
    }
    application_insights_connection_string = azurerm_application_insights.main.connection_string
    
    # Ensure all outbound traffic goes through VNet
    vnet_route_all_enabled = true
  }

  app_settings = {
    "ServiceBusConnection"     = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.main.name};SecretName=ServiceBusConnectionString)"
    "FUNCTIONS_WORKER_RUNTIME" = "dotnet-isolated"
    "WEBSITE_RUN_FROM_PACKAGE" = "1"
  }
}

# Auto-scale: scale based on Service Bus queue depth
resource "azurerm_monitor_autoscale_setting" "functions" {
  name                = "autoscale-orderprocessor"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  target_resource_id  = azurerm_service_plan.premium.id

  profile {
    name = "default"
    capacity {
      default = 1
      minimum = 1
      maximum = 20
    }

    rule {
      metric_trigger {
        metric_name        = "ActiveMessageCount"
        metric_resource_id = azurerm_servicebus_queue.orders.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 100
      }
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "2"
        cooldown  = "PT3M"
      }
    }
  }
}
```

#### Application Insights Alert: DLQ Depth

```hcl
resource "azurerm_monitor_metric_alert" "dlq_depth" {
  name                = "alert-dlq-depth-high"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_servicebus_namespace.main.id]
  description         = "Dead-letter queue depth exceeded threshold"
  severity            = 1  # Critical

  criteria {
    metric_namespace = "Microsoft.ServiceBus/namespaces"
    metric_name      = "DeadletteredMessages"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 100

    dimension {
      name     = "EntityName"
      operator = "Include"
      values   = ["orders-processing"]
    }
  }

  action {
    action_group_id = azurerm_monitor_action_group.ops_team.id
  }

  frequency   = "PT1M"
  window_size = "PT2M"
}
```

---

## Discussion Questions

1. RetailCo's Black Friday traffic is 10x normal. What are the trade-offs between pre-scaling (scheduled profiles) vs. reactive auto-scaling for this scenario?

2. In Scenario A, the staging slot uses the same App Service Plan as production. What are the implications for load testing in staging? How would you address this?

3. LogiCo requires exactly-once processing. Azure Service Bus provides at-least-once delivery. How does the idempotency check in the Function implementation address this gap?

4. Compare the cost of running LogiCo's order processing on a dedicated VM ($800/month) vs. Azure Functions Premium plan. Under what conditions does each approach become more cost-effective?

5. In Scenario B, why is the Premium plan chosen over the Consumption plan? What specific requirements drive this decision?
