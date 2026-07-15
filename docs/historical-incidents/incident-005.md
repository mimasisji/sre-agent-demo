# Incident 005 — Broken Distributed Traces During Retry Investigation

> **SRE Agent Knowledge File** — Historical incident for pattern matching.

---

| Field | Value |
|---|---|
| **Incident ID** | INC-005 |
| **Date** | 2026-07-08 |
| **Severity** | P3 |
| **Duration** | N/A (observability gap, not a service outage) |
| **Service** | SRE Agent Demo API |
| **Environment** | Production |
| **Root Cause** | `AsyncLocal` correlation ID not propagated to Polly retry thread, causing orphaned trace spans in Application Insights |

---

## Impact

- **No user-facing impact** — service functioned correctly
- **Observability impact:** Distributed traces were broken for all retried requests
- **Investigation difficulty:** End-to-end transaction view showed disconnected spans
- **Time lost during investigation:** 25 minutes attempting to correlate retry events manually

---

## Timeline (UTC)

| Time | Event |
|---|---|
| 11:30 | `ENABLE_DB_TIMEOUT=true` was active (intentional for demo) |
| 11:35 | Engineer opened Application Insights transaction search |
| 11:35 | Noticed retry spans had no parent `operation_Id` |
| 11:40 | Attempted end-to-end view — trace chain was broken |
| 11:45 | KQL confirmed: retry log entries missing `correlation.id` |
| 12:00 | Root cause identified: `AsyncLocal` not propagating across `Task.Run` boundary |
| 12:05 | Workaround documented — use `operation_Id` join query (Query #10 in kql-queries.md) |

---

## Detection

No alert fired — discovered during manual investigation.

KQL that revealed the gap:
```kql
traces
| where message contains "Retry"
| extend has_correlation = isnotempty(customDimensions["correlation.id"])
| summarize total=count(), missing_correlation=countif(has_correlation == false)
| extend pct_missing = round(todouble(missing_correlation)/total*100, 1)
```
Result: 100% of retry trace entries had no correlation ID.

---

## Workaround

Use `operation_Id` instead of `correlation.id` to join retry events:

```kql
let target_op = "<operation_Id from a failed request>";
union
    (requests | where operation_Id == target_op),
    (traces | where operation_Id == target_op | where message contains "Retry"),
    (dependencies | where operation_Id == target_op)
| project timestamp, itemType, name, duration, message
| order by timestamp asc
```

The `operation_Id` IS propagated correctly via `Activity.Current` — only the custom `correlation.id` dimension is missing.

---

## Mitigation Applied

No service mitigation needed.

**Investigation mitigation:** Added Query #10 (full incident timeline via operation_Id) to `docs/kql-queries.md`.

---

## Long-term Remediation

- [ ] TODO: Pass `Activity.Current` explicitly to Polly retry delegate to capture `correlation.id`
- [ ] TODO: Use `ExecutionContext.Capture()` pattern before retry block
- [ ] TODO: Add test to verify correlation ID present in retry log entries

---

## Lessons Learned

1. `AsyncLocal` values (including logging scopes) are NOT automatically propagated across thread pool boundaries
2. `Activity.Current` (OpenTelemetry trace context) IS propagated — this is why `operation_Id` works but custom scopes don't
3. The fix is a one-line capture of the correlation ID before the Polly delegate
4. This is a known .NET pattern — document it for future engineers
