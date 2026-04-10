#!/bin/bash
set -e
ACR="acrpoc3prod"
APP="app-poc3-prod"
RG="rg-poc3-prod"
AKS="aks-poc3-prod"

echo "=== POC 3 Validation ==="

echo -n "ACR image exists: "
az acr repository show-tags --name $ACR --repository myapp --query "[-1]" -o tsv

echo -n "App Service state: "
az webapp show --name $APP --resource-group $RG --query state -o tsv

echo -n "Staging slot: "
az webapp deployment slot list --name $APP --resource-group $RG --query "[0].name" -o tsv

echo "AKS pods:"
az aks get-credentials --name $AKS --resource-group $RG --overwrite-existing
kubectl get pods -n production

echo "=== Validation Complete ==="
