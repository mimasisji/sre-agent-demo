# Incident 003 — Cold Start Spike Triggered False Alert

> **SRE Agent Knowledge File** — Historical incident for pattern matching.

---

| Field | Value |
|---|---|
| **Incident ID** | INC-003 |
| **Date** | 2026-06-25 |
| **Severity** | P3 |
| **Duration** | 2 minutes (false positive) |
| **Service** | SRE Agent Demo API |
| **Environment** | Production |
| **Root Cause** | App Service B1 cold start after deployment caused a single 11-second request that triggered the HighLatency alert |

---

## Impact

- **False positive alert** — HighLatency alert fired due to one cold-start request
- **Actual user impact:** 1 request delayed by 11 seconds; all subsequent requests normal
- **SLO impact:** None (single request, not sustained degradation)
- **On-call engineer time lost:** ~12 minutes investigating a non-issue

---

## Timeline (UTC)

| Time | Event |
|---|---|
| 16:42 | `deploy.yml` completed deployment of version `f3a9b12` |
| 16:42:31 | First request hit the cold app — 11,203ms response time |
| 16:43 | HighLatency alert fired (avg duration exceeded 2000ms threshold) |
| 16:44 | On-call engineer began investigation |
| 16:46 | KQL showed only 1 slow request, all others normal |
| 16:46 | Engineer confirmed new deployment, recognized cold start pattern |
| 16:46 | Alert resolved automatically (next evaluation window showed normal latency) |

---

## Detection

Alert: **HighLatency** (false positive).

KQL that clarified the situation:
```kql
requests
| where timestamp > ago(15m)
| extend version = tostring(customDimensions["deployment.version"])
| summarize
    count(),
    avg_latency = avg(duration),
    max_latency = max(duration),
    slow_requests = countif(duration > 2000)
  by version, bin(timestamp, 1m)
| order by timestamp asc
```
Result: Exactly 1 slow request at deployment time, all subsequent requests normal.

---

## Mitigation Applied

None required — by the time investigation completed, the app was healthy.

**Preventive action taken:**
- Added warm-up `curl` to the CI/CD smoke test step (already in `deploy.yml`)
- Warm-up request is now the first thing done after deployment

---

## Long-term Remediation

- [x] Smoke test in `deploy.yml` now sends a warm-up request before the validation `curl`
- [ ] TODO: Exclude first request after deployment from latency alerting (requires deployment event marker)
- [ ] TODO: Consider "Always On" if budget allows (Standard tier)

---

## Lessons Learned

1. Cold start pattern is recognizable: single extreme outlier at exact deployment time
2. Alert suppression window after deployment would prevent false pages
3. The 5-minute alert window makes this unavoidable on B1 — the single request saturates the average
4. This pattern is documented in `docs/known-issues.md` Issue #3
