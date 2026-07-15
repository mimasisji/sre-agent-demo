---
description: "Azure SRE Agent Demo — full end-to-end implementation (Phases 1–4 then pause for Bicep deploy, then Phases 5–9)"
---

You are an expert Azure Cloud Architect, SRE, and Full Stack Developer.

Implement the Azure SRE Agent Demo project exactly as specified below.
Work in `C:\Projects\sre-agent-demo`.
Execute phases **in order**: 1 → 2 → 3 → 4, then **stop and report** so the user can deploy Bicep manually.
Do NOT start Phase 5 until the user replies "continue" after confirming Bicep deployment succeeded.

After completing Phase 4, output exactly:
```
⏸ PAUSE — Phases 1–4 complete.

Deploy Bicep manually:
  az group create --name rg-sre-demo --location eastus2
  az deployment group create \
    --resource-group rg-sre-demo \
    --template-file infra/main.bicep \
    --parameters @infra/main.parameters.json

Retrieve ADMIN_TOKEN after deploy:
  az webapp config appsettings list \
    -g rg-sre-demo -n <app-name> \
    --query "[?name=='ADMIN_TOKEN'].value" -o tsv

Reply "continue" when deployment is validated to proceed with Phases 5–9.
```

---

# Plan: Azure SRE Agent Demo — End-to-End (v2)

**TL;DR:** Build a self-contained ASP.NET Core .NET 8 Minimal API + HTML dashboard, deploy to Azure App Service via Bicep + GitHub Actions (OIDC, no long-lived secrets), introduce a controlled regression via feature flags protected by an admin token, trigger Azure Monitor alerts, and walk Azure SRE Agent through a full incident investigation lifecycle. Estimated cost: ~$14–24/month.

---

## Phase 1 — Repository Scaffold

1. Create directory structure: `/src`, `/infra`, `/docs`, `/scripts`, `/.github/workflows`
2. `README.md` — executive quick-start with one-command deploy + **"Pre-deployment Setup" section** covering OIDC federated credential creation (R1) and admin token retrieval (R2)
3. `docs/architecture.md` — Mermaid diagram + component descriptions (SRE Agent knowledge file)
4. `docs/slo-runbook.md` — SLOs, escalation paths, rollback procedure
5. `docs/known-issues.md` — 5 known failure patterns for SRE Agent pattern matching
6. `docs/kql-queries.md` — 10+ ready-to-run KQL queries
7. `docs/demo-script.md` — 10-minute executive demo script + pre-demo checklist (R5) + rehearsal steps (R4) + Plan B fallback (R5)
8. `docs/demo-backup-screenshots/README.md` — instructions for what to capture during rehearsal (R5)

---

## Phase 2 — Backend API (`src/SreAgentDemo.Api/`)

**ASP.NET Core .NET 8 Minimal API**

### Endpoints

| Endpoint | Behavior |
|---|---|
| `GET /health` | Liveness + version + active flag state |
| `GET /products` | Simulated DB read (~50ms) |
| `POST /orders` | Simulated DB write (~80ms) |
| `POST /checkout` | Orchestrates products + orders internally |
| `POST /admin/failure-mode` | Toggle `ENABLE_FAILURE_MODE` — requires `X-Admin-Token` header (R2) |
| `POST /admin/db-timeout` | Toggle `ENABLE_DB_TIMEOUT` — requires `X-Admin-Token` header (R2) |
| `GET /admin/config` | Returns `{ adminToken, flags }` — token-protected; bootstraps dashboard JS (R2) |

### Feature flag: `ENABLE_FAILURE_MODE=true`
- 30% of requests → HTTP 500
- 3–8s artificial delay via `Task.Delay`
- Exceptions logged with: `ErrorCode`, `CorrelationId`, `DeploymentVersion`
- Slow dependency events emitted to Application Insights

### Feature flag: `ENABLE_DB_TIMEOUT=true`
- Simulated `TaskCanceledException` / `TimeoutException` on DB operations
- Polly retry policy (3 retries, exponential backoff) — retries visible in App Insights dependency telemetry
- Elevated latency logged as dependency telemetry

