# POC 3: CI/CD + App Service Slots + ACR + AKS

## Architecture

```
GitHub Push → CI: Build + Test + Scan
                    ↓
              Push image to ACR (geo-replicated)
                    ↓
         ┌──────────┴──────────┐
         ↓                     ↓
  CD: App Service          CD: AKS Deploy
  Staging Slot Deploy      via Helm chart
         ↓
  Canary: 10% → 50% → 100%
  (App Insights monitors error rate)
         ↓
  Auto-rollback if error rate > 1%
```

## Validation Checklist
- [ ] Image pushed to ACR after successful build
- [ ] App deployed to staging slot
- [ ] Canary traffic split: 10% to staging
- [ ] AKS pods running (kubectl get pods)
- [ ] Application Insights alert configured for rollback
- [ ] Rollback pipeline triggered on error rate breach
