# Module 10: Security and Compliance — Problem Statements

## Scenario A: Secure CI/CD Pipeline

### Business Context
A financial services client requires all pipelines to include dependency vulnerability scanning, IaC security scanning, SAST analysis, and container image scanning before any deployment to production.

### Technical Requirements
1. Dependency scanning: OWASP Dependency Check, fail on CVSS >= 7.0
2. SAST: SonarCloud with quality gate (0 new blockers/criticals)
3. Container scanning: Trivy, fail on HIGH/CRITICAL unfixed CVEs
4. IaC scanning: Checkov on Terraform, fail on HIGH/CRITICAL misconfigurations
5. DAST: OWASP ZAP baseline scan against staging environment
6. Secret scanning: detect-secrets pre-commit hook + CI check
7. All scan results published as pipeline artifacts
8. Security dashboard in Azure DevOps showing trend over time

### Success Criteria
1. Pipeline fails if any HIGH/CRITICAL vulnerability found
2. Security scan results visible in PR comments
3. Zero secrets committed to repository (verified by secret scanning)
4. DAST scan runs against staging before production deployment

---

## Scenario B: Governance at Scale

### Business Context
A company with 20 Azure subscriptions needs Azure Policy to enforce tagging standards, allowed regions, required diagnostic settings, and prohibited resource types across all subscriptions.

### Technical Requirements
1. Management group hierarchy: Root → Business Units → Subscriptions
2. Policy initiative at root management group: require tags (environment, team, cost_center)
3. Policy: allowed locations = East US 2, West US 2, West Europe only
4. Policy: require diagnostic settings on all resources (audit effect)
5. Policy: deny public IP on VMs (deny effect)
6. Policy: require HTTPS-only on App Service (modify effect — auto-remediate)
7. Compliance dashboard showing compliance % per subscription
8. Weekly compliance report emailed to security team

### Success Criteria
1. Non-compliant resources identified within 24 hours of creation
2. Auto-remediation enables HTTPS-only on existing App Service apps
3. Compliance score > 90% across all subscriptions within 30 days
4. New resources in disallowed regions are blocked at creation time
