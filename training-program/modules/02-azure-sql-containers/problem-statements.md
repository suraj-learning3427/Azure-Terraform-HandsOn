# Module 2: Azure SQL + Containers — Problem Statements

## Scenario A: Financial Data Platform

### Business Context
FinBank needs a SQL database with encryption at rest, dynamic masking for PII (SSN, credit card numbers), geo-replication to a secondary region, and automated compliance reporting for SOC 2 audits.

### Technical Requirements
1. Azure SQL Database with Transparent Data Encryption (TDE) enabled
2. Dynamic Data Masking on columns: SSN, credit_card, email, phone_number
3. Active geo-replication with failover group to secondary region (West US 2)
4. Automated backups with 35-day long-term retention
5. Always Encrypted for SSN column (client-side encryption)
6. Azure Defender for SQL enabled for threat detection
7. Private endpoint — no public internet access
8. Auditing to Log Analytics workspace

### Constraints
- RTO: 30 seconds, RPO: 5 seconds
- Data must remain in US regions only (data residency)
- No public endpoint — private endpoint only
- Monthly cost must not exceed $800

### Success Criteria
1. TDE enabled and verified via `az sql db show`
2. Dynamic masking rules applied — non-privileged users see masked data
3. Failover group successfully fails over and fails back within 30 seconds
4. Backup retention set to 35 days
5. Private endpoint resolves correctly from VNet
6. Defender for SQL alerts fire on simulated SQL injection attempt

### Azure Services
- Azure SQL Database (General Purpose, 4 vCores): ~$370/month; scales to 8 vCores on demand
- Azure Key Vault (Standard): ~$5/month; stores Always Encrypted column master key
- Log Analytics Workspace: ~$30/month for audit logs

---

## Scenario B: Microservices Containerization

### Business Context
A SaaS company needs to containerize 5 microservices, store images in a private registry with geo-replication, and deploy them as a scalable container application with traffic splitting between revisions for safe rollouts.

### Technical Requirements
1. Azure Container Registry (ACR) Premium with geo-replication to two regions
2. Multi-stage Dockerfiles for each microservice (build stage + runtime stage)
3. ACR Tasks to automatically build images on git push
4. Azure Container Apps environment with 5 microservices deployed
5. Traffic splitting: 80% stable revision / 20% canary revision
6. KEDA-based scaling: scale to zero when no traffic, scale out on HTTP requests
7. Dapr sidecar for service-to-service communication and state management
8. Managed Identity for ACR pull (no registry credentials stored)

### Constraints
- Images must be scanned for vulnerabilities before deployment (Defender for Containers)
- No registry admin credentials — use Managed Identity only
- Container Apps must scale to zero during off-hours to minimize cost
- Total monthly cost at baseline: under $500

### Success Criteria
1. All 5 microservices running in Container Apps with health checks passing
2. Traffic split verified: 20% of requests routed to canary revision
3. Scale-to-zero confirmed: 0 replicas after 5 minutes of no traffic
4. ACR geo-replication active in both regions
5. Vulnerability scan passes before image is deployed
6. Dapr service invocation working between microservices

### Azure Services
- ACR Premium: ~$175/month; geo-replication included
- Azure Container Apps: ~$0.000024/vCPU-second; scale-to-zero = near-zero cost at idle
- Azure Container Apps Environment: ~$0.028/vCPU-hour for dedicated workload profiles