### Admin Token Middleware — `AdminTokenMiddleware.cs` (R2)
- Intercepts all requests to `/admin/*`
- Reads `X-Admin-Token` request header
- Compares against `ADMIN_TOKEN` environment variable using constant-time comparison
- Returns HTTP 401 with empty body if missing or mismatched — no information leak
- `GET /admin/config` bootstraps the dashboard: returns token in JSON; JS caches it in a closure (not localStorage)

> **Security note:** Demo-only. Token is a GUID generated at deploy time via Bicep `newGuid()`. Not for production.

### Observability stack
- `Microsoft.Azure.Monitor.OpenTelemetry.AspNetCore` NuGet package
- `ActivitySource` for distributed tracing on all service calls
- Serilog → Application Insights structured sink
- Custom metrics: `checkout.duration`, `db.query.duration`, `order.failure.count`
- Every request enriched with custom dimensions: `deployment.version`, `correlation.id`, `active.flags`

### Files to create
- `src/SreAgentDemo.Api/SreAgentDemo.Api.csproj`
- `src/SreAgentDemo.Api/Program.cs`
- `src/SreAgentDemo.Api/Services/ProductService.cs`
- `src/SreAgentDemo.Api/Services/OrderService.cs`
- `src/SreAgentDemo.Api/Services/CheckoutService.cs`
- `src/SreAgentDemo.Api/Middleware/FailureModeMiddleware.cs`
- `src/SreAgentDemo.Api/Middleware/DbTimeoutMiddleware.cs`
- `src/SreAgentDemo.Api/Middleware/AdminTokenMiddleware.cs`
- `src/SreAgentDemo.Api/Models/FeatureFlagState.cs`
- `src/SreAgentDemo.Api/appsettings.json`
- `src/SreAgentDemo.Tests/SreAgentDemo.Tests.csproj`
- `src/SreAgentDemo.Tests/FailureModeMiddlewareTests.cs`

---

## Phase 3 — Frontend (`src/SreAgentDemo.Api/wwwroot/index.html`) — R2 + R3

Co-hosted in the same App Service. Single vanilla HTML/JS file.

### Kept (basic health signals only — R3)
- **Traffic light** health indicator (green / yellow / red) — polls `/health` every 5s
- **Latency qualitative indicator** — shows only `"fast"` / `"slow"` / `"degraded"` (no numbers)
- **Feature flag state badge** — confirms the toggle worked for the presenter
- **"Enable Failure Mode" / "Enable DB Timeout" buttons** — calls `/admin/failure-mode` and `/admin/db-timeout`

### Intentionally removed — delegated to SRE Agent (R3)
- Error rate gauge with percentages — REMOVED
- Response time sparkline / historical chart — REMOVED
- Recent error feed with `CorrelationId` and `ErrorCode` — REMOVED
- Any structured error detail or metric history — REMOVED

### Token bootstrap (R2)
On page load, JS calls `GET /admin/config` with token from `data-admin-token` attribute injected server-side. Token held in JS closure; attached to admin calls as `X-Admin-Token` header.

> **Narrative rationale (add to demo-script.md):** *The dashboard intentionally reveals only that something is wrong ("red light"). Depth of investigation — which endpoint, which correlation IDs, which users, which deployment version — is the SRE Agent's job. This preserves the "wow" moment when the agent surfaces details the human operator cannot see at a glance.*

---

## Phase 4 — Bicep Infrastructure (`infra/`) — R1 doc refs + R2 token

```
infra/
  main.bicep
  main.parameters.json
  modules/
    loganalytics.bicep       <- PerGB2018, 30-day retention
    appinsights.bicep        <- workspace-based, linked to LAW
    appservice.bicep         <- B1 Linux, .NET 8, injects all app settings
    alerts.bicep             <- 3 scheduled query alert rules
    actiongroup.bicep        <- email action group -> mimasis@microsoft.com
```

### App Settings injected by Bicep

| Setting | Value |
|---|---|
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | from App Insights resource |
| `ENABLE_FAILURE_MODE` | `false` (default) |
| `ENABLE_DB_TIMEOUT` | `false` (default) |
| `DEPLOYMENT_VERSION` | `initial` (overwritten by CI/CD with `$GITHUB_SHA`) |
| `ADMIN_TOKEN` | `newGuid()` — fresh GUID generated at every deployment (R2) |

