# Module 3: Auth + API Management — Problem Statements

## Scenario A: Zero-Trust API Gateway

### Business Context
An enterprise needs an API gateway that validates JWT tokens from Azure AD, enforces rate limits per subscription key, transforms request/response payloads, and provides a developer portal for partner onboarding. Currently, backend APIs are directly exposed to the internet with no authentication.

### Technical Requirements
1. APIM Standard tier in front of 3 backend APIs (Orders, Inventory, Shipping)
2. JWT validation policy — reject requests without valid Azure AD tokens
3. Rate limiting: 100 calls/minute per subscription, 1000 calls/minute global
4. Response caching for GET /products (5-minute TTL)
5. Request transformation: strip internal headers before forwarding to backend
6. Developer portal with 3 products: Free (100 calls/day), Standard (10K/day), Enterprise (unlimited)
7. Application Insights integration for end-to-end request tracing
8. Named values referencing Key Vault for backend API keys

### Constraints
- Backend APIs must not be directly accessible — only through APIM
- No hardcoded secrets in APIM policies
- Developer portal must be publicly accessible for partner self-service
- Monthly cost under $500

### Success Criteria
1. Unauthenticated requests return 401
2. Rate limit exceeded returns 429 with Retry-After header
3. Cached responses served within 10ms (vs. 200ms+ for backend calls)
4. Developer portal accessible and subscription self-service working
5. End-to-end traces visible in Application Insights

---

## Scenario B: Secrets-Free Application

### Business Context
A DevOps team needs to eliminate all hardcoded credentials from their application. Currently, database passwords, API keys, and storage connection strings are stored as plaintext in app settings and Azure DevOps pipeline variables.

### Technical Requirements
1. Azure Key Vault with RBAC authorization
2. System-assigned Managed Identity on all Azure resources (App Service, Functions, AKS pods)
3. Key Vault references in App Service app settings
4. Azure SQL connection using `Authentication=Active Directory Managed Identity`
5. Storage Account access using Managed Identity (no connection strings)
6. Pipeline uses federated identity (OIDC) — no stored service principal secrets
7. Key Vault audit logging to detect unauthorized access attempts
8. Secret rotation: automated rotation for storage account keys

### Constraints
- Zero plaintext credentials anywhere (app settings, pipeline variables, code, config files)
- Secret rotation must not cause application downtime
- Audit trail for all Key Vault access

### Success Criteria
1. `az webapp config appsettings list` shows no plaintext passwords
2. Application connects to SQL using Managed Identity (verified in SQL audit logs)
3. Pipeline runs successfully using OIDC federated identity
4. Key Vault audit logs show all secret access events
5. Secret rotation completes without application errors
