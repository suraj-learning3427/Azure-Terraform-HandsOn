# Module 4: DevOps Fundamentals — Theory

## 1. Agile and DevOps

### 1.1 CALMS Framework
- **Culture**: Shared responsibility, blameless post-mortems, psychological safety
- **Automation**: Automate repetitive tasks (builds, tests, deployments, infrastructure)
- **Lean**: Eliminate waste, small batch sizes, fast feedback loops
- **Measurement**: Measure everything — DORA metrics, error rates, deployment frequency
- **Sharing**: Share knowledge, tools, and practices across teams

### 1.2 DORA Metrics (Key Interview Topic)
| Metric | Elite | High | Medium | Low |
|--------|-------|------|--------|-----|
| Deployment Frequency | Multiple/day | Weekly | Monthly | < Monthly |
| Lead Time for Changes | < 1 hour | 1 day–1 week | 1 week–1 month | > 1 month |
| Change Failure Rate | 0–5% | 5–10% | 10–15% | > 15% |
| Time to Restore | < 1 hour | < 1 day | 1 day–1 week | > 1 week |

### 1.3 Azure Boards
- **Work Items**: Epics → Features → User Stories → Tasks → Bugs
- **Sprints**: 2-week iterations with sprint planning, daily standups, retrospectives
- **Kanban boards**: visualize WIP, set WIP limits to prevent bottlenecks
- **Linking**: link commits, PRs, and pipeline runs to work items for traceability

---

## 2. Git Workflows

### 2.1 Trunk-Based Development (Recommended for CI/CD)
- All developers commit to `main` (trunk) frequently (at least daily)
- Short-lived feature branches (< 2 days)
- Feature flags to hide incomplete features in production
- Enables true continuous integration

### 2.2 GitFlow (Traditional)
```
main ──────────────────────────────────────────── (production releases)
  └── develop ──────────────────────────────────── (integration branch)
        ├── feature/user-auth ──── (merged to develop)
        ├── feature/payment ────── (merged to develop)
        └── release/1.2.0 ──────── (merged to main + develop)
hotfix/critical-bug ──────────────── (merged to main + develop)
```

### 2.3 GitHub Flow (Simplified)
```
main ──────────────────────────────────────────── (always deployable)
  ├── feature/add-login ──── PR → review → merge
  └── fix/null-pointer ───── PR → review → merge
```

### 2.4 Branch Policies in Azure DevOps
```bash
# Require minimum 2 reviewers on main
az repos policy approver-count create \
  --repository-id <repo-id> \
  --branch main \
  --minimum-approver-count 2 \
  --creator-vote-counts false \
  --allow-downvotes false \
  --reset-on-source-push true \
  --project myProject \
  --org https://dev.azure.com/myOrg

# Require build validation (CI must pass before merge)
az repos policy build create \
  --repository-id <repo-id> \
  --branch main \
  --build-definition-id <pipeline-id> \
  --queue-on-source-update-only false \
  --manual-queue-only false \
  --display-name "CI Build Validation" \
  --project myProject \
  --org https://dev.azure.com/myOrg
```

---

## 3. Technical Debt

### 3.1 Types of Technical Debt
- **Deliberate**: conscious shortcuts taken to meet deadlines ("we'll fix it later")
- **Inadvertent**: poor design decisions made without realizing the consequences
- **Bit rot**: code that was fine but became problematic as the system evolved

### 3.2 Measuring Technical Debt
- **Code coverage**: < 60% coverage indicates untested, risky code
- **Cyclomatic complexity**: functions with complexity > 10 are hard to maintain
- **Code duplication**: > 5% duplication indicates copy-paste programming
- **Dependency age**: outdated dependencies with known CVEs

### 3.3 Managing Technical Debt
- Allocate 20% of each sprint to debt reduction (the "20% rule")
- Track debt as work items in Azure Boards with a "TechDebt" tag
- Use SonarQube or SonarCloud to quantify and track debt over time
- Never let debt accumulate to the point where it blocks new features

---

## 4. Git Hooks and Automation

```bash
# Pre-commit hook: run linting before commit
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
npm run lint
if [ $? -ne 0 ]; then
  echo "Linting failed. Commit aborted."
  exit 1
fi
EOF
chmod +x .git/hooks/pre-commit

# Commit-msg hook: enforce conventional commits
cat > .git/hooks/commit-msg << 'EOF'
#!/bin/bash
COMMIT_MSG=$(cat "$1")
PATTERN="^(feat|fix|docs|style|refactor|test|chore)(\(.+\))?: .{1,72}$"
if ! echo "$COMMIT_MSG" | grep -qE "$PATTERN"; then
  echo "Invalid commit message. Use: feat|fix|docs|style|refactor|test|chore: description"
  exit 1
fi
EOF
chmod +x .git/hooks/commit-msg
```

---

## 5. Best Practices

- Commit small, commit often — large commits are hard to review and revert
- Write meaningful commit messages (Conventional Commits format)
- Never commit secrets — use `.gitignore` and pre-commit hooks
- Require PR reviews — at least 1 reviewer for feature branches, 2 for main
- Delete branches after merging — keep the repo clean
- Tag releases with semantic versioning (v1.2.3)
- Use `git bisect` to find the commit that introduced a bug
