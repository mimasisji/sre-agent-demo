# Incident 001 — Failure Mode Left Enabled Post-Rehearsal

> **SRE Agent Knowledge File** — Historical incident for pattern matching.

---

| Field | Value |
|---|---|
| **Incident ID** | INC-001 |
| **Date** | 2026-06-10 |
| **Severity** | P1 |
| **Duration** | 23 minutes |
| **Service** | SRE Agent Demo API |
| **Environment** | Production |
| **Root Cause** | `ENABLE_FAILURE_MODE=true` left active after rehearsal |

---

## Impact

- **Error rate:** 30% of requests returning HTTP 500
- **Affected endpoints:** `/products`, `/orders`, `/checkout`
- **Affected users:** 47 unique sessions
- **SLO impact:** 23-minute SLO breach, 0.053% availability consumed from 30-day budget

---

## Timeline (UTC)

| Time | Event |
|---|---|
| 14:15 | Demo rehearsal completed — presenter closed browser |
| 14:17 | `ENABLE_FAILURE_MODE` was NOT reset (missed checklist step) |
| 14:22 | Real traffic began hitting the API |
| 14:26 | Azure Monitor HTTP500-Spike alert fired |
| 14:27 | On-call engineer received email notification |
| 14:31 | Engineer ran KQL — saw `customDimensions["active.flags"]` = "FAILURE_MODE" |
| 14:33 | Engineer ran rollback command |
| 14:34 | Error rate dropped to 0% |
| 14:38 | Post-incident review started |

---

## Detection

Alert: **HTTP500-Spike** — 127 HTTP 500 responses in 10 minutes.

KQL that identified the cause:
```kql
requests
| where success == false
| where timestamp > ago(30m)
| project customDimensions["active.flags"], customDimensions["error.code"]
| summarize count() by tostring(customDimensions["active.flags"])
```
Result: `FAILURE_MODE` flag was active on all failed requests.

---

## Mitigation Applied

```bash
az webapp config appsettings set \
  -g rg-sre-demo -n sre-demo-app \
  --settings ENABLE_FAILURE_MODE=false
```

**Recovery time:** 28 seconds after command execution.

---

## Long-term Remediation

- [x] Added mandatory post-rehearsal checklist to `docs/demo-script.md`
- [x] Added flag state to `/health` endpoint response
- [ ] TODO: Implement nightly reset Logic App (scheduled for 2026-07-01)

---

## Lessons Learned

1. The `/health` endpoint correctly reported `failureMode: true` — but no one checked it after rehearsal
2. Alert fired correctly and within 4 minutes of degradation starting
3. KQL investigation identified root cause in under 2 minutes
4. Total MTTR was 7 minutes — within the 15-minute SLO target

---

## Recurrence Risk

**High.** This pattern will repeat before every demo unless the post-rehearsal checklist is followed. The checklist is now mandatory.
