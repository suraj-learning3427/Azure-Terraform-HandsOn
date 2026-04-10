# Module 4: DevOps Fundamentals — Assessment

## Knowledge Checks

**Q1**: What is the difference between GitFlow and trunk-based development?
**Answer**: GitFlow uses long-lived branches (develop, release, hotfix) and is suited for scheduled releases. Trunk-based development has everyone committing to main frequently with short-lived branches (< 2 days), enabling true CI/CD. Trunk-based is preferred for teams doing continuous deployment.

**Q2**: What are the four DORA metrics?
**Answer**: Deployment Frequency, Lead Time for Changes, Change Failure Rate, Time to Restore Service.

**Q3**: What is a blameless post-mortem?
**Answer**: A post-mortem that focuses on systemic causes of an incident rather than blaming individuals. The goal is to identify what failed in the process/system and how to prevent recurrence. Psychological safety is essential — people must feel safe reporting mistakes without fear of punishment.

**Q4**: What is the purpose of a PR template?
**Answer**: A PR template provides a checklist that authors must complete before requesting review. It ensures consistency (tests written, docs updated, security considered) and reduces back-and-forth in reviews. In Azure DevOps, add a `pull_request_template.md` to the repo root.

---

## Practical Task: Configure Branch Policies

Configure Azure DevOps branch policies on `main` to require:
- 2 reviewers
- Build validation (CI pipeline must pass)
- Comment resolution before merge

**Validation**:
```bash
# Verify branch policies are configured
az repos policy list --repository-id <repo-id> --branch main \
  --project myProject --org https://dev.azure.com/myOrg \
  --query "[].{type:type.displayName,enabled:isEnabled}"
```

---

## Rubric

### Criterion 1: Git Workflow Design
| Level | Description |
|-------|-------------|
| Exemplary (4) | Designs appropriate Git workflow for team size and release cadence. Configures branch policies, PR templates, and commit message enforcement. Explains trade-offs between GitFlow and trunk-based development. |
| Proficient (3) | Configures branch policies and PR reviews. Understands trunk-based vs. GitFlow. Minor gaps in automation. |
| Developing (2) | Configures basic branch protection but missing build validation or comment resolution. |
| Beginning (1) | Cannot configure branch policies or explain why they matter. |
