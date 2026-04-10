# Module 6: Release Strategies — Assessment

## Knowledge Checks

**Q1**: What is the expand-contract pattern for database migrations?
**Answer**: A 3-phase approach for backward-compatible schema changes: Expand (add new column/table as nullable, both old and new code work), Migrate (deploy new code that uses the new schema), Contract (remove old schema elements after confirming new code is stable). Ensures zero downtime and safe rollback at each phase.

**Q2**: What is a feature flag kill switch?
**Answer**: A feature flag that can be disabled instantly (without redeployment) to turn off a problematic feature for all users. Essential for risky features — if something goes wrong in production, you disable the flag and the feature is gone within seconds, without a rollback deployment.

**Q3**: What metrics should trigger an automated canary rollback?
**Answer**: Error rate (HTTP 5xx), p95/p99 latency, business metrics (conversion rate, order completion rate), and custom Application Insights metrics. Define thresholds before deployment: e.g., rollback if error rate > 1% (baseline 0.1%) or p95 latency > 2x baseline for 5 consecutive minutes.

**Q4**: What is the difference between a deployment ring and a canary deployment?
**Answer**: Canary routes a percentage of random traffic to the new version. Deployment rings target specific user groups (internal → early adopters → broad users → all users) — the audience is controlled, not random. Rings are better for enterprise software where you want specific teams to validate before broader rollout.

---

## Practical Task: Implement Canary with Automated Rollback

Configure App Service traffic routing at 10% canary and create an Application Insights alert that triggers a rollback pipeline.

**Validation**:
```bash
# Verify traffic routing
az webapp traffic-routing show --name myapp --resource-group myRG
# Expected: staging=10

# Verify alert rule exists
az monitor metrics alert show --name "canary-error-rate-alert" --resource-group myRG

# Verify rollback pipeline is linked to alert action group
az monitor action-group show --name "rollback-action-group" --resource-group myRG
```

---

## Rubric

### Criterion 1: Release Strategy Selection and Implementation
| Level | Description |
|-------|-------------|
| Exemplary (4) | Selects appropriate strategy with clear justification. Implements canary with automated rollback triggers. Handles database migrations with expand-contract pattern. Uses feature flags for risky features. |
| Proficient (3) | Implements blue-green or canary correctly. Defines rollback criteria. Minor gaps in automation or database migration strategy. |
| Developing (2) | Implements basic slot swap but no canary traffic routing. Rollback is manual only. |
| Beginning (1) | Cannot implement deployment slots or explain the difference between blue-green and canary. |
