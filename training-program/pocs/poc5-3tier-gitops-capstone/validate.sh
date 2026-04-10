#!/bin/bash
set -e
RG="rg-poc5-prod"
AKS="aks-poc5-prod"

echo "=== POC 5 Capstone Validation ==="

# Get AKS credentials
az aks get-credentials --name $AKS --resource-group $RG --overwrite-existing

echo "Node pools:"
kubectl get nodes -o wide

echo -e "\nFlux kustomizations:"
flux get kustomizations 2>/dev/null || echo "Flux not installed yet"

echo -e "\nProduction pods:"
kubectl get pods -n production 2>/dev/null || echo "Namespace not created yet"

echo -e "\nApplication Gateway WAF:"
az network application-gateway waf-config show \
  --gateway-name agw-poc5-prod \
  --resource-group $RG \
  --query "enabled" -o tsv

echo -e "\nSQL private endpoint:"
az network private-endpoint show \
  --name pe-sql-poc5-prod \
  --resource-group $RG \
  --query "provisioningState" -o tsv

echo -e "\nACR geo-replication:"
az acr replication list --registry acrpoc5prod --query "[].{location:location,status:status.displayStatus}" -o table

echo "=== Validation Complete ==="
