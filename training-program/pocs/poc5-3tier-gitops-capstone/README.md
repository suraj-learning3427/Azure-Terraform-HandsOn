# POC 5: 3-Tier Architecture + AKS GitOps Capstone

## Architecture

```
Internet
    ↓
Application Gateway (WAF v2)
    ↓
AKS Cluster (System + User Node Pools)
    ├── Flux GitOps Controller (syncs from Git)
    ├── Web Tier Pods (Deployment)
    ├── API Tier Pods (Deployment)
    └── Key Vault CSI Driver (mounts secrets as volumes)
    ↓
Data Tier (Private Endpoints)
    ├── Azure SQL (private endpoint)
    └── Azure Cache for Redis (private endpoint)

Supporting:
    ├── ACR (geo-replicated) — AKS pulls images
    ├── Log Analytics + Container Insights
    └── Azure Monitor alerts
```

## GitOps Workflow
1. Developer pushes code → CI builds image → pushes to ACR
2. CI updates image tag in `gitops/` directory → commits to Git
3. Flux detects change in Git → applies Helm release to AKS
4. Kubernetes rolls out new pods with zero downtime

## Deployment Steps

```bash
# 1. Deploy infrastructure
cd terraform
terraform init && terraform apply

# 2. Install Flux on AKS
az aks get-credentials --name aks-poc5-prod --resource-group rg-poc5-prod
flux bootstrap github \
  --owner=myorg \
  --repository=myapp-gitops \
  --branch=main \
  --path=clusters/production

# 3. Verify GitOps sync
flux get kustomizations
flux get helmreleases -A
```

## Validation Checklist
- [ ] Application Gateway WAF enabled
- [ ] AKS system and user node pools running
- [ ] Flux kustomization synced (flux get kustomizations)
- [ ] Web and API pods running (kubectl get pods -n production)
- [ ] SQL accessible from AKS pods via private endpoint
- [ ] Redis accessible from AKS pods via private endpoint
- [ ] Key Vault secrets mounted as files in pods
- [ ] Container Insights showing metrics
- [ ] End-to-end request: Internet → AGW → AKS → SQL returns 200
