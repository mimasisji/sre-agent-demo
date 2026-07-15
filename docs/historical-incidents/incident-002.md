# Incident 002 — DB Timeout Retry Storm Under Load

> **SRE Agent Knowledge File** — Historical incident for pattern matching.

---

| Field | Value |
|---|---|
| **Incident ID** | INC-002 |
| **Date** | 2026-06-18 |
| **Severity** | P2 |
| **Duration** | 41 minutes |
| **Service** | SRE Agent Demo API |
| **Environment** | Production |
| **Root Cause** | `ENABLE_DB_TIMEOUT=true` combined with load test caused thread pool exhaustion via Polly retries |

---

## Impact

- **Latency degradation:** p99 latency grew from 80ms to 12,000ms over 15 minutes
- **Error rate:** Started at 0%, reached 18% as threads exhausted
- **Affected endpoints:** `/checkout` (most impacted — calls both products and orders)
- **Affected users:** 89 unique sessions degraded
- **SLO impact:** p99 latency SLO breached for 31 minutes

---

## Timeline (UTC)

| Time | Event |
|---|---|
| 09:00 | Load test started (50 concurrent users) |
| 09:03 | `ENABLE_DB_TIMEOUT` was `true` from previous test — not noticed |
| 09:18 | Latency alert fired (p99 > 2000ms) |
| 09:19 | On-call engineer investigated — saw Polly retry logs |
| 09:26 | Suspected DB timeout flag — confirmed via app settings check |
| 09:31 | Disabled `ENABLE_DB_TIMEOUT` flag |
| 09:34 | Latency began recovering |
| 09:41 | Latency returned to normal (< 200ms p99) |

---

## Detection

Alert: **HighLatency** — average response time exceeded 2000ms.

KQL that identified the cause:
```kql
traces
| where message contains "Retry"
| where timestamp > ago(1h)
| extend retry_attempt = toint(customDimensions["polly.retry.attempt"])
| summarize count() by bin(timestamp, 5m), retry_attempt
| order by timestamp asc
```
Result: Exponential growth in retry events — 3 retries per request × 50 concurrent users = 150 simultaneous blocking DB calls.

```kql
dependencies
| where type == "SimulatedDB"
| where timestamp > ago(1h)
| summarize avg(duration), count() by bin(timestamp, 5m)
```
Result: Average DB call duration growing from 80ms to 8000ms over 15 minutes.

---

## Mitigation Applied

```bash
az webapp config appsettings set \
  -g rg-sre-demo -n sre-demo-app \
  --settings ENABLE_DB_TIMEOUT=false
```

**Recovery time:** 7 minutes after flag disabled (thread pool needed to drain).

---

## Long-term Remediation

- [x] Added `ENABLE_DB_TIMEOUT` to post-rehearsal checklist
- [ ] TODO: Add circuit breaker to DB simulation (Polly CircuitBreakerPolicy) — INC-002-REMEDIATION
- [ ] TODO: Add thread pool saturation alert

---

## Lessons Learned

1. Retry storms are invisible in error rate metrics — only latency metrics reveal them early
2. The recovery took longer than expected because threads were already exhausted when the flag was disabled
3. Load testing should always verify all flags are reset before starting
4. Correlation between load test start time and latency growth was clear in retrospect but not immediately obvious
