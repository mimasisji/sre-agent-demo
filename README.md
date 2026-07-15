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
- Contributor access to your Azure subscription

### 1 — Pre-deployment Setup (OIDC + Secrets)

> Do this **once** before first deploy. See [Pre-deployment Setup](#pre-deployment-setup) below.

### 2 — Deploy Infrastructure

```bash
az group create --name rg-sredemo-swe --location swedencentral

az deployment group create \
  --resource-group rg-sredemo-swe \
  --template-file infra/main.bicep \
  --parameters @infra/main.parameters.json
```

### 3 — Retrieve ADMIN_TOKEN

```bash
az webapp config appsettings list \
  -g rg-sredemo-swe -n sredemo-mim-app \
  --query "[?name=='ADMIN_TOKEN'].value" -o tsv
```

### 4 — Build & Deploy App Locally (optional — CI/CD does this automatically)

```bash
cd src/SreAgentDemo.Api
dotnet publish -c Release -o ./publish
az webapp deploy --resource-group rg-sredemo-swe --name sredemo-mim-app \
  --src-path ./publish --type zip
```

### 5 — Verify

```bash
curl https://sredemo-mim-app.azurewebsites.net/health
```

### 6 — Clean Up

```bash
az group delete -n rg-sredemo-swe --yes
```

---

## Pre-deployment Setup

### OIDC Federated Credentials for GitHub Actions (R1)

No long-lived secrets. GitHub authenticates to Azure via OpenID Connect.

```bash
# 1. Create App Registration
APP_ID=$(az ad app create --display-name "sre-agent-demo-github" --query appId -o tsv)

# 2. Create service principal
az ad sp create --id $APP_ID

# 3. Get object ID
OBJ_ID=$(az ad app show --id $APP_ID --query id -o tsv)

# 4. Assign Contributor to resource group
az role assignment create \
  --assignee $APP_ID \
  --role Contributor \
  --scope /subscriptions/<sub-id>/resourceGroups/rg-sredemo-swe

# 5. Federated credential — main branch (deploy.yml)
az ad app federated-credential create --id $OBJ_ID --parameters '{
  "name": "github-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:<org>/<repo>:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}'

# 6. Federated credential — workflow_dispatch for toggle-failure.yml
az ad app federated-credential create --id $OBJ_ID --parameters '{
  "name": "github-demo-env",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:<org>/<repo>:environment:demo",
  "audiences": ["api://AzureADTokenExchange"]
}'
```

### GitHub Repository Secrets

Add these **3 secrets** in your repo → Settings → Secrets → Actions:

| Secret | Value |
|---|---|
| `AZURE_CLIENT_ID` | `$APP_ID` from above |
| `AZURE_TENANT_ID` | `$(az account show --query tenantId -o tsv)` |
| `AZURE_SUBSCRIPTION_ID` | `$(az account show --query id -o tsv)` |

### GitHub Environment

Create an environment named `demo` in Settings → Environments (required for the `toggle-failure.yml` federated credential).

---

## Feature Flags

| Flag | Effect |
|---|---|
| `ENABLE_FAILURE_MODE=true` | 30% HTTP 500, 3–8s delay, structured exceptions logged |
| `ENABLE_DB_TIMEOUT=true` | Simulated DB timeouts with Polly retries (observable in App Insights) |

**Toggle via dashboard** (browser) or **GitHub Actions** (`toggle-failure.yml` workflow).

**Toggle via CLI:**
```bash
az webapp config appsettings set \
  -g rg-sredemo-swe -n sredemo-mim-app \
  --settings ENABLE_FAILURE_MODE=true
```

**Rollback (emergency):**
```bash
az webapp config appsettings set \
  -g rg-sredemo-swe -n sredemo-mim-app \
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
│   └── seed-telemetry.sh          # Rehearsal automation
└── .github/workflows/
    ├── deploy.yml                 # CI/CD
    └── toggle-failure.yml         # Manual failure toggle
```
