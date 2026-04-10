# Module 10: Security and Compliance — Interview Preparation

## Q1 (Conceptual): Shift-Left Security
**Question**: What does "shift-left security" mean and how do you implement it in a DevOps pipeline?

**Sample Answer**: Shift-left means moving security checks earlier in the development lifecycle — from production (far right) to development (far left). Instead of finding vulnerabilities in production, you catch them in the IDE, code review, or CI pipeline. Implementation: 1) IDE plugins (SonarLint) for real-time code analysis. 2) Pre-commit hooks for secret scanning and linting. 3) PR checks: SAST (SonarCloud), dependency scanning (OWASP), IaC scanning (Checkov). 4) CI pipeline: container scanning (Trivy), DAST against staging. 5) Production: runtime protection (Defender for Cloud), anomaly detection. The cost of fixing a vulnerability in development is 10x cheaper than in production.

---

## Q2 (Scenario): Security Incident Response
**Question**: Azure Defender for Cloud alerts you that a VM in production is communicating with a known malicious IP. What do you do?

**Sample Answer**: Incident response: 1) Isolate immediately — apply an NSG rule to block all outbound traffic from the VM. 2) Preserve evidence — take a snapshot of the VM disk before any changes. 3) Investigate — check Azure Activity Log for recent changes, review VM login history, check running processes and network connections. 4) Determine scope — is this one VM or multiple? Check if the malicious IP appears in other resources' logs. 5) Remediate — if compromised, rebuild the VM from a clean image (don't try to clean a compromised VM). 6) Post-mortem — how did the attacker get in? Patch the vulnerability. 7) Improve — add the malicious IP to Azure Firewall deny list, enable JIT VM access.

---

## Q3 (Design): Azure Policy for Compliance
**Question**: How would you use Azure Policy to enforce that all Azure SQL databases have TDE enabled?

**Sample Answer**: Use the built-in policy "Transparent Data Encryption on SQL databases should be enabled" (policy ID: 17k78e20-9358-41c9-923c-fb736d382a12). Assign it at the subscription or management group level with effect "AuditIfNotExists" to identify non-compliant databases, or "DeployIfNotExists" to automatically enable TDE on new databases. For existing non-compliant databases, create a remediation task in the policy assignment — it will trigger a deployment to enable TDE on all existing databases. Monitor compliance in Defender for Cloud's Regulatory Compliance dashboard.

---

## Q4 (Troubleshooting): High Security Score Recommendations
**Question**: Your Azure Security Score is 45/100. What are the highest-impact actions to improve it quickly?

**Sample Answer**: Focus on the recommendations with the highest "Max Score" impact. Typically the biggest wins: 1) Enable MFA for all users (often 10+ points). 2) Enable Defender for Cloud plans (Servers, SQL, Containers). 3) Apply system updates to VMs. 4) Remediate vulnerabilities found by Defender for Servers. 5) Enable disk encryption on VMs. 6) Restrict RDP/SSH access (use JIT or Bastion). 7) Enable Azure AD for SQL authentication. I'd export the recommendations to CSV, sort by "Max Score", and work through the top 10 — that usually gets you from 45 to 70+ within a week.
