# Architecture Patterns

## 3-Tier Architecture (Most Common Interview Topic)

```
Tier 1 (Presentation): Application Gateway (WAF) → App Service / AKS
Tier 2 (Application):  AKS / App Service → Business logic
Tier 3 (Data):         Azure SQL + Redis (private endpoints)
```

**Key principles**:
- Each tier in its own subnet with NSG rules
- No direct internet access to tiers 2 and 3
- Private endpoints for all data services
- Managed Identities for service-to-service auth

---

## Microservices Pattern

**When to use**: Independent deployability, different scaling requirements per service, polyglot teams.

**Azure implementation**:
- Container Apps or AKS for service hosting
- APIM as API gateway
- Service Bus for async communication
- Dapr for service discovery and state management
- Each service has its own database (database-per-service pattern)

**Anti-patterns to avoid**:
- Distributed monolith (microservices that must deploy together)
- Chatty services (too many synchronous calls between services)
- Shared database (breaks independent deployability)

---

## Event-Driven Architecture

```
Producer → Event Hub / Service Bus → Consumer (Functions/Container Apps)
                                   → Dead Letter Queue (failed messages)
```

**When to use**: Decoupled systems, high throughput, async processing.

**Azure services**:
- Event Hub: high-throughput event streaming (IoT, telemetry)
- Service Bus: reliable message queuing (orders, transactions)
- Event Grid: reactive event routing (Azure resource events)

---

## Hub-Spoke Network Topology

```
Hub VNet (shared services: Firewall, Bastion, DNS)
    ├── Spoke 1 VNet (dev environment)
    ├── Spoke 2 VNet (staging environment)
    └── Spoke 3 VNet (production environment)
```

**Benefits**: Centralized security controls, shared services, cost optimization.
**Implementation**: VNet peering between hub and spokes, Azure Firewall in hub for outbound inspection.

---

## Landing Zone Pattern

A pre-configured Azure environment with governance, security, and networking already in place before workloads are deployed.

**Components**:
- Management groups hierarchy
- Azure Policy assignments (tagging, regions, security)
- Hub-spoke networking
- Log Analytics workspace
- Defender for Cloud enabled
- RBAC roles defined

**Terraform implementation**: Azure Landing Zone Terraform module (official Microsoft module).

---

## Scalability Patterns

| Pattern | Description | Azure Implementation |
|---------|-------------|---------------------|
| Horizontal scaling | Add more instances | App Service autoscale, VMSS, AKS HPA |
| Vertical scaling | Larger instance size | Change App Service SKU, VM size |
| Cache-aside | Cache frequently read data | Azure Cache for Redis |
| CQRS | Separate read/write models | SQL write + read replica |
| Sharding | Partition data across databases | Elastic pools, Cosmos DB partitioning |
| Circuit breaker | Fail fast on downstream failures | Polly library, APIM retry policy |
