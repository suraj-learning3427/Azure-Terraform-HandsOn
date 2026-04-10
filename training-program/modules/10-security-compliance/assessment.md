# Module 10: Security and Compliance — Assessment

## Knowledge Checks

**Q1**: What is the difference between Checkov and Trivy?
**Answer**: Checkov scans Infrastructure as Code (Terraform, ARM, Kubernetes YAML) for security misconfigurations — e.g., storage account with public access enabled, NSG allowing all inbound traffic. Trivy scans container images and filesystems for known CVEs in OS packages and application dependencies. Use both: Checkov in the IaC pipeline stage, Trivy in the container build stage.

**Q2**: What is the difference between Azure Policy effects: Audit, Deny, and DeployIfNotExists?
**Answer**: Audit: logs non-compliant resources but doesn't block them — good for visibility without disruption. Deny: blocks creation/update of non-compliant resources — use for hard security requirements (e.g., no public IPs on VMs). DeployIfNotExists: automatically deploys a remediation resource when a non-compliant resource is found — use for auto-remediation (e.g., automatically enable diagnostic settings on new resources).

**Q3**: What is Just-In-Time (JIT) VM access?
**Answer**: JIT VM access (via Defender for Cloud) blocks RDP/SSH ports by default and only opens them for a specific user, from a specific IP, for a limited time (e.g., 3 hours) when explicitly requested. This eliminates the attack surface of permanently open management ports. All access requests are logged in Azure Activity Log.

**Q4**: What is a Log Analytics workspace and why should you have one per environment?
**Answer**: A Log Analytics workspace is a centralized repository for logs from Azure resources, VMs, containers, and applications. Separate workspaces per environment because: 1) Access control — dev team shouldn't see production logs. 2) Cost — production logs have longer retention (90 days) than dev (30 days). 3) Compliance — production logs may need to be in a specific region for data residency. 4) Blast radius — a misconfigured query in dev doesn't affect production log ingestion.

---

## Practical Task: Implement Security Scanning in Pipeline

Add Trivy and Checkov scanning stages to an existing Azure Pipeline.

```yaml
# Validation: pipeline should fail with this Dockerfile
FROM ubuntu:18.04  # Old base image with known CVEs
RUN apt-get install -y curl

# And this Terraform (Checkov should flag):
resource "azurerm_storage_account" "bad" {
  allow_nested_items_to_be_public = true  # Checkov: CKV_AZURE_59
  min_tls_version = "TLS1_0"             # Checkov: CKV_AZURE_3
}
```

---

## Rubric

### Criterion 1: Security Pipeline Implementation
| Level | Description |
|-------|-------------|
| Exemplary (4) | Implements SAST, dependency scanning, container scanning, and IaC scanning. All scans fail the pipeline on HIGH/CRITICAL findings. Results published as artifacts. Secret scanning in pre-commit and CI. |
| Proficient (3) | Implements container scanning and IaC scanning. Pipeline fails on critical findings. Minor gaps in SAST or secret scanning. |
| Developing (2) | Implements one scanning tool. Pipeline doesn't fail on findings (only reports). |
| Beginning (1) | No security scanning in pipeline. Cannot explain the difference between SAST and DAST. |
