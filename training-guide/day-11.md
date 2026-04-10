# Day 11 — Apr 29 | 3-Tier Architecture + AKS GitOps
**Presenters**: Suraj & Joby

---

## What You'll Learn Today
- Complete 3-tier architecture design and implementation
- GitOps with Flux on AKS
- End-to-end: App Gateway → AKS → SQL + Redis

---

## Part 1: 3-Tier Architecture

### Architecture Overview
```
Internet
    ↓
Application Gateway (WAF v2)  ← Single entry point, OWASP rules
    ↓
AKS Cluster (System + User Node Pools)
    ├── Web Tier Pods (Deployment, HPA)
    ├── API Tier Pods (Deployment, HPA)
    └── Key Vault CSI Driver (secrets as files)
    ↓
Data Tier (Private Endpoints — no public access)
    ├── Azure SQL (GP_Gen5_4)
    └── Azure Cache for Redis (Premium)

Supporting:
    ├── ACR (geo-replicated) — AKS pulls images
    ├── Log Analytics + Container Insights
    └── Azure Monitor alerts
```

### Key Design Decisions
- Each tier in its own subnet with NSG rules
- No direct internet access to app or data tiers
- Private endpoints for SQL and Redis
- Managed Identities for all service-to-service auth
- Application Gateway as the single ingress point with WAF

### Terraform: Complete 3-Tier
```hcl
# Networking: 4 subnets
resource "azurerm_virtual_network" "main" {
  name          = "vnet-poc5-prod"
  address_space = ["10.2.0.0/16"]
  # ...
}

# snet-agw:  10.2.1.0/24  — Application Gateway
# snet-aks:  10.2.2.0/23  — AKS pods (Azure CNI needs /23 for enough IPs)
# snet-data: 10.2.4.0/24  — Private endpoints (SQL, Redis)

# AKS with Container Insights + Key Vault CSI
resource "azurerm_kubernetes_cluster" "main" {
  # ... (see Day 5 for full config)
  key_vault_secrets_provider {
    secret_rotation_enabled = true  # Auto-rotate secrets in pods
  }
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  }
}

# SQL with private endpoint
resource "azurerm_mssql_server" "main" {
  public_network_access_enabled = false  # Private endpoint only
  # ...
}
resource "azurerm_private_endpoint" "sql" {
  subnet_id = azurerm_subnet.data.id
  private_service_connection {
    private_connection_resource_id = azurerm_mssql_server.main.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }
}

# Redis with private endpoint
resource "azurerm_redis_cache" "main" {
  sku_name                      = "Premium"
  capacity                      = 1
  family                        = "P"
  public_network_access_enabled = false
}
resource "azurerm_private_endpoint" "redis" {
  subnet_id = azurerm_subnet.data.id
  private_service_connection {
    private_connection_resource_id = azurerm_redis_cache.main.id
    subresource_names              = ["redisCache"]
    is_manual_connection           = false
  }
}
```

---

## Part 2: GitOps with Flux

### What is GitOps?
Git is the single source of truth for both application code AND infrastructure configuration. A GitOps controller (Flux) continuously syncs the cluster state to match what's in Git.

```
Developer pushes code
    ↓
CI: Build image → push to ACR
    ↓
CI: Update image tag in gitops/ directory → commit to Git
    ↓
Flux detects change in Git (polls every 1 minute)
    ↓
Flux applies Helm release to AKS
    ↓
Kubernetes rolls out new pods (zero downtime)
```

### Install Flux on AKS
```bash
# Get AKS credentials
az aks get-credentials --name aks-poc5-prod --resource-group rg-poc5-prod

# Install Flux CLI
curl -s https://fluxcd.io/install.sh | sudo bash

# Bootstrap Flux (connects to GitHub repo)
flux bootstrap github \
  --owner=myorg \
  --repository=myapp-gitops \
  --branch=main \
  --path=clusters/production \
  --personal

# Verify Flux is running
flux get kustomizations
kubectl get pods -n flux-system
```

### Flux Kustomization
```yaml
# clusters/production/myapp.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: myapp
  namespace: flux-system
spec:
  interval: 1m          # Check Git every minute
  path: ./apps/production
  prune: true           # Remove resources deleted from Git
  sourceRef:
    kind: GitRepository
    name: myapp-gitops
  healthChecks:
    - apiVersion: apps/v1
      kind: Deployment
      name: myapp-web
      namespace: production
```

### Helm Release via Flux
```yaml
# apps/production/myapp-helmrelease.yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: myapp
  namespace: production
spec:
  interval: 5m
  chart:
    spec:
      chart: ./helm/myapp
      sourceRef:
        kind: GitRepository
        name: myapp-gitops
  values:
    image:
      repository: acrpoc5prod.azurecr.io/myapp
      tag: "abc123"    # CI updates this value
  upgrade:
    remediation:
      retries: 3
```

