# Day 6 — Apr 16 | CI/CD Deep Dive + GitHub Actions
**Presenters**: Varsha & Gowtham

---

## What You'll Learn Today
- GitHub Actions workflows, OIDC authentication, reusable workflows
- Multi-stage pipelines with matrix strategy
- Container build strategy

---

## Part 1: GitHub Actions

### Workflow Syntax
```yaml
# .github/workflows/ci-cd.yml
name: CI/CD Pipeline

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  AZURE_WEBAPP_NAME: myapp-prod
  DOTNET_VERSION: '8.0.x'
  ACR_NAME: myacrprod

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-dotnet@v4
        with:
          dotnet-version: ${{ env.DOTNET_VERSION }}

      - name: Build and test
        run: |
          dotnet build --configuration Release
          dotnet test --collect:"XPlat Code Coverage"

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: webapp
          path: ./publish

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment: production    # Requires approval
    permissions:
      id-token: write          # Required for OIDC
      contents: read
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: webapp

      # OIDC login — no stored secrets!
      - uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - uses: azure/webapps-deploy@v3
        with:
          app-name: ${{ env.AZURE_WEBAPP_NAME }}
          package: .
```

### OIDC Authentication — No Stored Secrets
```bash
# Configure federated identity on service principal
# GitHub Actions can authenticate to Azure without storing any credentials

az ad app create --display-name "github-actions-myapp"
APP_ID=$(az ad app list --display-name "github-actions-myapp" --query "[0].appId" -o tsv)
az ad sp create --id $APP_ID

# Add federated credential for the production environment
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-prod",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:myorg/myrepo:environment:production",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Grant Contributor on subscription
az role assignment create \
  --role Contributor \
  --assignee $APP_ID \
  --scope /subscriptions/$(az account show --query id -o tsv)

# Add to GitHub secrets (no secret value — just IDs):
# AZURE_CLIENT_ID = $APP_ID
# AZURE_TENANT_ID = $(az account show --query tenantId -o tsv)
# AZURE_SUBSCRIPTION_ID = $(az account show --query id -o tsv)
```

### Matrix Strategy — Test Multiple Versions in Parallel
```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        node-version: [18, 20, 22]
        os: [ubuntu-latest, windows-latest]
    steps:
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}
      - run: npm test
```

### Reusable Workflows
```yaml
# .github/workflows/reusable-build.yml
on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: echo "Building for ${{ inputs.environment }}"

# Calling the reusable workflow
jobs:
  deploy-dev:
    uses: ./.github/workflows/reusable-build.yml
    with:
      environment: dev
```

---

## Part 2: Container Build Strategy

### Multi-Stage Dockerfile (Build Once, Run Anywhere)
```dockerfile
# Stage 1: Build (includes SDK — large image)
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["MyApp.csproj", "."]
RUN dotnet restore
COPY . .
RUN dotnet publish -c Release -o /app/publish

# Stage 2: Runtime (no SDK — small image)
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app

# Security: run as non-root
RUN adduser --disabled-password appuser && chown -R appuser /app
USER appuser

COPY --from=build /app/publish .
EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080
ENTRYPOINT ["dotnet", "MyApp.dll"]
```

### Build and Push to ACR in Pipeline
```yaml
- name: Build and push to ACR
  uses: azure/docker-login@v1
  with:
    login-server: ${{ env.ACR_NAME }}.azurecr.io
    username: ${{ secrets.ACR_USERNAME }}
    password: ${{ secrets.ACR_PASSWORD }}

- run: |
    docker build -t ${{ env.ACR_NAME }}.azurecr.io/myapp:${{ github.sha }} .
    docker push ${{ env.ACR_NAME }}.azurecr.io/myapp:${{ github.sha }}
```

**Better approach — use Managed Identity (no ACR credentials)**:
```yaml
- uses: azure/login@v2
  with:
    client-id: ${{ secrets.AZURE_CLIENT_ID }}
    tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

- run: |
    az acr login --name ${{ env.ACR_NAME }}
    docker build -t ${{ env.ACR_NAME }}.azurecr.io/myapp:${{ github.sha }} .
    docker push ${{ env.ACR_NAME }}.azurecr.io/myapp:${{ github.sha }}
```

---

## Hands-On: Migrate POC 2 Pipeline to GitHub Actions

1. Create `.github/workflows/ci-cd.yml`
2. Configure OIDC federated identity (no stored secrets)
3. Add environment protection rule for production (require 1 approval)
4. Test: push to main → pipeline runs → approval required for prod

---

## Interview Q&A — Day 6 Topics

**Q: What is OIDC and why is it better than storing service principal secrets in GitHub?**
A: OIDC (OpenID Connect) allows GitHub Actions to authenticate to Azure using short-lived tokens issued by GitHub's identity provider — no credentials stored anywhere. Azure trusts GitHub's OIDC issuer and issues access tokens based on the workflow's identity (repo + branch + environment). No secrets to rotate, no risk of credential leakage from a compromised GitHub repo.

**Q: A developer committed a service principal secret to GitHub. What do you do?**
A: Immediate: 1) Rotate the secret immediately — assume it's compromised. 2) Check Azure AD sign-in logs for unauthorized use. 3) Clean git history with `git filter-repo`. 4) Force-push and notify team to re-clone. Prevention: implement OIDC (no secrets to commit), add `gitleaks` as pre-commit hook and CI check, enable GitHub Advanced Security secret scanning.

**Q: What is the benefit of multi-stage Docker builds?**
A: The final image only contains the runtime (no SDK, no build tools, no source code). This reduces image size (e.g., from 800MB to 200MB), reduces attack surface (fewer packages = fewer CVEs), and speeds up image pulls. The build stage is discarded — only the published artifacts are copied to the final stage.

**Q: How do you speed up a slow CI pipeline?**
A: 1) Cache dependencies (`actions/cache` for npm/nuget/pip). 2) Parallelize with matrix strategy. 3) Move slow integration tests to a separate nightly pipeline. 4) Use Docker layer caching for container builds. 5) Run fastest tests first (unit → integration → e2e). Target: < 10 minutes for CI.

**Q: What is the difference between `needs` and `if` in GitHub Actions?**
A: `needs` defines execution order — a job won't start until its dependencies complete. `if` defines whether a job runs at all — e.g., `if: github.ref == 'refs/heads/main'` only runs on main branch. You can combine them: depend on a previous job AND only run if it succeeded AND only on main.
