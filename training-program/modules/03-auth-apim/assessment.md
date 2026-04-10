# Module 3: Auth + API Management — Assessment

## Knowledge Checks

**Q1**: What OAuth 2.0 flow should a background service use to call another API?
**Answer**: Client Credentials flow — no user involved, service authenticates with its own identity (client_id + client_secret or certificate).

**Q2**: What is the difference between `rate-limit` and `quota` in APIM?
**Answer**: `rate-limit` enforces a short-term rate (e.g., 100 calls/minute) and resets every renewal period. `quota` enforces a longer-term limit (e.g., 10,000 calls/month) that doesn't reset until the quota period ends. Use both together: rate-limit for burst protection, quota for billing/tier enforcement.

**Q3**: How do you reference a Key Vault secret in an APIM named value?
**Answer**: In APIM Named Values, set the type to "Key Vault" and provide the Key Vault secret URI. APIM uses its system-assigned Managed Identity to fetch the secret. The APIM identity must have `Key Vault Secrets User` role on the vault.

**Q4**: What is the On-Behalf-Of (OBO) flow used for?
**Answer**: OBO is used when API A needs to call API B on behalf of the user who called API A. API A exchanges its access token for a new token scoped to API B, preserving the user's identity in the downstream call. Common in microservices architectures where multiple APIs need to act on behalf of the same user.

---

## Practical Task: Implement JWT Validation in APIM

Deploy an APIM instance with a JWT validation policy that:
1. Validates tokens from your Azure AD tenant
2. Requires the `api://my-api` audience claim
3. Returns 401 for missing/invalid tokens
4. Allows unauthenticated access to `GET /health`

**Validation**:
```bash
# 1. Get a valid token
TOKEN=$(az account get-access-token --resource api://my-api --query accessToken -o tsv)

# 2. Call API with valid token - should return 200
curl -H "Authorization: Bearer $TOKEN" https://myapim.azure-api.net/myapi/data

# 3. Call without token - should return 401
curl https://myapim.azure-api.net/myapi/data

# 4. Call health endpoint without token - should return 200
curl https://myapim.azure-api.net/myapi/health
```

---

## Rubric

### Criterion 1: Identity and Access Design
| Level | Description |
|-------|-------------|
| Exemplary (4) | Uses Managed Identity for all Azure resource authentication. Correctly implements RBAC on Key Vault. Uses federated identity (OIDC) for CI/CD pipelines. Zero plaintext credentials anywhere. |
| Proficient (3) | Uses Managed Identity for most resources. RBAC on Key Vault configured. Minor gaps (e.g., one service still using connection string). |
| Developing (2) | Aware of Managed Identity but uses service principal secrets for some resources. Key Vault configured but using access policies instead of RBAC. |
| Beginning (1) | Uses plaintext credentials in app settings or code. Cannot explain Managed Identity. |

### Criterion 2: APIM Policy Implementation
| Level | Description |
|-------|-------------|
| Exemplary (4) | Implements JWT validation, rate limiting, caching, and request transformation. Uses named values for secrets. Configures correct policy scopes. Integrates Application Insights. |
| Proficient (3) | Implements JWT validation and rate limiting correctly. Minor gaps in caching or transformation policies. |
| Developing (2) | Implements basic JWT validation but incorrect scope or missing claims validation. Rate limiting configured but not working correctly. |
| Beginning (1) | Cannot implement JWT validation policy. Does not understand policy pipeline order. |
