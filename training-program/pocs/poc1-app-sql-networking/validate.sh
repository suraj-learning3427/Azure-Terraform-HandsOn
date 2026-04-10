#!/bin/bash
# POC 1 Validation Script
set -e

RG=$(terraform -chdir=terraform output -raw resource_group_name)
APP=$(terraform -chdir=terraform output -raw app_service_name)
SQL_SERVER=$(terraform -chdir=terraform output -raw sql_server_name)

echo "=== POC 1 Validation ==="
echo "Resource Group: $RG"

# 1. App Service running
echo -n "App Service state: "
az webapp show --name $APP --resource-group $RG --query state -o tsv

# 2. App returns 200
echo -n "Health check: "
curl -s -o /dev/null -w "%{http_code}" https://$APP.azurewebsites.net/health

# 3. Staging slot exists
echo -e "\nStaging slot: "
az webapp deployment slot list --name $APP --resource-group $RG --query "[].name" -o tsv

# 4. SQL public access disabled
echo -n "SQL public access: "
az sql server show --name $SQL_SERVER --resource-group $RG --query publicNetworkAccess -o tsv

# 5. TDE enabled
echo -n "TDE status: "
az sql db tde show --database sqldb-dev-poc1 --server $SQL_SERVER --resource-group $RG --query status -o tsv

# 6. Auto-scale configured
echo -n "Autoscale rules: "
az monitor autoscale show --name "autoscale-dev-poc1" --resource-group $RG --query "profiles[0].rules | length(@)" -o tsv

echo "=== Validation Complete ==="
