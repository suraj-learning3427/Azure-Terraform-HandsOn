#!/bin/bash
set -e
RG="rg-poc2-dev"
VMSS="vmss-poc2-dev"

echo "=== POC 2 Validation ==="

echo -n "VMSS instances: "
az vmss list-instances --name $VMSS --resource-group $RG --query "length(@)" -o tsv

echo -n "LB health probe status: "
az network lb probe show --lb-name lb-poc2-dev --name health-probe --resource-group $RG --query "provisioningState" -o tsv

echo -n "Autoscale min instances: "
az monitor autoscale show --name autoscale-poc2-dev --resource-group $RG --query "profiles[0].capacity.minimum" -o tsv

echo "=== Validation Complete ==="