---

## Phase 5 — Azure Monitor Alerts + KQL

### 3 Alert Rules (free tier — first 10 rules free)

| Alert name | Logic | Frequency | Window |
|---|---|---|---|
| `HTTP500-Spike` | `requests where resultCode=="500", count > 5` | 5 min | 10 min |
| `HighLatency` | `avg duration > 2000ms` | 5 min | 10 min |
| `FailedRequestRate` | `failed/total > 10%` | 5 min | 10 min |

All alerts → Action Group → `mimasis@microsoft.com`.

### `docs/kql-queries.md` — 10+ queries

1. Root cause — correlate error spike with `DeploymentVersion` custom dimension
2. Impacted users — group failed requests by `client_IP` / `session_Id`
3. Dependency failures — downstream latency spikes with operation names
4. Exception details — `exceptions | project timestamp, type, outerMessage, customDimensions`
5. Deployment correlation — error rate before vs. after `DEPLOYMENT_VERSION` change
6. Error timeline — 1-minute buckets of 500 errors over last hour
7. Retry storms — count Polly retry events via custom dimensions
8. Slow requests — p95/p99 latency by endpoint
9. Feature flag activity — admin endpoint calls correlated with error onset
10. Full incident timeline — join requests + exceptions + dependencies on `operation_Id`

---

## Phase 6 — Knowledge Files for Azure SRE Agent

### `docs/architecture.md`
- Mermaid architecture diagram
- Components: Browser → App Service (API + wwwroot) → simulated DB (in-memory)
- Middleware chain: `AdminTokenMiddleware` → `FailureModeMiddleware` → `DbTimeoutMiddleware` → handlers
- Feature flag effect on request path (normal vs. failure mode)
- Observability: App → OpenTelemetry → Application Insights → Log Analytics Workspace

### `docs/slo-runbook.md`
- SLOs: p99 latency < 500ms | error rate < 1% | availability > 99.9%
- Immediate rollback: `az webapp config appsettings set -g rg-sre-demo -n <app> --settings ENABLE_FAILURE_MODE=false ENABLE_DB_TIMEOUT=false`
- Escalation: L1 On-call → L2 Engineering → L3 Platform
- MTTR target: < 15 min

### `docs/known-issues.md`
- Issue #1: `ENABLE_FAILURE_MODE` left `true` after rehearsal
- Issue #2: DB connection pool exhaustion under sustained load
- Issue #3: Cold start latency spike on first request after deployment
- Issue #4: Memory growth under high exception volume
- Issue #5: Correlation ID not propagated on Polly retry paths

### `docs/historical-incidents/incident-001.md` through `incident-005.md`
Each: Date | Severity | Duration | Root Cause | Timeline (UTC) | Mitigation | Remediation | Lessons Learned

### Two distinct incident artifact types (R4)

| Artifact | Location | Purpose |
|---|---|---|
| Markdown `incident-00N.md` | Uploaded as Knowledge Files | SRE Agent reads as documented patterns |
| Telemetry incidents | App Insights / Log Analytics | SRE Agent queries during live investigation |

**Both are required.** Markdown alone is insufficient.

---

## Phase 7 — GitHub Actions CI/CD — R1 OIDC throughout

### `.github/workflows/deploy.yml` (push to `main`)

```yaml
permissions:
  id-token: write
  contents: read
```

Steps: `azure/login@v2` (client-id/tenant-id/subscription-id, no creds secret) → dotnet restore → build → test → publish → `azure/webapps-deploy@v3` → set `DEPLOYMENT_VERSION=${{ github.sha }}` → smoke test `curl -f /health`

### `.github/workflows/toggle-failure.yml` (`workflow_dispatch`)

```yaml
permissions:
  id-token: write
  contents: read

inputs:
  enable_failure_mode: { type: boolean, default: false }
  enable_db_timeout:   { type: boolean, default: false }
```

