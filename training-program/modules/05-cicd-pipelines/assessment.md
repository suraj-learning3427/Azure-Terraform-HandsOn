# Module 5: CI/CD Pipelines — Assessment

## Knowledge Checks

**Q1**: What is the difference between `dependsOn` and `condition` in Azure Pipelines?
**Answer**: `dependsOn` defines execution order — a stage/job won't start until its dependencies complete. `condition` defines whether a stage/job runs at all — e.g., `condition: eq(variables['Build.SourceBranch'], 'refs/heads/main')` only runs on main branch. You can combine them: depend on a previous stage AND only run if it succeeded AND only on main.

**Q2**: What is OIDC and why is it better than storing service principal secrets in GitHub?
**Answer**: OIDC (OpenID Connect) allows GitHub Actions to authenticate to Azure using short-lived tokens issued by GitHub's identity provider, without storing any credentials. Azure trusts GitHub's OIDC issuer and issues access tokens based on the workflow's identity (repo + branch + environment). No secrets to rotate, no risk of credential leakage.

**Q3**: What is artifact immutability and why does it matter?
**Answer**: Build once, deploy the same artifact everywhere. The same binary/container image that passed tests in dev is deployed to staging and then production — no rebuilding. This ensures what you tested is exactly what runs in production. Rebuilding for each environment risks introducing differences (different dependency versions, build environment changes).

**Q4**: What is a deployment job in Azure Pipelines and how does it differ from a regular job?
**Answer**: A deployment job targets an environment and records deployment history. It supports deployment strategies (runOnce, rolling, canary). It respects environment approval gates and checks. Regular jobs don't have environment context or deployment history tracking.

---

## Practical Task: Create a Multi-Stage Pipeline

Create an Azure Pipelines YAML with:
1. Build stage: restore, build, test with coverage
2. Deploy to staging: automatic on main branch
3. Deploy to production: requires manual approval

**Validation**:
```bash
# Trigger pipeline and verify stages
az pipelines run --name "MyPipeline" --branch main \
  --org https://dev.azure.com/myOrg --project myProject

# Check pipeline run status
az pipelines runs list --pipeline-name "MyPipeline" \
  --org https://dev.azure.com/myOrg --project myProject \
  --query "[0].{status:status,result:result}"
```

---

## Rubric

### Criterion 1: Pipeline Design
| Level | Description |
|-------|-------------|
| Exemplary (4) | Multi-stage pipeline with templates, variable groups linked to Key Vault, OIDC auth, quality gates (coverage + SAST), approval gates, and notifications. Pipeline completes in < 15 minutes. |
| Proficient (3) | Multi-stage pipeline with quality gates and approval gates. Uses variable groups. Minor gaps in templates or OIDC. |
| Developing (2) | Single-stage pipeline or multi-stage without approval gates. Secrets stored in pipeline variables. |
| Beginning (1) | Cannot create a working pipeline YAML. Does not understand stages vs. jobs vs. steps. |
