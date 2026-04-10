# Module 5: CI/CD Pipelines — Theory

## 1. Azure Pipelines YAML

### 1.1 Pipeline Structure
```yaml
trigger:
  branches:
    include: [main, release/*]
  paths:
    exclude: [docs/**, '*.md']

pr:
  branches:
    include: [main]

variables:
  buildConfiguration: Release
  dotnetVersion: '8.0.x'

stages:
  - stage: Build
    jobs:
      - job: BuildAndTest
        pool:
          vmImage: ubuntu-latest
        steps:
          - task: UseDotNet@2
            inputs:
              version: $(dotnetVersion)
          - script: dotnet build --configuration $(buildConfiguration)
          - script: dotnet test --configuration $(buildConfiguration) --collect:"XPlat Code Coverage"
          - task: PublishCodeCoverageResults@1
            inputs:
              codeCoverageTool: Cobertura
              summaryFileLocation: '**/coverage.cobertura.xml'

  - stage: Deploy_Dev
    dependsOn: Build
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
    jobs:
      - deployment: DeployToDev
        environment: dev
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureWebApp@1
                  inputs:
                    azureSubscription: 'MyServiceConnection'
                    appName: 'myapp-dev'

  - stage: Deploy_Prod
    dependsOn: Deploy_Dev
    jobs:
      - deployment: DeployToProd
        environment: production  # Has approval gate configured
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureWebApp@1
                  inputs:
                    azureSubscription: 'MyServiceConnection'
                    appName: 'myapp-prod'
```

### 1.2 Templates (Reusable Pipeline Components)
```yaml
# templates/build-steps.yml
parameters:
  - name: buildConfiguration
    type: string
    default: Release

steps:
  - task: UseDotNet@2
    inputs:
      version: '8.0.x'
  - script: dotnet build --configuration ${{ parameters.buildConfiguration }}
  - script: dotnet test --configuration ${{ parameters.buildConfiguration }}

# Main pipeline using template
stages:
  - stage: Build
    jobs:
      - job: Build
        steps:
          - template: templates/build-steps.yml
            parameters:
              buildConfiguration: Release
```

### 1.3 Variable Groups and Secrets
```yaml
# Reference a variable group (linked to Key Vault)
variables:
  - group: myapp-prod-secrets  # Contains Key Vault-linked secrets
  - name: buildConfiguration
    value: Release

# Use secret in pipeline (masked in logs)
steps:
  - script: echo "Deploying with connection: $(SqlConnectionString)"
    # SqlConnectionString comes from variable group, masked in output
```

---

## 2. GitHub Actions

### 2.1 Workflow Syntax
```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  AZURE_WEBAPP_NAME: myapp-prod
  DOTNET_VERSION: '8.0.x'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with:
          dotnet-version: ${{ env.DOTNET_VERSION }}
      - run: dotnet build --configuration Release
      - run: dotnet test --configuration Release
      - uses: actions/upload-artifact@v4
        with:
          name: webapp
          path: ./publish

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment: production  # Requires approval
    permissions:
      id-token: write  # Required for OIDC
      contents: read
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: webapp
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

### 2.2 OIDC Authentication (No Stored Secrets)
```bash
# Configure federated identity on service principal
az ad app federated-credential create \
  --id <app-id> \
  --parameters '{
    "name": "github-actions-prod",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:myorg/myrepo:environment:production",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

---

## 3. Quality Gates

### 3.1 Test Result Publishing
```yaml
- task: PublishTestResults@2
  inputs:
    testResultsFormat: JUnit
    testResultsFiles: '**/test-results.xml'
    failTaskOnFailedTests: true

- task: PublishCodeCoverageResults@1
  inputs:
    codeCoverageTool: Cobertura
    summaryFileLocation: '**/coverage.cobertura.xml'
    failIfCoverageEmpty: true
```

### 3.2 Security Scanning in Pipeline
```yaml
# SAST with SonarCloud
- task: SonarCloudPrepare@1
  inputs:
    SonarCloud: 'SonarCloud'
    organization: 'myorg'
    scannerMode: 'MSBuild'
    projectKey: 'myproject'

- script: dotnet build

- task: SonarCloudAnalyze@1
- task: SonarCloudPublish@1
  inputs:
    pollingTimeoutSec: '300'

# Container scanning with Trivy
- script: |
    docker build -t myapp:$(Build.BuildId) .
    trivy image --exit-code 1 --severity HIGH,CRITICAL myapp:$(Build.BuildId)
```

---

## 4. Environments and Approvals

In Azure DevOps, configure approval gates on environments:
1. Go to Pipelines → Environments → production
2. Add approval: require approval from "QA Lead" group before deployment
3. Add check: invoke Azure Function to validate deployment window (business hours only)
4. Add check: query Azure Monitor — fail if error rate > 1% in last 15 minutes

---

## 5. Best Practices

- Keep pipelines fast: target < 10 minutes for CI, < 30 minutes for full CD
- Fail fast: run fastest tests first (unit → integration → e2e)
- Never store secrets in pipeline YAML — use variable groups linked to Key Vault
- Use pipeline templates for DRY (Don't Repeat Yourself) across multiple pipelines
- Pin action/task versions to avoid supply chain attacks (`actions/checkout@v4.1.1` not `@v4`)
- Use OIDC for Azure authentication — no stored service principal secrets
- Artifact immutability: build once, deploy the same artifact to all environments
