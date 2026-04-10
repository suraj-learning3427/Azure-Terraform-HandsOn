# Module 5: CI/CD Pipelines — Problem Statements

## Scenario A: Multi-Stage Enterprise Pipeline

### Business Context
A team needs a pipeline that builds a .NET 8 application, runs unit tests with coverage enforcement, performs SAST scanning, publishes artifacts, deploys to dev/staging/prod with approval gates, and sends Teams notifications on failure.

### Technical Requirements
1. Azure Pipelines YAML with 4 stages: Build → Test → Deploy Staging → Deploy Production
2. Unit tests with minimum 80% code coverage (fail build if below threshold)
3. SonarCloud SAST scan — fail if new critical/blocker issues introduced
4. Trivy container image scan — fail if HIGH/CRITICAL CVEs found
5. Staging deployment: automatic after successful build
6. Production deployment: requires manual approval from "Release Managers" group
7. Deployment window check: production deployments only allowed Mon-Fri 9am-5pm EST
8. Teams notification on pipeline failure with link to failed stage
9. Artifact retention: 30 days for staging artifacts, 90 days for production

### Success Criteria
1. Pipeline completes in < 15 minutes for CI stages
2. Coverage gate blocks merge if coverage drops below 80%
3. SonarCloud quality gate visible in PR comments
4. Production deployment blocked outside business hours
5. Teams notification received within 2 minutes of failure

---

## Scenario B: GitHub Actions Migration from Jenkins

### Business Context
A team using Jenkins needs to migrate to GitHub Actions, maintaining all existing quality gates, test integrations, and deployment approvals. Jenkins has 15 pipelines with shared libraries.

### Technical Requirements
1. Migrate 15 Jenkins pipelines to GitHub Actions workflows
2. Convert Jenkins shared libraries to reusable GitHub Actions workflows
3. Maintain all existing quality gates (SonarQube, test coverage, security scans)
4. Implement OIDC authentication to Azure (replace stored service principal secrets)
5. Environment protection rules for production (require 2 approvals)
6. Matrix strategy: run tests on Node 18, 20, and 22 in parallel
7. Workflow dispatch: allow manual triggering with environment selection

### Success Criteria
1. All 15 pipelines migrated and passing
2. No stored Azure credentials — OIDC only
3. Build time equal to or better than Jenkins
4. All quality gates maintained
