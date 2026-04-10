# Module 9: Azure Infrastructure with Terraform — Problem Statements

## Scenario A: Enterprise AKS Platform

### Business Context
A company needs an AKS cluster with system and user node pools, Azure CNI networking, Azure AD integration, Container Insights monitoring, and private API server endpoint for a production Kubernetes platform.

### Technical Requirements
1. AKS cluster: Kubernetes 1.28, system node pool (3 nodes, D4s_v3), user node pool (2-20 nodes, autoscale)
2. Azure CNI networking with Calico network policy
3. Azure AD RBAC integration — cluster admins via Azure AD group
4. Container Insights with Log Analytics workspace
5. Private cluster: API server accessible only from VNet
6. ACR integration: AKS can pull images from ACR without credentials
7. Key Vault CSI driver: mount secrets as volumes in pods
8. Cluster autoscaler enabled on user node pool

### Success Criteria
1. `kubectl get nodes` shows system and user node pools
2. Pod can pull image from ACR without imagePullSecret
3. Pod can mount Key Vault secret as a file
4. Cluster API server not accessible from internet
5. Container Insights showing metrics in Azure Monitor

---

## Scenario B: Auto-Scaling Web Tier with VMSS

### Business Context
A high-traffic application needs a VMSS-based web tier with custom scaling rules, load balancer health probes, and automatic OS image updates.

### Technical Requirements
1. VMSS with Ubuntu 22.04, Standard_D2s_v3, min 2 / max 10 instances
2. Azure Load Balancer with health probe on `/health` (HTTP 200)
3. Autoscale: scale out at 70% CPU, scale in at 30% CPU
4. Automatic OS image updates with rolling upgrade policy
5. NSG: allow 443 inbound from internet, allow 22 from bastion subnet only
6. Managed Identity for VMSS instances to access Key Vault
7. Custom script extension to install and configure nginx on first boot

### Success Criteria
1. Load balancer health probe shows all instances healthy
2. Autoscale triggers within 5 minutes of CPU threshold breach
3. OS image update completes without downtime (rolling upgrade)
4. VMSS instances can read Key Vault secrets via Managed Identity
