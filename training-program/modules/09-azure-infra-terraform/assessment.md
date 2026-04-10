# Module 9: Azure Infrastructure with Terraform — Assessment

## Knowledge Checks

**Q1**: Why should you use `ignore_changes = [instances]` on a VMSS resource?
**Answer**: The autoscaler manages the instance count dynamically. Without `ignore_changes`, every `terraform apply` would reset the instance count to the value in the Terraform config, overriding the autoscaler's decisions. `ignore_changes` tells Terraform to not manage that attribute after initial creation.

**Q2**: What is the difference between Azure CNI and kubenet networking in AKS?
**Answer**: Kubenet: pods get IPs from a separate pod CIDR, not from the VNet. Simpler but limited — pods can't be directly accessed from on-premises or other VNets without additional routing. Azure CNI: pods get IPs directly from the VNet subnet — they're first-class VNet citizens. Required for: private endpoints, direct pod-to-pod communication across VNets, network policies with Calico, and most enterprise scenarios. Azure CNI requires more IP addresses (plan subnet size carefully).

**Q3**: What is the Key Vault CSI driver and why is it preferred over environment variables for secrets?
**Answer**: The Key Vault CSI driver mounts Key Vault secrets as files in pod volumes. Preferred because: secrets are fetched at pod startup (not baked into the image), they're automatically rotated (pod restarts pick up new values), they're not visible in `kubectl describe pod` (unlike env vars), and they follow the principle of least privilege (each pod only mounts the secrets it needs).

**Q4**: What is a node taint and toleration in Kubernetes?
**Answer**: A taint marks a node as "reserved" — pods won't be scheduled there unless they have a matching toleration. Use case: system node pool has `CriticalAddonsOnly=true:NoSchedule` taint — only system pods (with the toleration) run there, keeping it free for kube-system workloads. User workloads go to the user node pool. This prevents user pods from consuming resources needed by system components.

---

## Practical Task: Deploy AKS with Terraform

Deploy an AKS cluster with system and user node pools using Terraform.

```bash
# Validation
terraform apply

# Verify cluster
az aks get-credentials --name aks-myapp-prod --resource-group myRG
kubectl get nodes -o wide
# Expected: system and user node pool nodes

# Verify ACR integration
kubectl run test --image=myacr.azurecr.io/myapp:latest --restart=Never
kubectl get pod test
# Expected: Running (no imagePullBackOff)

# Verify autoscaler
kubectl -n kube-system get configmap cluster-autoscaler-status -o yaml
```

---

## Rubric

### Criterion 1: AKS Architecture Design
| Level | Description |
|-------|-------------|
| Exemplary (4) | Designs AKS with system/user node pools, Azure CNI, Azure AD RBAC, Container Insights, private cluster, ACR integration, Key Vault CSI driver, and cluster autoscaler. Explains node pool sizing rationale. |
| Proficient (3) | Deploys AKS with system/user node pools, Azure CNI, and monitoring. Minor gaps in private cluster or Key Vault integration. |
| Developing (2) | Deploys basic AKS cluster with single node pool. Missing Azure AD integration or monitoring. |
| Beginning (1) | Cannot deploy AKS with Terraform or explain node pool concepts. |
