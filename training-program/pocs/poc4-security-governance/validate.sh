#!/bin/bash
set -e
RG="rg-poc4-security"
KV="kv-poc4-prod"

echo "=== POC 4 Validation ==="

echo -n "Key Vault RBAC enabled: "
az keyvault show --name $KV --resource-group $RG --query "properties.enableRbacAuthorization" -o tsv

echo -n "Policy assignment exists: "
az policy assignment show --name governance-assignment --scope $(az account show --query id -o tsv) --query "name" -o tsv 2>/dev/null || echo "Not found"

echo -n "Log Analytics workspace: "
az monitor log-analytics workspace show --workspace-name law-poc4-prod --resource-group $RG --query "provisioningState" -o tsv

echo -n "App Insights: "
az monitor app-insights component show --app appi-poc4-prod --resource-group $RG --query "provisioningState" -o tsv

echo -n "Alert rule: "
az monitor metrics alert show --name alert-high-error-rate --resource-group $RG --query "enabled" -o tsv

echo "=== Validation Complete ==="
