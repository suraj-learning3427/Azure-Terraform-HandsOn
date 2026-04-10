# Module 6: Release Strategies — Interview Preparation

## Q1 (Conceptual): Blue-Green vs Canary
**Question**: When would you choose blue-green over canary deployment?

**Sample Answer**: Blue-green is better when you need atomic, instant switchover — the entire traffic shifts at once. It's ideal for: major version upgrades where you can't mix old and new code, database schema changes that aren't backward compatible (though this is risky), or when you need the simplest possible rollback (just swap back). Canary is better when you want to validate with real production traffic before full rollout, when you can tolerate a small percentage of users experiencing issues, or when you want to measure business metrics (conversion rate) before committing. For most feature releases, canary is safer. For infrastructure upgrades or breaking changes, blue-green is cleaner.

---

## Q2 (Scenario): Database Migration During Blue-Green
**Question**: You're doing a blue-green deployment but the new version requires a database schema change (adding a NOT NULL column). How do you handle this?

**Sample Answer**: This is the hardest part of blue-green. The key principle: database changes must be backward compatible — old code must work with the new schema. I'd use the expand-contract pattern:

Phase 1 (Expand): Add the new column as nullable. Deploy this migration. Both old and new code work.
Phase 2 (Migrate): Deploy new application code that writes to the new column. Blue-green swap.
Phase 3 (Contract): After confirming new code is stable, add the NOT NULL constraint and remove old code paths.

This takes 3 deployments but ensures zero downtime and safe rollback at each step. Never add a NOT NULL column without a default value in a single deployment — it will break the old application version.

---

## Q3 (Design): Rollback Strategy for Microservices
**Question**: You have 10 microservices deployed via canary. Service 3 has a bug. How do you rollback just that service without affecting others?

**Sample Answer**: Each microservice should have independent deployment and rollback capability. For Service 3: 1) Immediately route 100% traffic back to the stable revision (in Container Apps: `az containerapp ingress traffic set --revision-weight stable=100 canary=0`). 2) The other 9 services continue their canary rollout unaffected. 3) Investigate the bug in Service 3, fix it, and re-deploy when ready. This is why microservices are valuable — independent deployability. The key enabler is that each service has its own deployment pipeline and traffic routing configuration.

---

## Q4 (Troubleshooting): Canary Showing False Positives
**Question**: Your canary deployment shows higher error rates than the stable version, but you suspect it's because the canary is getting more complex requests. How do you validate this?

**Sample Answer**: This is a traffic distribution problem. Check: 1) Is traffic routing truly random? App Service traffic routing uses a cookie — verify the cookie is being set correctly and not cached. 2) Segment the error analysis: compare error rates for the same API endpoints between canary and stable. If canary gets more `/checkout` calls (complex) and stable gets more `/browse` calls (simple), the comparison is unfair. 3) Use Application Insights to filter by `cloud_RoleName` and compare error rates for identical operations. 4) Consider using a synthetic load test against both versions with identical traffic patterns to get a fair comparison.
