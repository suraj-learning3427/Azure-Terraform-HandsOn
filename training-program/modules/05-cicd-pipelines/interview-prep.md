# Module 5: CI/CD Pipelines — Interview Preparation

## Q1 (Conceptual): CI vs CD vs CD
**Question**: Explain the difference between Continuous Integration, Continuous Delivery, and Continuous Deployment.

**Sample Answer**: CI (Continuous Integration) means every developer merges code to main frequently, and an automated build and test suite runs on every merge. The goal is to detect integration issues early. CD (Continuous Delivery) means the software is always in a deployable state — every successful CI build produces a release candidate that *could* be deployed to production with a button click. Continuous Deployment goes one step further: every successful build is *automatically* deployed to production with no human intervention. Most enterprises practice Continuous Delivery (not Deployment) because they need change management approval for production releases.

---

## Q2 (Scenario): Pipeline is Taking 45 Minutes
**Question**: Your CI pipeline takes 45 minutes. Developers are frustrated and skipping it. How do you fix it?

**Sample Answer**: 45 minutes is too long — target < 10 minutes for CI. I'd profile the pipeline first: which stage takes the longest? Common culprits: 1) Integration tests running in CI (move to a separate nightly pipeline), 2) No caching of dependencies (add `actions/cache` or Azure Pipelines cache task), 3) Sequential test execution (parallelize with matrix strategy or test splitting), 4) Large Docker builds (use multi-stage builds and layer caching), 5) Unnecessary steps (remove redundant restore/build steps). After optimization, I'd set a pipeline duration SLA and alert if it exceeds 12 minutes.

---

## Q3 (Design): Blue-Green Deployment Pipeline
**Question**: Design a pipeline that implements blue-green deployment for an Azure App Service application.

**Sample Answer**:
```yaml
stages:
  - stage: Deploy_Green  # Deploy to staging slot (green)
    steps:
      - task: AzureWebApp@1
        inputs:
          appName: myapp
          deployToSlotOrASE: true
          slotName: staging
          
  - stage: Smoke_Test  # Test green slot
    steps:
      - script: |
          curl -f https://myapp-staging.azurewebsites.net/health
          
  - stage: Swap  # Swap staging (green) to production (blue)
    environment: production  # Requires approval
    steps:
      - task: AzureAppServiceManage@0
        inputs:
          Action: 'Swap Slots'
          WebAppName: myapp
          SourceSlot: staging
          
  - stage: Rollback  # Available if swap causes issues
    condition: failed()
    steps:
      - task: AzureAppServiceManage@0
        inputs:
          Action: 'Swap Slots'
          WebAppName: myapp
          SourceSlot: staging  # Swap back
```

---

## Q4 (Security): Securing Pipeline Secrets
**Question**: A developer accidentally committed an Azure service principal secret to the git repo. What do you do immediately and how do you prevent it in the future?

**Sample Answer**: Immediate response: 1) Rotate the secret immediately — assume it's compromised. 2) Check Azure AD sign-in logs for any unauthorized use of that service principal. 3) Remove the secret from git history using `git filter-repo` (not `git filter-branch`). 4) Force-push the cleaned history and notify all team members to re-clone.

Prevention: 1) Add `detect-secrets` or `gitleaks` as a pre-commit hook and CI check. 2) Enable GitHub Advanced Security secret scanning (alerts on committed secrets). 3) Replace service principal secrets with OIDC federated identity — no secrets to commit. 4) Add `.gitignore` rules for `.env` files and credential files. 5) Mandatory security training for the team.
