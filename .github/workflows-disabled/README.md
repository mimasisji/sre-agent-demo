# GitHub Actions Workflows — Deferred

These workflows are fully implemented and ready to use, but are currently **disabled** because GitHub Enterprise hosted runners are blocked at the enterprise level (`GitHub Actions hosted runners are disabled for this repository`).

## Workflows

| File | Trigger | Purpose |
|---|---|---|
| `deploy.yml` | Push to `main` | Build, test, publish, deploy to Azure App Service |
| `toggle-failure.yml` | `workflow_dispatch` | Toggle `ENABLE_FAILURE_MODE` / `ENABLE_DB_TIMEOUT` via OIDC |

## OIDC Setup (Already Completed)

The Azure infrastructure for OIDC authentication is already in place:

- **User-Assigned Managed Identity:** `sredemo-github-oidc` in `rg-sredemo-swe`
- **Federated credential `github-main`:** bound to `repo:mimasis_microsoft/sre-agent-demo:ref:refs/heads/main`
- **Federated credential `github-demo-env`:** bound to `repo:mimasis_microsoft/sre-agent-demo:environment:demo`
- **Role assignment:** Contributor on `rg-sredemo-swe`
- **GitHub Secrets configured:** `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`

## To Enable

Ask your GitHub Enterprise admin to enable hosted runners for this repository (or organization). Once enabled, move these files back to `.github/workflows/` and the pipelines will work immediately.

## In the Meantime

Use the local PowerShell scripts in `scripts/`:

```powershell
# Deploy
.\scripts\deploy.ps1

# Toggle failure mode
.\scripts\toggle-failure.ps1 -FailureMode $true
.\scripts\toggle-failure.ps1 -FailureMode $false

# Seed telemetry (3 days before demo)
.\scripts\seed-telemetry.ps1 -Cycles 3
```