Steps:
1. `azure/login@v2` (OIDC — federated credential for `environment:demo`)
2. Fetch `ADMIN_TOKEN` via `az webapp config appsettings list`
3. Set app settings via Azure CLI
4. Call `/admin/failure-mode` or `/admin/db-timeout` with `X-Admin-Token: <token>` header

### GitHub Secrets (R1 — 3 secrets, no credentials)
- `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`

---

## Phase 8 — Demo Script (`docs/demo-script.md`) — R3 + R4 + R5

### Pre-demo checklist — 15 minutes before (R5)
- ✅ `curl https://<app>.azurewebsites.net/health` → HTTP 200
- ✅ SRE Agent reachable + all knowledge files show "Indexed"
- ✅ Feature flags OFF (`ENABLE_FAILURE_MODE=false`)
- ✅ `ADMIN_TOKEN` in clipboard
- ✅ `docs/demo-backup-screenshots/` open in hidden browser tab

### 10-minute executive narrative

| Time | Act | On-screen | Talking point |
|---|---|---|---|
| 0:00–1:00 | Healthy State | Green light, "fast", flags OFF | "Our e-commerce API is healthy." |
| 1:00–2:00 | Introduce Regression | Click "Enable Failure Mode" → red, "degraded" | "We just deployed a bad build." |
| 2:00–3:00 | Alert Fires | Azure Monitor alert email / portal | "Azure Monitor caught it in under 5 minutes." |
| 3:00–8:00 | SRE Agent Investigates | Live in SRE Agent UI — 6 prompts | See prompts below |
| 8:00–9:00 | Remediate | Toggle flag off → dashboard green | "Done in 30 seconds." |
| 9:00–10:00 | Post-mortem | SRE Agent generates full report | "Ready for the incident log." |

### 6 SRE Agent prompts (verbatim)
1. `"Investigate the spike in 500 errors in the last 30 minutes."`
2. `"What customers are impacted by the degradation?"`
3. `"Were there any recent code changes that correlate with this incident?"`
4. `"What is the most likely root cause?"`
5. `"Recommend immediate mitigation and long-term remediation."`
6. `"Generate a complete post-incident report."`

### Plan B — Screenshot fallback (R5)
If SRE Agent is unresponsive → switch to `docs/demo-backup-screenshots/` → narrate from pre-captured responses.

---

## Phase 9 — Demo Rehearsal Automation (`scripts/seed-telemetry.sh`) — R4

### Purpose
Generate authentic historical telemetry in Application Insights so SRE Agent has real patterns to match against. Run 3 days before the demo.

### Script usage
```bash
chmod +x scripts/seed-telemetry.sh
./scripts/seed-telemetry.sh \
  --resource-group rg-sre-demo \
  --app-name <app-name> \
  --cycles 3
```

### Logic per cycle
1. Set `ENABLE_FAILURE_MODE=true` via Azure CLI
2. Sleep 10–15 minutes → ~50–100 failed requests
3. Set `ENABLE_FAILURE_MODE=false`
4. Sleep 30 minutes → recovery telemetry
5. Push trivial commit to `main` → rotate `DEPLOYMENT_VERSION`

Final cycle: also run with `ENABLE_DB_TIMEOUT=true`.

### Rehearsal checklist (add to `docs/demo-script.md`)
- [ ] Deploy full solution
- [ ] Run `./scripts/seed-telemetry.sh --cycles 3`
- [ ] Verify App Insights: at least 3 error spikes visible over 2–3 days
- [ ] Capture screenshots of SRE Agent responses to all 6 prompts → `docs/demo-backup-screenshots/`
- [ ] Verify knowledge files indexed in SRE Agent

---

## Pre-deployment Setup — OIDC Federated Credentials (R1)

Include verbatim in `README.md`:

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
  --scope /subscriptions/<sub-id>/resourceGroups/rg-sre-demo

# 5. Federated credential — main branch (deploy.yml)
az ad app federated-credential create --id $OBJ_ID --parameters '{
  "name": "github-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:<org>/<repo>:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}'

# 6. Federated credential — workflow_dispatch (toggle-failure.yml)
az ad app federated-credential create --id $OBJ_ID --parameters '{
  "name": "github-demo-env",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:<org>/<repo>:environment:demo",
  "audiences": ["api://AzureADTokenExchange"]
}'

