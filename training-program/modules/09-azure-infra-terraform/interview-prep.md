# Module 9: Azure Infrastructure with Terraform — Interview Preparation

## Q1 (Design): AKS vs VMSS for Application Hosting
**Question**: When would you choose AKS over VMSS for hosting a web application?

**Sample Answer**: AKS for: microservices with multiple containers, applications needing service discovery, workloads requiring fine-grained resource allocation (CPU/memory limits per container), teams with Kubernetes expertise, or when you need advanced deployment strategies (rolling updates, canary via Argo Rollouts). VMSS for: monolithic applications that aren't containerized, workloads requiring specific OS configuration, applications with licensing tied to VMs, or teams without Kubernetes expertise. For new cloud-native applications, AKS is almost always the better choice — the operational overhead is justified by the deployment flexibility and ecosystem.

---

## Q2 (Scenario): AKS Node Pool Sizing
**Question**: How do you determine the right VM size and node count for an AKS node pool?

**Sample Answer**: Start with workload requirements: 1) Sum the CPU and memory requests of all pods that will run on the cluster. 2) Add 30% headroom for system pods and autoscaler buffer. 3) Choose a VM size where each node can run 10-20 pods efficiently (avoid too many tiny nodes or too few huge nodes). 4) For the user node pool: Standard_D4s_v3 (4 vCPU, 16 GB) is a good general-purpose starting point. 5) Set min_count to handle baseline load, max_count to handle peak. 6) Monitor actual utilization for 2 weeks and right-size. Key: enable cluster autoscaler and let it manage node count — don't try to predict exact node count upfront.

---

## Q3 (Troubleshooting): AKS Pods Stuck in Pending
**Question**: Pods are stuck in Pending state. How do you diagnose this?

**Sample Answer**: `kubectl describe pod <pod-name>` — check the Events section. Common causes: 1) Insufficient resources: "0/3 nodes are available: 3 Insufficient cpu" — cluster autoscaler should add nodes, check autoscaler logs. 2) Node selector/affinity mismatch: pod requires a label that no node has. 3) Taint/toleration mismatch: pod doesn't tolerate a node taint. 4) PVC not bound: pod waiting for persistent volume. 5) Image pull failure: check imagePullPolicy and ACR access. For autoscaler issues: `kubectl -n kube-system logs -l app=cluster-autoscaler` — check why it's not scaling up.

---

## Q4 (Design): Private AKS Cluster Architecture
**Question**: A client requires that the AKS API server is not accessible from the internet. How do you implement this?

**Sample Answer**: Enable private cluster: `private_cluster_enabled = true` in Terraform. This creates a private endpoint for the API server in your VNet — the API server gets a private IP only. Implications: 1) `kubectl` commands must run from within the VNet (or via VPN/ExpressRoute). 2) CI/CD pipelines must run on self-hosted agents in the VNet (not Microsoft-hosted agents). 3) Azure DevOps self-hosted agent or GitHub Actions self-hosted runner deployed in the VNet. 4) Use Azure Bastion for developer access to the VNet. 5) Consider Azure Private DNS zone for the API server FQDN resolution.
