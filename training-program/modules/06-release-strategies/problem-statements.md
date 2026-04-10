# Module 6: Release Strategies — Problem Statements

## Scenario A: Zero-Downtime Payment Processing Update

### Business Context
A financial services client needs to deploy a critical payment processing update with zero downtime, instant rollback capability if error rates exceed 0.1%, and gradual traffic shifting from 5% → 25% → 100%.

### Technical Requirements
1. Blue-green deployment using App Service deployment slots
2. Canary traffic routing: 5% → 25% → 100% with 15-minute hold at each step
3. Automated rollback: Application Insights alert triggers rollback pipeline if error rate > 0.1%
4. Database migration: backward-compatible schema changes (old code works with new schema)
5. Feature flag: new payment flow behind `NewPaymentProcessor` flag
6. Smoke tests run against staging slot before any traffic routing
7. Deployment window: only during low-traffic hours (2am-4am EST)

### Constraints
- Zero downtime — no 503 errors during deployment
- Rollback must complete in < 2 minutes
- Database rollback not possible — schema changes must be backward compatible
- Requires sign-off from Payment Team Lead before production swap

### Success Criteria
1. Zero 5xx errors during deployment (verified in Application Insights)
2. Canary at 5% for 15 minutes with error rate < 0.1%
3. Automated rollback triggers within 2 minutes of threshold breach
4. Full rollout completes within 1 hour of deployment start

---

## Scenario B: Feature Flag Governance

### Business Context
A product team wants to decouple feature releases from code deployments, enabling A/B testing of a new UI redesign and instant kill switches for problematic features without redeployment.

### Technical Requirements
1. Azure App Configuration with feature flags
2. Targeting filter: enable new UI for 10% of users, 100% for "BetaUsers" group
3. A/B test: track conversion rate for old vs. new UI in Application Insights
4. Kill switch: disable feature within 30 seconds without redeployment
5. Feature flag audit log: who changed what flag and when
6. SDK integration: .NET and React apps both read from App Configuration

### Success Criteria
1. Feature flag change takes effect within 30 seconds (no redeployment)
2. A/B test data shows statistically significant conversion rate difference
3. Kill switch disables feature for all users within 30 seconds
4. Audit log shows all flag changes with user identity and timestamp