# 7. GitHub secrets to add:
# AZURE_CLIENT_ID       = $APP_ID
# AZURE_TENANT_ID       = $(az account show --query tenantId -o tsv)
# AZURE_SUBSCRIPTION_ID = $(az account show --query id -o tsv)
```

---

## Azure SRE Agent — Connection Configuration

| Category | What to connect |
|---|---|
| Logs | Application Insights resource + Log Analytics Workspace |
| Azure Resources | Resource Group `rg-sre-demo` (full scope) |
| Code | GitHub repo (read access via GitHub App) |
| Knowledge Files | `architecture.md`, `slo-runbook.md`, `known-issues.md`, `incident-001.md` → `incident-005.md` |
| Incidents | 2–3 historical incidents created in SRE Agent (backed by rehearsal telemetry) |

---

## Cost Estimation (Monthly)

| Resource | SKU | Est. Cost/Month |
|---|---|---|
| App Service Plan | B1 Linux | ~$13.14 |
| Application Insights | First 5 GB free → $2.30/GB | ~$0–5 |
| Log Analytics Workspace | First 5 GB/month free | ~$0–5 |
| Azure Monitor Alerts | 3 rules (first 10 free) | $0 |
| Bandwidth / Storage | Minimal demo traffic | ~$1 |
| **Total** | | **~$14–24/month** |

> `az group delete -n rg-sre-demo --yes` — deletes everything after the demo.

---

## All 32 Files to Generate

### Source
- `src/SreAgentDemo.Api/SreAgentDemo.Api.csproj`
- `src/SreAgentDemo.Api/Program.cs`
- `src/SreAgentDemo.Api/Services/ProductService.cs`
- `src/SreAgentDemo.Api/Services/OrderService.cs`
- `src/SreAgentDemo.Api/Services/CheckoutService.cs`
- `src/SreAgentDemo.Api/Middleware/FailureModeMiddleware.cs`
- `src/SreAgentDemo.Api/Middleware/DbTimeoutMiddleware.cs`
- `src/SreAgentDemo.Api/Middleware/AdminTokenMiddleware.cs`
- `src/SreAgentDemo.Api/Models/FeatureFlagState.cs`
- `src/SreAgentDemo.Api/wwwroot/index.html`
- `src/SreAgentDemo.Api/appsettings.json`
- `src/SreAgentDemo.Tests/SreAgentDemo.Tests.csproj`
- `src/SreAgentDemo.Tests/FailureModeMiddlewareTests.cs`

### Infrastructure
- `infra/main.bicep`
- `infra/main.parameters.json`
- `infra/modules/loganalytics.bicep`
- `infra/modules/appinsights.bicep`
- `infra/modules/appservice.bicep`
- `infra/modules/alerts.bicep`
- `infra/modules/actiongroup.bicep`

### Docs
- `README.md`
- `docs/architecture.md`
- `docs/slo-runbook.md`
- `docs/known-issues.md`
- `docs/kql-queries.md`
- `docs/demo-script.md`
- `docs/demo-backup-screenshots/README.md`
- `docs/historical-incidents/incident-001.md`
- `docs/historical-incidents/incident-002.md`
- `docs/historical-incidents/incident-003.md`
- `docs/historical-incidents/incident-004.md`
- `docs/historical-incidents/incident-005.md`

### CI/CD & Scripts
- `.github/workflows/deploy.yml`
- `.github/workflows/toggle-failure.yml`
- `scripts/seed-telemetry.sh`

---

## Decisions & Scope Boundaries

| Decision | Value |
|---|---|
| Database | Fully simulated in-memory — zero Azure SQL cost |
| Admin auth | GUID token via `X-Admin-Token` (demo only, not production-ready) |
| Frontend | Served from `wwwroot` — no separate Static Web App |
| Azure SRE Agent | Not deployable via Bicep — manual setup documented in README |
| Region | `eastus2` — parameterized in `main.parameters.json` |
| Alert email | `mimasis@microsoft.com` — parameterized |
| Language | English throughout |
| Out of scope | Kubernetes, containers, multi-region, production hardening |
