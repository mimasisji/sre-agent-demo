# Azure SRE Agent Demo

End-to-end demo showing how **Azure SRE Agent** reduces MTTR by investigating a live application degradation — from alert to post-mortem — in under 10 minutes.

## What This Demo Shows

| Stage | What happens |
|---|---|
| **Healthy** | ASP.NET Core e-commerce API running normally |
| **Break it** | Toggle `ENABLE_FAILURE_MODE` — 30% HTTP 500s, 3–8s latency |
| **Alert fires** | Azure Monitor detects spike in < 5 minutes |
| **SRE Agent investigates** | Root cause, impacted users, recent changes, mitigation |
| **Remediate** | Disable flag — API recovers in seconds |
| **Post-mortem** | SRE Agent generates complete incident report |

## Architecture

```
Browser ──► App Service (ASP.NET Core .NET 8)
                │
                ├── /health, /products, /orders, /checkout
                ├── /admin/failure-mode  (X-Admin-Token protected)
                ├── /admin/db-timeout    (X-Admin-Token protected)
                └── wwwroot/index.html   (health dashboard)
                │
                └──► Application Insights ──► Log Analytics Workspace
                                │
                                └──► Azure Monitor Alerts ──► email
```

## Quick Start — Deploy Everything

### Prerequisites
- Azure CLI (`az`) logged in
- .NET 8 SDK
- Contributor access to `rg-sredemo-swe`

### 1 — Deploy Infrastructure (first time only)

```powershell
az group create --name rg-sredemo-swe --location swedencentral

az deployment group create `
  --resource-group rg-sredemo-swe `
  --template-file infra/main.bicep `
  --parameters @infra/main.parameters.json
```

### 2 — Retrieve ADMIN_TOKEN

```powershell
az webapp config appsettings list `
  -g rg-sredemo-swe -n sredemo-mim-app `
  --query "[?name=='ADMIN_TOKEN'].value" -o tsv
```

### 3 — Build & Deploy

```powershell
.\scripts\deploy.ps1
```

### 4 — Verify

```powershell
Invoke-RestMethod https://sredemo-mim-app.azurewebsites.net/health
```

### 5 — Clean Up

```powershell
az group delete -n rg-sredemo-swe --yes
```

---

## Pre-deployment Setup

### OIDC Federated Credentials (Already Configured)

OIDC authentication between GitHub Actions and Azure is fully configured using a **User-Assigned Managed Identity** (no App Registration required — avoids enterprise tenant restrictions).

| Item | Value |
|---|---|
| Managed Identity | `sredemo-github-oidc` in `rg-sredemo-swe` |
| Federated cred `github-main` | `repo:mimasis_microsoft/sre-agent-demo:ref:refs/heads/main` |
| Federated cred `github-demo-env` | `repo:mimasis_microsoft/sre-agent-demo:environment:demo` |
| Role assignment | Contributor on `rg-sredemo-swe` |
| GitHub Secrets | `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` ✅ |

> **GitHub Actions are deferred** — hosted runners are disabled at the enterprise level. See `.github/workflows-disabled/README.md`.  
> **Use `scripts/deploy.ps1` for local deploys until runners are enabled.**

### Recreating the Managed Identity (if needed)

```powershell
# Create User-Assigned Managed Identity
az identity create -g rg-sredemo-swe -n sredemo-github-oidc

$MiClientId  = az identity show -g rg-sredemo-swe -n sredemo-github-oidc --query clientId -o tsv
$MiPrincipal = az identity show -g rg-sredemo-swe -n sredemo-github-oidc --query principalId -o tsv
$SubId       = az account show --query id -o tsv

# Assign Contributor on the resource group
az role assignment create --assignee $MiPrincipal --role Contributor `
  --scope "/subscriptions/$SubId/resourceGroups/rg-sredemo-swe"

# Federated credential — main branch
az identity federated-credential create `
  --identity-name sredemo-github-oidc -g rg-sredemo-swe `
  --name github-main `
  --issuer https://token.actions.githubusercontent.com `
  --subject "repo:mimasis_microsoft/sre-agent-demo:ref:refs/heads/main" `
  --audiences api://AzureADTokenExchange

# Federated credential — demo environment (toggle-failure.yml)
az identity federated-credential create `
  --identity-name sredemo-github-oidc -g rg-sredemo-swe `
  --name github-demo-env `
  --issuer https://token.actions.githubusercontent.com `
  --subject "repo:mimasis_microsoft/sre-agent-demo:environment:demo" `
  --audiences api://AzureADTokenExchange
```

