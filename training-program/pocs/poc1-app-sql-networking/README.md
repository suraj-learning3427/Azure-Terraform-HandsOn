# POC 1: App + SQL + Networking Foundation

## Architecture

```
Internet → Azure Load Balancer → App Service (staging slot)
                                      ↓
                               Key Vault (connection strings)
                                      ↓
                               Azure SQL (TDE + DDM)
                                      ↑
                          VNet 10.0.0.0/16
                          ├── web-subnet  10.0.1.0/24 (App Service VNet integration)
                          ├── data-subnet 10.0.2.0/24 (SQL private endpoint)
                          └── mgmt-subnet 10.0.3.0/24 (Bastion)
```

## Prerequisites
- Azure subscription with Contributor access
- Terraform >= 1.5.0
- Azure CLI >= 2.50.0
- `az login` completed

## Deployment Steps

### Step 1: Bootstrap Remote State
```bash
cd terraform/bootstrap
terraform init
terraform apply -auto-approve
```

### Step 2: Deploy Foundation Infrastructure
```bash
cd terraform/foundation
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### Step 3: Deploy Application
```bash
# Deploy to staging slot
az webapp deployment source config-zip \
  --name $(terraform output -raw app_service_name) \
  --resource-group $(terraform output -raw resource_group_name) \
  --slot staging \
  --src app.zip

# Swap staging to production
az webapp deployment slot swap \
  --name $(terraform output -raw app_service_name) \
  --resource-group $(terraform output -raw resource_group_name) \
  --slot staging \
  --target-slot production
```

## Validation Checklist
- [ ] App Service returns 200 on `/health`
- [ ] Staging slot accessible at `<appname>-staging.azurewebsites.net`
- [ ] SQL connection works from App Service (check App Insights)
- [ ] Dynamic Data Masking: non-admin user sees masked email/phone
- [ ] No public endpoint on SQL server
- [ ] Key Vault references resolve in app settings
- [ ] Remote state stored in Azure Storage blob
- [ ] All resources tagged with environment/team/cost_center
