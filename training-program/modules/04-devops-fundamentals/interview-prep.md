# Module 4: DevOps Fundamentals — Interview Preparation

## Q1 (Conceptual): DORA Metrics
**Question**: What are DORA metrics and why do they matter?

**Sample Answer**: DORA (DevOps Research and Assessment) metrics are four key measures of software delivery performance: Deployment Frequency (how often you deploy to production), Lead Time for Changes (time from commit to production), Change Failure Rate (% of deployments causing incidents), and Time to Restore Service (how long to recover from incidents). They matter because they're evidence-based — research shows elite performers on these metrics have 2x better commercial outcomes. They give teams an objective way to measure DevOps maturity and identify bottlenecks.

---

## Q2 (Scenario): Merge Conflict Strategy
**Question**: Your team has 10 developers all working on the same codebase. Merge conflicts are happening daily and slowing everyone down. What's your approach?

**Sample Answer**: The root cause is long-lived branches. I'd move to trunk-based development: everyone commits to main at least daily, feature branches live for < 2 days. Use feature flags to hide incomplete features in production. This eliminates most merge conflicts because there's never a large divergence between branches. For the transition: start with a team agreement on branch lifetime limits, add a CI check that fails if a branch is > 3 days old, and use feature flags for any work that takes > 1 day.

---

## Q3 (Design): Git Strategy for Regulated Industry
**Question**: A financial services client needs a Git strategy that satisfies SOX compliance — every change must be reviewed, approved, and traceable to a business requirement. How do you design this?

**Sample Answer**: 
- Branch protection on main and release branches: require 2 approvals (one from a senior engineer, one from a different team)
- Link every PR to an Azure Boards work item (enforced via branch policy)
- Signed commits: require GPG-signed commits to prove authorship
- Immutable audit trail: Azure DevOps keeps full history of PR approvals, comments, and pipeline runs
- Separate deployment approval: production deployments require a change management ticket approval
- All of this is auditable — auditors can see who approved what, when, and why

---

## Q4 (Troubleshooting): CI Pipeline Keeps Breaking
**Question**: Your CI pipeline breaks 3-4 times per week due to flaky tests. How do you address this?

**Sample Answer**: Flaky tests are a form of technical debt that erodes trust in the CI system. My approach: 1) Identify flaky tests using test analytics (Azure DevOps has built-in flaky test detection). 2) Quarantine them — move to a separate "flaky" test suite that doesn't block the build but still runs. 3) Fix or delete them — a flaky test is worse than no test because it gives false confidence. 4) Add a rule: any test that fails 3 times in 30 days without a code change is automatically quarantined. 5) Track flaky test count as a team metric and allocate time to fix them.
