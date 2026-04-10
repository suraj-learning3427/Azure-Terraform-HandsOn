# POC 2: CI Pipeline + VMs + Scale Sets

## Architecture

```
Developer Push → PR → Azure Pipelines CI
                        ├── Build (.NET 8)
                        ├── Unit Tests + Coverage
                        ├── SAST (SonarCloud)
                        └── Artifact → Deploy to VMSS

Terraform Provisioned:
├── Networking Module (VNet + Subnets + NSGs with dynamic rules)
├── Compute Module (VMSS min:2 max:10 + Load Balancer)
└── Database Module (Azure SQL GP_Gen5_2)
```

## Prerequisites
- Azure DevOps organization with SonarCloud service connection
- Azure subscription with Contributor access
- Terraform >= 1.5.0

## Deployment Steps

```bash
# 1. Deploy infrastructure
cd terraform
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# 2. Configure Azure DevOps pipeline
# Import azure-pipelines.yml into your Azure DevOps project
# Configure service connections: Azure subscription, SonarCloud

# 3. Trigger pipeline
git push origin main
```

## Validation Checklist
- [ ] Pipeline runs green on push to main
- [ ] Unit test results published in pipeline
- [ ] Code coverage > 80% enforced
- [ ] SonarCloud quality gate passes
- [ ] VMSS shows 2 healthy instances
- [ ] Load balancer health probe returns healthy
- [ ] Autoscale triggers on CPU > 70%
- [ ] Branch policy blocks direct push to main
