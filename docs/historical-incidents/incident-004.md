# Incident 004 — Memory Growth OOM Restart During Extended Demo

> **SRE Agent Knowledge File** — Historical incident for pattern matching.

---

| Field | Value |
|---|---|
| **Incident ID** | INC-004 |
| **Date** | 2026-07-01 |
| **Severity** | P2 |
| **Duration** | 18 minutes (including restart recovery) |
| **Service** | SRE Agent Demo API |
| **Environment** | Production |
| **Root Cause** | Memory exhaustion on B1 App Service after 4 hours with `ENABLE_FAILURE_MODE=true` at 15 req/s |

---

## Impact

- **Automatic OOM restart** by App Service platform
- **Downtime:** 47 seconds during restart
- **State loss:** In-memory flag state reset to App Settings defaults after restart
- **Affected users:** All users during 47-second restart window
- **SLO impact:** 47-second availability breach + 8 minutes recovery to full traffic

---

## Timeline (UTC)

| Time | Event |
|---|---|
| 10:00 | Extended demo session started — `ENABLE_FAILURE_MODE=true` |
| 14:03 | Memory usage crossed 1.4 GB (B1 limit: 1.75 GB) |
| 14:09 | Performance counters showed GC pressure increasing |
| 14:15 | HighLatency alert fired (GC pauses causing request delays) |
| 14:17 | On-call investigated — saw memory growth in `performanceCounters` |
| 14:18 | App Service platform triggered OOM restart automatically |
| 14:18:47 | App back online after restart |
| 14:23 | Traffic fully recovered, FailedRequestRate alert cleared |
| 14:26 | Post-incident review |

---

## Detection

Alert: **HighLatency** (caused by GC pause storms before OOM).

KQL that showed memory trend:
```kql
performanceCounters
| where name == "Private Bytes"
| where timestamp > ago(5h)
| summarize avg(value)/1024/1024 as avg_mb by bin(timestamp, 10m)
| order by timestamp asc
| render timechart
```
Result: Linear memory growth from 180 MB to 1,420 MB over 4 hours.

---

## Mitigation Applied

1. App Service restarted automatically (OOM)
2. After restart, `ENABLE_FAILURE_MODE` was left at the App Settings value (`false` — correct)
3. No manual action required post-restart

---

## Long-term Remediation

- [x] Added memory warning to demo script — limit failure mode to < 2 hours per session
- [ ] TODO: Add memory alert rule (Private Bytes > 1 GB)
- [ ] TODO: Implement exception object pooling in failure simulation
- [ ] TODO: Evaluate moving to P1v2 for larger demos (2x memory)

---

## Lessons Learned

1. Exception-heavy workloads on small SKUs can cause silent memory growth that only becomes visible near OOM
2. The automatic restart was graceful — App Service handled recovery without manual intervention
3. After restart, flags reset to App Settings — a useful safety net for runaway demo sessions
4. 4 hours at 15 req/s is an extreme demo scenario — normal 10-minute demos are not at risk