### CI Pipeline: Update Image Tag in Git
```yaml
- stage: UpdateGitOps
  dependsOn: Build
  jobs:
    - job: UpdateImageTag
      steps:
        - script: |
            # Clone gitops repo
            git clone https://$(GITHUB_TOKEN)@github.com/myorg/myapp-gitops.git
            cd myapp-gitops

            # Update image tag
            sed -i "s/tag: .*/tag: \"$(Build.BuildId)\"/" \
              apps/production/myapp-helmrelease.yaml

            # Commit and push
            git config user.email "pipeline@mycompany.com"
            git config user.name "Azure DevOps Pipeline"
            git add .
            git commit -m "Update myapp image to $(Build.BuildId)"
            git push
          displayName: Update image tag in GitOps repo
```

### Key Vault CSI Driver — Mount Secrets as Files
```yaml
# Kubernetes: SecretProviderClass
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: myapp-secrets
  namespace: production
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "true"
    userAssignedIdentityID: ""  # Use pod's managed identity
    keyvaultName: kv-poc5-prod
    tenantId: <tenant-id>
    objects: |
      array:
        - |
          objectName: SqlConnectionString
          objectType: secret
        - |
          objectName: RedisConnectionString
          objectType: secret

---
# Pod: mount secrets as files
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-api
spec:
  template:
    spec:
      volumes:
        - name: secrets
          csi:
            driver: secrets-store.csi.k8s.io
            readOnly: true
            volumeAttributes:
              secretProviderClass: myapp-secrets
      containers:
        - name: api
          image: acrpoc5prod.azurecr.io/myapp:latest
          volumeMounts:
            - name: secrets
              mountPath: /mnt/secrets
              readOnly: true
          # App reads /mnt/secrets/SqlConnectionString
```

---

## Validate POC 5
```bash
# Node pools
kubectl get nodes -o wide
# Expected: system nodes (3) + user nodes (2+)

# Flux sync status
flux get kustomizations
# Expected: myapp → Applied → True

# Application pods
kubectl get pods -n production
# Expected: myapp-web and myapp-api pods Running

# End-to-end test
AGW_IP=$(az network public-ip show --name pip-agw-poc5-prod \
  --resource-group rg-poc5-prod --query ipAddress -o tsv)
curl http://$AGW_IP/health
# Expected: 200 OK

# Secret mounted in pod
kubectl exec -n production deploy/myapp-api -- cat /mnt/secrets/SqlConnectionString
# Expected: connection string value
```

---

## Interview Q&A — Day 11 Topics

**Q: What is GitOps and how does Flux work?**
A: GitOps is a practice where Git is the single source of truth for both application and infrastructure configuration. Flux is a GitOps controller that runs in Kubernetes and continuously reconciles the cluster state with what's defined in Git. When you push a change to Git, Flux detects it (polls every 1 minute) and applies the change to the cluster. If someone manually changes something in the cluster, Flux reverts it to match Git. Benefits: audit trail (every change is a git commit), easy rollback (revert the commit), and consistent environments.

**Q: What is the Key Vault CSI driver and why is it preferred over environment variables for secrets?**
A: The Key Vault CSI driver mounts Key Vault secrets as files in pod volumes. Preferred because: secrets are fetched at pod startup (not baked into the image), they're automatically rotated (pod restarts pick up new values), they're not visible in `kubectl describe pod` (unlike env vars which are visible), and they follow least privilege (each pod only mounts the secrets it needs).

**Q: How do you design a 3-tier architecture in Azure for high availability?**
A: Web tier: Application Gateway (WAF) with multiple backend instances, auto-scaling. App tier: AKS with HPA (Horizontal Pod Autoscaler), multiple replicas across availability zones. Data tier: Azure SQL with zone-redundant configuration or geo-replication, Redis Premium with geo-replication. All tiers in separate subnets with NSG rules. Private endpoints for data tier — no public access. Managed Identities for all service-to-service auth.

**Q: What is the difference between Flux and ArgoCD?**
A: Both are GitOps controllers for Kubernetes. Flux: CLI-first, Kubernetes-native CRDs, better for multi-tenancy, part of CNCF. ArgoCD: UI-first, visual dashboard showing sync status, easier for teams new to GitOps. Both support Helm, Kustomize, and plain YAML. Choice depends on team preference — Flux for CLI-heavy teams, ArgoCD for teams that want a visual dashboard.

**Q: How do you handle a situation where Flux is stuck and not syncing?**
A: 1) Check Flux status: `flux get kustomizations` — look for error messages. 2) Check Flux controller logs: `kubectl logs -n flux-system deploy/kustomize-controller`. 3) Common causes: Git authentication failure (token expired), invalid YAML in the repo, resource conflict in the cluster. 4) Force reconciliation: `flux reconcile kustomization myapp --with-source`. 5) If a bad commit is blocking sync: revert the commit in Git, Flux will sync the revert.
