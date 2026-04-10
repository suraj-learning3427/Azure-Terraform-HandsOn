# Module 3: Auth + API Management — Interview Preparation

## Q1 (Conceptual): Managed Identity vs Service Principal
**Question**: What is the difference between a Managed Identity and a Service Principal? When would you use each?

**Sample Answer**: A Service Principal is an identity for an application in Azure AD — you manage its credentials (secrets or certificates) and are responsible for rotation. A Managed Identity is a special type of service principal whose credentials are automatically managed by Azure — you never see or rotate the credentials.

Use Managed Identity whenever the resource supports it (App Service, Functions, AKS, VMs, etc.) — it's always the better choice because there are no credentials to leak or rotate. Use a Service Principal when: the resource doesn't support Managed Identity (e.g., on-premises application, GitHub Actions with OIDC), or when you need an identity that spans multiple subscriptions.

**Follow-ups**: What's the difference between system-assigned and user-assigned Managed Identity?

---

## Q2 (Scenario): APIM Policy Debugging
**Question**: An API call through APIM is returning 401 even though the client has a valid Azure AD token. How do you debug this?

**Sample Answer**:
1. Enable APIM tracing: add `Ocp-Apim-Trace: true` and `Ocp-Apim-Subscription-Key` headers to the request
2. Check the trace in APIM → APIs → Test → Trace tab — it shows exactly which policy failed
3. Common causes: wrong audience claim (the token's `aud` must match the API's App ID URI), expired token, wrong tenant ID in the `validate-jwt` policy's `openid-config` URL
4. Verify the token claims using jwt.ms — paste the Bearer token and check `aud`, `iss`, `exp`
5. Check if the `validate-jwt` policy is in the correct scope (API-level vs. operation-level)

**Follow-ups**: How would you allow some API operations to be unauthenticated while others require JWT validation?

---

## Q3 (Design): Key Vault Architecture for Multi-Environment Setup
**Question**: Design a Key Vault architecture for an application with dev, staging, and production environments.

**Sample Answer**:
One Key Vault per environment — never share Key Vaults across environments. This provides:
- Blast radius isolation: a compromised dev Key Vault doesn't affect production
- Independent access control: dev team has access to dev KV, only CI/CD pipeline accesses prod KV
- Separate audit trails per environment

Architecture:
- `kv-myapp-dev`: dev team has Key Vault Secrets Officer role; dev App Service has Secrets User role
- `kv-myapp-staging`: CI/CD pipeline service principal has Secrets Officer; staging App Service has Secrets User
- `kv-myapp-prod`: only CI/CD pipeline (via OIDC federated identity) can write secrets; prod App Service has Secrets User; no human has direct access

Enable purge protection and soft delete on all vaults. Enable private endpoints on staging and production. Enable diagnostic logging to Log Analytics.

**Follow-ups**: How would you handle secret rotation across environments? How do you prevent accidental deletion of production secrets?

---

## Q4 (Troubleshooting): APIM Rate Limiting Not Working
**Question**: You've configured a rate-limit policy of 100 calls/minute but clients are making 500 calls/minute without being throttled. What's wrong?

**Sample Answer**:
Most likely the rate-limit policy is in the wrong scope or the subscription key isn't being sent. Check:
1. Policy scope: is the `rate-limit` policy in the `<inbound>` section? Is it at the API level or product level?
2. `rate-limit` vs `rate-limit-by-key`: `rate-limit` applies per subscription key. If clients aren't sending a subscription key, the policy may not apply. Use `rate-limit-by-key` with `counter-key="@(context.Request.IpAddress)"` to rate limit by IP instead.
3. Check if `subscription-required` is set to `false` on the API — if no subscription is required, `rate-limit` won't work as expected.
4. Check APIM logs in Application Insights for 429 responses — are they being generated but not reaching the client?

**Follow-ups**: What's the difference between `rate-limit` and `quota` policies in APIM?
