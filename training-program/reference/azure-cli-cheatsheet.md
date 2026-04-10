# Azure CLI Cheatsheet

## Authentication
```bash
az login                                    # Interactive login
az account list                             # List subscriptions
az account set --subscription "My Sub"      # Set active subscription
az account show                             # Show current subscription
```

## Resource Groups
```bash
az group create --name myRG --location eastus2
az group list --query "[].name" -o tsv
az group delete --name myRG --yes --no-wait
```

## App Service
```bash
# Create
az appservice plan create --name myPlan --resource-group myRG --sku P1v3 --is-linux
az webapp create --name myApp --resource-group myRG --plan myPlan --runtime "DOTNETCORE:8.0"

# Deployment slots
az webapp deployment slot create --name myApp --resource-group myRG --slot staging
az webapp deployment slot swap --name myApp --resource-group myRG --slot staging --target-slot production
az webapp traffic-routing set --name myApp --resource-group myRG --distribution staging=10

# Settings
az webapp config appsettings set --name myApp --resource-group myRG --settings KEY=VALUE
az webapp identity assign --name myApp --resource-group myRG

# Scaling
az monitor autoscale create --resource myPlan --resource-type Microsoft.Web/serverfarms \
  --resource-group myRG --name autoscale --min-count 2 --max-count 10 --count 2
```

## Azure SQL
```bash
az sql server create --name myServer --resource-group myRG --location eastus2 \
  --admin-user sqladmin --admin-password "P@ssw0rd!"
az sql db create --name myDB --server myServer --resource-group myRG --sku GP_Gen5_2
az sql db tde show --database myDB --server myServer --resource-group myRG
az sql failover-group create --name myFOG --server myServer --resource-group myRG \
  --partner-server myServerSecondary --failover-policy Automatic
```

## AKS
```bash
az aks create --name myAKS --resource-group myRG --node-count 3 --node-vm-size Standard_D4s_v3
az aks get-credentials --name myAKS --resource-group myRG
az aks nodepool add --cluster-name myAKS --resource-group myRG --name user \
  --node-count 2 --enable-cluster-autoscaler --min-count 2 --max-count 20
az aks update --name myAKS --resource-group myRG --attach-acr myACR
```

## Key Vault
```bash
az keyvault create --name myKV --resource-group myRG --enable-rbac-authorization true
az keyvault secret set --vault-name myKV --name MySecret --value "s3cr3t"
az keyvault secret show --vault-name myKV --name MySecret --query value -o tsv
az role assignment create --role "Key Vault Secrets User" --assignee <principal-id> \
  --scope $(az keyvault show --name myKV --query id -o tsv)
```

## Azure Policy
```bash
az policy assignment create --name myAssignment \
  --policy "/providers/Microsoft.Authorization/policyDefinitions/<id>" \
  --scope "/subscriptions/<sub-id>"
az policy state list --resource-group myRG --query "[?complianceState=='NonCompliant']"
az policy remediation create --name myRemediation --policy-assignment myAssignment \
  --resource-group myRG
```

## Monitor
```bash
az monitor metrics alert create --name myAlert --resource-group myRG \
  --scopes <resource-id> --condition "avg Percentage CPU > 80" --window-size 5m
az monitor log-analytics workspace create --name myLAW --resource-group myRG
az monitor diagnostic-settings create --name myDiag --resource <resource-id> \
  --workspace <law-id> --logs '[{"category":"AuditEvent","enabled":true}]'
```

## Useful Query Patterns
```bash
# Get resource IDs
az webapp show --name myApp --resource-group myRG --query id -o tsv

# List with specific fields
az vm list --query "[].{name:name,size:hardwareProfile.vmSize,rg:resourceGroup}" -o table

# Filter by tag
az resource list --tag environment=production --query "[].name" -o tsv

# Get managed identity principal ID
az webapp identity show --name myApp --resource-group myRG --query principalId -o tsv
```
