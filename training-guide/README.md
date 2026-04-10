# Azure DevOps + Terraform — Enterprise Training Guide

## How to Use This Guide

Each file = one training day. Open it, follow it top to bottom.

**Structure of every day:**
1. What you'll learn today
2. Theory (with examples and CLI commands)
3. Real-world problem statement
4. Hands-on POC steps
5. Interview Q&A for this topic

---

## Schedule

| File | Date | Presenters | Topics |
|------|------|------------|--------|
| [day-01.md](day-01.md) | Apr 7 | Varsha & Gowtham | Azure App Service + Terraform Basics |
| [day-02.md](day-02.md) | Apr 8 | Lini & Karthik | Azure SQL + Containers + Terraform State |
| [day-03.md](day-03.md) | Apr 9 | Thulasi & Swaroop | Auth, Key Vault, APIM + Terraform Advanced |
| [day-04.md](day-04.md) | Apr 14 | Sabari & Shruthi | DevOps Fundamentals + Terraform Modules |
| [day-05.md](day-05.md) | Apr 15 | Suraj & Joby | CI/CD Pipelines + Azure Infra with Terraform |
| [day-06.md](day-06.md) | Apr 16 | Varsha & Gowtham | CI/CD Deep Dive + GitHub Actions |
| [day-07.md](day-07.md) | Apr 21 | Vijay & Manju | Release Strategies + AKS with Terraform |
| [day-08.md](day-08.md) | Apr 22 | Murali & Venkat | Canary, A/B Testing + CI/CD to App Service |
| [day-09.md](day-09.md) | Apr 23 | Sabari & Shruthi | Security, Compliance + Secure Pipelines |
| [day-10.md](day-10.md) | Apr 28 | Vijay & Manju | Infrastructure + App Pipeline (Full POC) |
| [day-11.md](day-11.md) | Apr 29 | Suraj & Joby | 3-Tier Architecture + AKS GitOps |
| [day-12.md](day-12.md) | Apr 30 | Lini & Karthik | Capstone Review + Interview Preparation |

---

## Prerequisites (Complete Before Day 1)

```bash
# Install tools
az --version          # Azure CLI >= 2.50
terraform --version   # Terraform >= 1.5
kubectl version       # kubectl
helm version          # Helm >= 3.0

# Login
az login
az account set --subscription "Your Subscription"
```