### GitHub Secrets

```powershell
gh secret set AZURE_CLIENT_ID      --body $MiClientId
gh secret set AZURE_TENANT_ID      --body (az account show --query tenantId -o tsv)
gh secret set AZURE_SUBSCRIPTION_ID --body $SubId
```

---

## Feature Flags

| Flag | Effect |
|---|---|
| `ENABLE_FAILURE_MODE=true` | 30% HTTP 500, 3–8s delay, structured exceptions logged |
| `ENABLE_DB_TIMEOUT=true` | Simulated DB timeouts with Polly retries (observable in App Insights) |

**Toggle via dashboard** (browser) or **PowerShell script:**

```powershell
# Enable failure mode
.\scripts\toggle-failure.ps1 -FailureMode $true

# Disable failure mode
.\scripts\toggle-failure.ps1 -FailureMode $false

# Enable/disable DB timeout
.\scripts\toggle-failure.ps1 -DbTimeout $true
.\scripts\toggle-failure.ps1 -DbTimeout $false
```

**Rollback (emergency — Azure Portal fallback):**  
Azure Portal → App Service `sredemo-mim-app` → Configuration → set `ENABLE_FAILURE_MODE=false` and `ENABLE_DB_TIMEOUT=false`.

**Rollback via CLI:**
```powershell
az webapp config appsettings set `
  -g rg-sredemo-swe -n sredemo-mim-app `
  --settings ENABLE_FAILURE_MODE=false ENABLE_DB_TIMEOUT=false
```

---

## Azure SRE Agent Setup

Connect the following in Azure SRE Agent:

| Category | Resource |
|---|---|
| **Logs** | Application Insights + Log Analytics Workspace |
| **Azure Resources** | Resource Group `rg-sredemo-swe` |
| **Code** | This GitHub repository |
| **Knowledge Files** | `docs/architecture.md`, `docs/slo-runbook.md`, `docs/known-issues.md`, `docs/historical-incidents/*.md` |

---

## Cost Estimate (Monthly)

> **Deployed configuration:** F1 Free (Sweden Central). Actual infrastructure cost: $0/month.

| Resource | SKU | Cost |
|---|---|---|
| App Service Plan | F1 Free Linux | **$0** |
| Application Insights | First 5 GB free | ~$0–5 |
| Log Analytics Workspace | First 5 GB free | ~$0–5 |
| Azure Monitor Alerts | 3 rules (first 10 free) | $0 |
| **Total** | | **~$0–10/month** |

> **F1 Free limits:** 60 CPU min/day, 1 GB storage, no Always On, no SLA. Sufficient for demo traffic. Upgrade to B1 ($13/month) for sustained load testing.

> **Security note:** The `/admin` endpoints use a GUID token (`ADMIN_TOKEN`) generated at deploy time. This is for demo purposes only and is not a production-grade authentication mechanism.

---

## Repository Structure

```
.
├── src/
│   ├── SreAgentDemo.Api/          # ASP.NET Core .NET 8 Minimal API
│   └── SreAgentDemo.Tests/        # Unit tests
├── infra/
│   ├── main.bicep                 # Entry point
│   ├── main.parameters.json
│   └── modules/                   # Modular Bicep
├── docs/
│   ├── architecture.md            # SRE Agent knowledge file
│   ├── slo-runbook.md             # SRE Agent knowledge file
│   ├── known-issues.md            # SRE Agent knowledge file
│   ├── kql-queries.md             # Ready-to-run KQL
│   ├── demo-script.md             # 10-min executive script
│   ├── demo-backup-screenshots/   # Plan B screenshots
│   └── historical-incidents/      # SRE Agent knowledge files
├── scripts/
│   ├── deploy.ps1                 # Build + zip deploy to Azure
│   ├── toggle-failure.ps1         # Toggle FAILURE_MODE / DB_TIMEOUT flags
│   ├── seed-telemetry.ps1         # Pre-demo telemetry seeding (PowerShell)
│   └── seed-telemetry.sh          # Legacy bash version (Linux/macOS)
└── .github/
    ├── workflows-disabled/        # CI/CD (deferred — enterprise runners blocked)
    │   ├── deploy.yml
    │   ├── toggle-failure.yml
    │   └── README.md
    └── workflows/                 # Empty — workflows moved to workflows-disabled
```
