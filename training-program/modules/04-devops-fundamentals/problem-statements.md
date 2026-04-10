# Module 4: DevOps Fundamentals — Problem Statements

## Scenario A: Enterprise Git Governance

### Business Context
A 50-developer team has no branch policies. Developers push directly to main, breaking the build multiple times per week. Code reviews are optional and rarely happen. The team wants to adopt proper Git governance without slowing down development.

### Technical Requirements
1. Branch policy: no direct pushes to main
2. Require 2 reviewers for PRs to main (1 reviewer for feature branches)
3. Build validation: CI pipeline must pass before PR can be merged
4. Comment resolution: all PR comments must be resolved before merge
5. PR template with checklist: tests passing, docs updated, security reviewed
6. Conventional commit message enforcement via commit-msg hook
7. Automated PR description generation from linked work items
8. Branch naming convention: `feature/`, `fix/`, `hotfix/`, `release/`

### Constraints
- Cannot break existing developer workflows significantly
- Must work with both Azure DevOps Repos and GitHub
- Implementation must be completed within 1 sprint (2 weeks)

### Success Criteria
1. Zero direct pushes to main for 2 consecutive weeks
2. All PRs have at least 2 approvals before merge
3. CI pipeline pass rate > 95% before merge
4. Average PR review time < 4 hours
5. Build break incidents reduced from 5/week to < 1/week

---

## Scenario B: Technical Debt Reduction Sprint

### Business Context
A team has accumulated 18 months of technical debt. SonarQube reports 2,400 code smells, 45 bugs, 12 security vulnerabilities, and 8% code duplication. The team wants to systematically reduce debt while continuing to ship features.

### Technical Requirements
1. SonarQube/SonarCloud integration in CI pipeline — fail build if new issues introduced
2. Quality gate: 0 new bugs, 0 new vulnerabilities, coverage > 80% on new code
3. Debt backlog: create Azure Boards work items for all critical/high issues
4. 20% sprint capacity allocated to debt reduction
5. Track debt trend over time with SonarQube dashboard
6. Dependency scanning: identify and update packages with known CVEs

### Success Criteria
1. No new security vulnerabilities introduced in any PR
2. Code coverage on new code > 80%
3. Critical issues reduced by 50% within 3 sprints
4. All CVE-rated dependencies updated within 1 sprint
