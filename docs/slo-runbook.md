# SLO Runbook — Azure SRE Agent Demo

> **SRE Agent Knowledge File** — Upload this file to Azure SRE Agent → Knowledge Files.

---

## Service Level Objectives (SLOs)

| SLO | Target | Measurement window |
|---|---|---|
| **Availability** | ≥ 99.9% | Rolling 30 days |
| **p99 Latency** | < 500 ms | Rolling 1 hour |
| **Error Rate** | < 1% | Rolling 5 minutes |
| **MTTR** | < 15 minutes | Per incident |

### SLO Burn Rate Thresholds

| Severity | Error Rate | Action |
|---|---|---|
| **P1 — Critical** | > 30% for > 2 min | Page on-call immediately |
| **P2 — High** | > 10% for > 5 min | Alert on-call |
| **P3 — Medium** | > 1% for > 15 min | Create ticket, monitor |

---

## Alert Rules

### HTTP500-Spike (P1)
- **Trigger:** More than 5 HTTP 500 responses in any 10-minute window
- **KQL:**
  ```kql
  requests
  | where resultCode == "500"
  | summarize count() by bin(timestamp, 5m)
  | where count_ > 5
  ```
- **Action:** Page on-call, start investigation

### HighLatency (P2)
- **Trigger:** Average response time > 2000 ms over 10-minute window
- **KQL:**
  ```kql
  requests
  | summarize avg(duration) by bin(timestamp, 5m)
  | where avg_duration > 2000
  ```
- **Action:** Alert on-call, check for slow dependencies

### FailedRequestRate (P2)
- **Trigger:** Failed requests exceed 10% of total in any 10-minute window
- **KQL:**
  ```kql
  requests
  | summarize failed=countif(success==false), total=count() by bin(timestamp, 5m)
  | extend rate=todouble(failed)/total
  | where rate > 0.1
  ```
- **Action:** Alert on-call, check feature flags

---

## Immediate Response Runbook

### Step 1 — Acknowledge the alert (0–2 min)

1. Confirm alert is firing in Azure Monitor portal
2. Check current feature flag state:
   ```bash
   az webapp config appsettings list \
    -g rg-sredemo-swe -n sredemo-mim-app \
     --query "[?name=='ENABLE_FAILURE_MODE' || name=='ENABLE_DB_TIMEOUT']"
   ```
3. If either flag is `true` and you did NOT intend that — go to **Emergency Rollback** immediately.

### Step 2 — Assess scope (2–5 min)

Run these KQL queries in Application Insights (or ask Azure SRE Agent):

```kql
// How many users impacted?
requests
| where success == false
| where timestamp > ago(30m)
| summarize impacted_requests=count(), impacted_sessions=dcount(session_Id)

// Which endpoints are failing?
requests
| where success == false
| where timestamp > ago(30m)
| summarize count() by name, resultCode
| order by count_ desc
```

### Step 3 — Correlate with recent changes (5–8 min)

```kql
// Did error rate change after a deployment?
requests
| summarize
    error_rate=round(todouble(countif(success==false))/count()*100,1)
  by bin(timestamp, 5m),
     tostring(customDimensions["deployment.version"])
| order by timestamp asc
```

### Step 4 — Remediate (8–12 min)

**If ENABLE_FAILURE_MODE was accidentally left on:**
```bash
az webapp config appsettings set \
  -g rg-sredemo-swe -n sredemo-mim-app \
  --settings ENABLE_FAILURE_MODE=false
```

**If ENABLE_DB_TIMEOUT is causing retries:**
```bash
az webapp config appsettings set \
  -g rg-sredemo-swe -n sredemo-mim-app \
  --settings ENABLE_DB_TIMEOUT=false
```

**If a bad deployment is suspected — rollback via GitHub Actions:**
1. Go to GitHub → Actions → toggle-failure.yml
2. Run workflow with `enable_failure_mode=false` and `enable_db_timeout=false`

**Emergency — direct Azure CLI (no GitHub needed):**
```bash
az webapp config appsettings set \
  -g rg-sredemo-swe -n sredemo-mim-app \
  --settings ENABLE_FAILURE_MODE=false ENABLE_DB_TIMEOUT=false
```

### Step 5 — Verify recovery (12–15 min)

```bash
curl -f https://sredemo-mim-app.azurewebsites.net/health
```

Expected response:
```json
{
  "status": "healthy",
  "version": "<git-sha>",
  "flags": {
    "failureMode": false,
    "dbTimeout": false
  }
}
```

---

## Emergency Rollback

> Use this when you need to restore service in under 60 seconds.

```bash
# Disable all failure simulation immediately
az webapp config appsettings set \
  -g rg-sre-demo -n <app-name> \
  --settings ENABLE_FAILURE_MODE=false ENABLE_DB_TIMEOUT=false

# Verify health
watch -n 5 curl -s https://<app-name>.azurewebsites.net/health
```

App settings changes take effect in **< 30 seconds** without a restart.

---

## Escalation Path

| Level | Who | When | Contact |
|---|---|---|---|
| L1 On-call | Receiving the alert | Immediately on alert | PagerDuty / Teams alert |
| L2 Engineering | Senior engineer | If not resolved in 10 min | Engineering Teams channel |
| L3 Platform | Azure platform team | If infrastructure issue suspected | Azure Support ticket |

---

## MTTR Target

| Scenario | Target MTTR |
|---|---|
| Feature flag left enabled | < 5 min (single CLI command) |
| Bad deployment | < 10 min (toggle workflow) |
| Infrastructure issue | < 30 min |

---

## Post-Incident Requirements

Every P1/P2 incident requires:
1. Incident report within 24 hours
2. Root cause documented in `docs/historical-incidents/`
3. Follow-up action items with owner and due date
4. SLO impact calculated (error budget consumed)

---

## Useful References

- KQL queries: `docs/kql-queries.md`
- Known failure patterns: `docs/known-issues.md`
- Historical incidents: `docs/historical-incidents/`
- Architecture: `docs/architecture.md`
