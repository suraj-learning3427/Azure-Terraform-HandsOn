# Day 5 — Apr 15 | CI/CD Pipelines + Azure Infrastructure with Terraform
**Presenters**: Suraj & Joby

---

## What You'll Learn Today
- Azure Pipelines YAML: stages, jobs, templates, quality gates, approval gates
- Terraform for VMs, VMSS, AKS, networking

---

## Part 1: Azure Pipelines YAML

### Pipeline Structure
```yaml
trigger:
  branches:
    include: [main]

variables:
  buildConfiguration: Release

stages:
  - stage: Build
    jobs:
      - job: BuildAndTest
        pool:
          vmImage: ubuntu-latest
        steps:
          - task: UseDotNet@2
            inputs:
              version: '8.0.x'
          - script: dotnet build --configuration $(buildConfiguration)
          - script: dotnet test --collect:"XPlat Code Coverage"
          - task: PublishCodeCoverageResults@1
            inputs:
              codeCoverageTool: Cobertura
              summaryFileLocation: '**/coverage.cobertura.xml'
          - publish: $(Build.ArtifactStagingDirectory)
            artifact: webapp

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
        environment: production   # ← Approval gate configured here
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureWebApp@1
                  inputs:
                    azureSubscription: 'MyServiceConnection'
                    appName: 'myapp-prod'
```

### Reusable Templates
```yaml
# templates/dotnet-build.yml
parameters:
  - name: configuration
    type: string
    default: Release

steps:
  - task: UseDotNet@2
    inputs:
      version: '8.0.x'
  - script: dotnet build --configuration ${{ parameters.configuration }}
  - script: dotnet test --configuration ${{ parameters.configuration }}

# Main pipeline using template
stages:
  - stage: Build
    jobs:
      - job: Build
        steps:
          - template: templates/dotnet-build.yml
            parameters:
              configuration: Release
```

### Variable Groups (Secrets from Key Vault)
```yaml
variables:
  - group: myapp-prod-secrets   # Linked to Key Vault in Azure DevOps
  - name: buildConfiguration
    value: Release

# Secrets from the group are available as $(SecretName)
# They are masked in pipeline logs automatically
```

### Security Scanning in Pipeline
```yaml
- stage: SecurityScan
  jobs:
    - job: Scan
      steps:
        # Container image scan
        - script: |
            docker build -t myapp:$(Build.BuildId) .
            trivy image --exit-code 1 --severity HIGH,CRITICAL myapp:$(Build.BuildId)
          displayName: Trivy container scan

        # IaC scan
        - script: |
            pip install checkov
            checkov -d ./terraform --framework terraform --soft-fail-on MEDIUM
          displayName: Checkov IaC scan

        # Dependency scan
        - task: dependency-check-build-task@6
          inputs:
            projectName: myapp
            scanPath: .
            format: JSON
```

### Configure Approval Gate
1. Go to **Pipelines → Environments → production**
2. Click **Approvals and checks → Add → Approvals**
3. Add approvers (e.g., "Release Managers" group)
4. Set timeout (e.g., 24 hours)

---

## Part 2: Azure Infrastructure with Terraform

