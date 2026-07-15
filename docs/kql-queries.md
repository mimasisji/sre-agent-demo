# KQL Queries — Azure SRE Agent Demo

Ready-to-run queries for Application Insights and Log Analytics. Use these during demos and incident investigations.

---

## 1. Root Cause — Correlate Error Spike with Deployment Version

```kql
requests
| where timestamp > ago(2h)
| extend version = tostring(customDimensions["deployment.version"])
| summarize
    total = count(),
    failed = countif(success == false),
    error_rate_pct = round(todouble(countif(success == false)) / count() * 100, 1)
  by bin(timestamp, 5m), version
| order by timestamp asc
```

**What to look for:** Error rate jumps after a new `deployment.version` appears.

---

## 2. Impacted Users — Group Failed Requests by Session and IP

```kql
requests
| where success == false
| where timestamp > ago(30m)
| summarize
    failed_requests = count(),
    affected_sessions = dcount(session_Id),
    affected_ips = dcount(client_IP),
    endpoints = make_set(name)
  by client_IP, session_Id
| order by failed_requests desc
| take 20
```

**What to look for:** Which users/sessions are seeing the most failures.

---

## 3. Dependency Failures — Downstream Latency Spikes

```kql
dependencies
| where timestamp > ago(30m)
| summarize
    count(),
    avg_duration_ms = avg(duration),
    p95_duration_ms = percentile(duration, 95),
    failure_count = countif(success == false)
  by name, type, bin(timestamp, 5m)
| order by timestamp asc, avg_duration_ms desc
```

**What to look for:** `SimulatedDB` dependency showing elevated latency or failures.

---

## 4. Exception Details — Full Stack with Custom Dimensions

```kql
exceptions
| where timestamp > ago(30m)
| project
    timestamp,
    error_code = tostring(customDimensions["error.code"]),
    correlation_id = tostring(customDimensions["correlation.id"]),
    deployment_version = tostring(customDimensions["deployment.version"]),
    active_flags = tostring(customDimensions["active.flags"]),
    exception_type = type,
    message = outerMessage,
    operation_id = operation_Id
| order by timestamp desc
| take 50
```

**What to look for:** `ErrorCode: SIM_FAILURE_001` appearing after a specific `deployment.version` change.

---

## 5. Deployment Correlation — Before vs. After Comparison

```kql
let before_version = "abc1234"; // replace with previous SHA
let after_version = "def5678";  // replace with current SHA
requests
| extend version = tostring(customDimensions["deployment.version"])
| where version in (before_version, after_version)
| summarize
    error_rate_pct = round(todouble(countif(success==false))/count()*100, 2),
    avg_latency_ms = round(avg(duration), 0),
    p99_latency_ms = round(percentile(duration, 99), 0),
    total_requests = count()
  by version
```

**What to look for:** Error rate or latency jump between versions.

---

## 6. Error Timeline — 1-Minute Buckets Over Last Hour

```kql
requests
| where timestamp > ago(1h)
| summarize
    total = count(),
    errors = countif(success == false),
    error_rate_pct = round(todouble(countif(success==false))/count()*100, 1)
  by bin(timestamp, 1m)
| order by timestamp asc
| render timechart
```

**What to look for:** When exactly the error rate spiked and whether it's still elevated.

---

## 7. Retry Storms — Count Polly Retry Events

```kql
traces
| where message contains "Retry"
| extend
    retry_attempt = toint(customDimensions["polly.retry.attempt"]),
    correlation_id = tostring(customDimensions["correlation.id"])
| where timestamp > ago(30m)
| summarize retry_events = count(), unique_requests = dcount(correlation_id)
    by bin(timestamp, 5m), retry_attempt
| order by timestamp asc
```

**What to look for:** Retry storm when `ENABLE_DB_TIMEOUT=true` — many retries per unique request.

---

## 8. Slow Requests — p95/p99 Latency by Endpoint

```kql
requests
| where timestamp > ago(30m)
| summarize
    p50 = round(percentile(duration, 50), 0),
    p95 = round(percentile(duration, 95), 0),
    p99 = round(percentile(duration, 99), 0),
    count = count(),
    error_rate = round(todouble(countif(success==false))/count()*100, 1)
  by name
| order by p99 desc
```

**What to look for:** `/checkout` and `/orders` showing p99 > 3000ms when failure mode is active.

---

## 9. Feature Flag Activity — Admin Calls Correlated with Error Onset

```kql
requests
| where name contains "/admin"
| where timestamp > ago(2h)
| project
    timestamp,
    endpoint = name,
    result = resultCode,
    client_ip = client_IP,
    operation_id = operation_Id
| order by timestamp desc
```

**What to look for:** A call to `/admin/failure-mode` just before the error rate spike.

---

## 10. Full Incident Timeline — Join Requests + Exceptions + Dependencies

```kql
let op_id = "<paste operation_Id here>";
union
    (requests | where operation_Id == op_id | extend item_type = "request"),
    (exceptions | where operation_Id == op_id | extend item_type = "exception"),
    (dependencies | where operation_Id == op_id | extend item_type = "dependency"),
    (traces | where operation_Id == op_id | extend item_type = "trace")
| project
    timestamp,
    item_type,
    name = coalesce(name, problemId, message),
    duration,
    success,
    customDimensions
| order by timestamp asc
```

**How to use:** Find an `operation_Id` from query #4, paste it here to see the complete timeline of a single failed request.

---

## 11. Active Failures Right Now

```kql
requests
| where success == false
| where timestamp > ago(5m)
| summarize
    count(),
    endpoints = make_set(name),
    active_flags = make_set(tostring(customDimensions["active.flags"]))
  by resultCode
```

**What to look for:** Confirm whether failures are still happening or resolved.

---

## 12. SLO Compliance Check (Last 30 Days)

```kql
requests
| where timestamp > ago(30d)
| summarize
    total = count(),
    successful = countif(success == true),
    availability_pct = round(todouble(countif(success==true)) / count() * 100, 3),
    p99_latency_ms = round(percentile(duration, 99), 0)
| extend
    slo_availability_met = availability_pct >= 99.9,
    slo_latency_met = p99_latency_ms < 500
```

**What to look for:** Both SLO flags should be `true` in steady state.
