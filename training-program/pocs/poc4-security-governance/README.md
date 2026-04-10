# POC 4: Full Pipeline + Key Vault + SPN + Policy + Monitor

## Architecture

```
Azure DevOps Pipeline
    ↓ (OIDC federated identity — no stored secrets)
Service Principal → Terraform Apply
    ↓
Key Vault (RBAC) ← App Managed Identity
    ↓
Azure Policy Initiative (tagging + regions + diagnostics)
    ↓
Log Analytics + Application Insights + Alert Rules
    ↓
Action Group → Teams/PagerDuty notification
```

## Key Security Features
- OIDC federated identity: pipeline authenticates with no stored credentials
- Key Vault RBAC: fine-grained secret access control
- Azure Policy: governance enforced at subscription level
- Defender for Cloud: security score and recommendations
- All resources have diagnostic settings → Log Analytics

## Validation Checklist
- [ ] Pipeline runs with no stored service principal secrets
- [ ] Key Vault audit logs show secret access events
- [ ] Azure Policy compliance > 90%
- [ ] Alert fires on simulated error (test alert)
- [ ] Log Analytics receives diagnostic logs from all resources
- [ ] Defender for Cloud security score visible
