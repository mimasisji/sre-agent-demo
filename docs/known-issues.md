# Known Issues — Azure SRE Agent Demo

> **SRE Agent Knowledge File** — Upload this file to Azure SRE Agent → Knowledge Files.
> This file documents recurring failure patterns so SRE Agent can match them against live incidents.

---

## Issue #1 — ENABLE_FAILURE_MODE Left Enabled After Rehearsal

**Frequency:** Common  
**Severity:** P1  
**First seen:** 2026-06-10  

### Symptoms
- HTTP 500 error rate spikes to ~30% across all endpoints
- Average latency increases to 3–8 seconds
- Exceptions in App Insights contain `ErrorCode: SIM_FAILURE_001`
- `customDimensions["active.flags"]` contains `FAILURE_MODE`

### Root Cause
The `ENABLE_FAILURE_MODE` App Service setting was set to `true` during a demo rehearsal run and was not reset before the next request traffic.

### Detection KQL
```kql
requests
| where customDimensions["active.flags"] contains "FAILURE_MODE"
| where timestamp > ago(1h)
| summarize count() by bin(timestamp, 5m)
```

### Immediate Mitigation
```bash
az webapp config appsettings set \
  -g rg-sre-demo -n <app-name> \
  --settings ENABLE_FAILURE_MODE=false
```

### Long-term Remediation
- Add a post-rehearsal checklist step that resets all flags
- Add a scheduled Azure Logic App that resets flags at midnight
- Add a `/health` response field showing active flags (already implemented — monitor it)

---

## Issue #2 — DB Connection Pool Exhaustion Under Sustained Load

**Frequency:** Rare  
**Severity:** P2  
**First seen:** 2026-06-18  

### Symptoms
- Latency degrades gradually over 10–15 minutes under sustained traffic
- `dependencies` table shows increasing `duration` for simulated DB calls
- Polly retry events appear in logs: `customDimensions["polly.retry.attempt"]`
- No hard HTTP 500s initially — just slow responses that eventually time out

### Root Cause
When `ENABLE_DB_TIMEOUT=true` is combined with high request rates, the Polly retry policy (3 retries × 3 concurrent requests) causes thread pool exhaustion. Each retry holds a slot for up to 10 seconds.

### Detection KQL
```kql
dependencies
| where type == "SimulatedDB"
| where duration > 2000
| where timestamp > ago(30m)
| summarize count(), avg(duration), max(duration) by bin(timestamp, 5m)
| order by timestamp asc
```

### Immediate Mitigation
```bash
az webapp config appsettings set \
  -g rg-sre-demo -n <app-name> \
  --settings ENABLE_DB_TIMEOUT=false
```

### Long-term Remediation
- Implement circuit breaker pattern (Polly `CircuitBreakerPolicy`)
- Add connection pool monitoring metric
- Reduce retry count from 3 to 1 for demo stability

---

## Issue #3 — Cold Start Latency Spike on First Request After Deployment

**Frequency:** Every deployment  
**Severity:** P3  
**First seen:** 2026-06-05  

### Symptoms
- First `/health` request after deployment returns in 8–15 seconds
- Subsequent requests are normal (< 200ms)
- App Insights shows a single high-latency request immediately after `DEPLOYMENT_VERSION` changes
- No errors — just a latency spike on the very first request

### Root Cause
Azure App Service B1 plan does not support "always on". After deployment, the first request must cold-start the .NET 8 process, which includes JIT compilation of the middleware pipeline.

### Detection KQL
```kql
requests
| where timestamp > ago(2h)
| extend version = tostring(customDimensions["deployment.version"])
| summarize
    first_request_latency = max(iif(row_number() == 1, duration, 0.0)),
    avg_latency = avg(duration)
  by version
```

### Immediate Mitigation
- Run a warm-up request immediately after deploy: `curl -f /health`
- The CI/CD smoke test step already does this

### Long-term Remediation
- Enable "Always On" (requires Standard or Premium App Service Plan — above demo budget)
- Implement application warm-up endpoint that pre-loads services

---

## Issue #4 — Memory Growth Under High Exception Volume

**Frequency:** Uncommon  
**Severity:** P2  
**First seen:** 2026-06-22  

### Symptoms
- App Service memory usage grows steadily over hours when `ENABLE_FAILURE_MODE=true`
- Eventually triggers OOM restart (App Service restarts automatically)
- After restart, all in-memory state (including flag state) resets to defaults from App Settings
- Memory growth rate: ~50 MB/hour under 10 req/s with 30% failure rate

### Root Cause
`System.Exception` objects created in failure simulation are large (containing stack traces). Under high load, GC pressure increases because exceptions are thrown at high frequency. The Gen2 heap grows between GC collections.

### Detection KQL
```kql
performanceCounters
| where name == "Private Bytes"
| where timestamp > ago(3h)
| summarize avg(value) by bin(timestamp, 10m)
| order by timestamp asc
```

### Immediate Mitigation
Restart the App Service to clear memory:
```bash
az webapp restart -g rg-sre-demo -n <app-name>
```

### Long-term Remediation
- Pool and reuse exception instances (not idiomatic but reduces allocation pressure)
- Reduce artificial failure rate from 30% to 10% for long-running demos
- Upgrade to at least P1v3 App Service Plan for better memory headroom

---

## Issue #5 — Correlation ID Not Propagated on Polly Retry Paths

**Frequency:** Common when ENABLE_DB_TIMEOUT=true  
**Severity:** P3  
**First seen:** 2026-06-15  

### Symptoms
- Distributed trace in Application Insights shows broken trace chains
- Retry attempts appear as orphaned operations (no parent `operation_Id`)
- `customDimensions["correlation.id"]` is missing from retry log entries
- End-to-end transaction view is fragmented

### Root Cause
The `ILogger` scope containing the correlation ID is captured in the outer request context. When Polly executes retries on a background thread (via `Task.Run`), the `AsyncLocal` scope is not automatically propagated to the new thread.

### Detection KQL
```kql
traces
| where message contains "Retry"
| where isempty(customDimensions["correlation.id"])
| where timestamp > ago(1h)
| summarize count() by bin(timestamp, 5m)
```

### Immediate Mitigation
No user-visible impact — only affects trace completeness in App Insights. No action required during demo.

### Long-term Remediation
- Pass `Activity.Current` explicitly to the Polly retry delegate
- Use `ExecutionContext.Capture()` before the retry block and restore in the delegate
- Switch to `AsyncLocal<string>` for correlation ID propagation