### AKS Cluster
```hcl
resource "azurerm_kubernetes_cluster" "main" {
  name                = "aks-training-prod"
  resource_group_name = var.resource_group_name
  location            = var.location
  dns_prefix          = "training"
  kubernetes_version  = "1.28"

  # System node pool (runs kube-system pods)
  default_node_pool {
    name                = "system"
    node_count          = 3
    vm_size             = "Standard_D4s_v3"
    vnet_subnet_id      = var.aks_subnet_id
    enable_auto_scaling = true
    min_count           = 3
    max_count           = 5
    node_taints         = ["CriticalAddonsOnly=true:NoSchedule"]
  }

  identity { type = "SystemAssigned" }

  network_profile {
    network_plugin    = "azure"   # Azure CNI — pods get VNet IPs
    network_policy    = "calico"
    load_balancer_sku = "standard"
    service_cidr      = "172.16.0.0/16"
    dns_service_ip    = "172.16.0.10"
  }

  azure_active_directory_role_based_access_control {
    managed            = true
    azure_rbac_enabled = true
  }

  oms_agent {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }

  lifecycle {
    ignore_changes = [
      default_node_pool[0].node_count,  # Managed by autoscaler
      kubernetes_version                 # Managed by upgrade policy
    ]
  }
}

# User node pool for application workloads
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = "Standard_D4s_v3"
  vnet_subnet_id        = var.aks_subnet_id
  enable_auto_scaling   = true
  min_count             = 2
  max_count             = 20
}

# Grant AKS pull access to ACR
resource "azurerm_role_assignment" "aks_acr" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}
```

---

## POC 2 Complete: CI Pipeline Running Green

### Pipeline YAML for POC 2
```yaml
# azure-pipelines.yml
trigger:
  branches:
    include: [main]

stages:
  - stage: Build
    jobs:
      - job: Build
        pool:
          vmImage: ubuntu-latest
        steps:
          - task: DotNetCoreCLI@2
            inputs:
              command: test
              arguments: '--collect:"XPlat Code Coverage"'
          - task: PublishCodeCoverageResults@1
            inputs:
              codeCoverageTool: Cobertura
              summaryFileLocation: '**/coverage.cobertura.xml'
          - publish: $(Build.ArtifactStagingDirectory)
            artifact: webapp

  - stage: Deploy
    dependsOn: Build
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
    jobs:
      - deployment: Deploy
        environment: dev
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureWebApp@1
                  inputs:
                    azureSubscription: 'MyServiceConnection'
                    appName: 'app-poc2-dev'
```

### Validate
```bash
# Trigger pipeline
git push origin main

# Check pipeline status
az pipelines runs list --pipeline-name "POC2-Pipeline" \
  --org https://dev.azure.com/myOrg --project myProject \
  --query "[0].{status:status,result:result}" -o table
```

---

## Interview Q&A — Day 5 Topics

**Q: What is the difference between CI, Continuous Delivery, and Continuous Deployment?**
A: CI (Continuous Integration): every commit triggers an automated build and test suite — detects integration issues early. Continuous Delivery: every successful CI build produces a release candidate that *could* be deployed to production with a button click. Continuous Deployment: every successful build is *automatically* deployed to production with no human intervention. Most enterprises practice Continuous Delivery — they need change management approval for production.

**Q: How do you implement approval gates in Azure Pipelines?**
A: Configure them on Environments (not on the pipeline YAML). Go to Pipelines → Environments → production → Approvals and checks → Add → Approvals. Add approvers and timeout. In the pipeline YAML, use a `deployment` job targeting that environment — it will automatically wait for approval before proceeding.

**Q: What is artifact immutability and why does it matter?**
A: Build once, deploy the same artifact everywhere. The same binary/container image that passed tests in dev is deployed to staging and then production — no rebuilding. This ensures what you tested is exactly what runs in production. Rebuilding for each environment risks introducing differences (different dependency versions, build environment changes).

**Q: What is the difference between Azure CNI and kubenet networking in AKS?**
A: Kubenet: pods get IPs from a separate pod CIDR, not from the VNet — limited connectivity to other VNet resources. Azure CNI: pods get IPs directly from the VNet subnet — they're first-class VNet citizens. Required for: private endpoints, direct pod-to-pod communication across VNets, network policies with Calico. Azure CNI requires more IP addresses — plan subnet size carefully (each node needs IPs for max pods).

**Q: Why use `ignore_changes = [default_node_pool[0].node_count]` on AKS?**
A: The cluster autoscaler manages node count dynamically. Without `ignore_changes`, every `terraform apply` would reset the node count to the value in the config, overriding the autoscaler's decisions and potentially destroying nodes that have running pods.
