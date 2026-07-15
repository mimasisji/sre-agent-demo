# SRE Agent — Prompt 6 Response (verbatim)

> **Prompt sent to agent:** *"Generate a complete post-incident report."*
>
> **Captured on:** 2026-07-15 during first rehearsal run.
> **Purpose:** Screenshot backup / Plan B fallback content for live executive demo — see `docs/demo-script.md`.

---

## Post-Incident Report

**Incident:** Spike in HTTP 500 errors on `sredemo-mim-app`
**Date:** July 15, 2026
**Incident window:** **19:31 UTC to 19:34 UTC**
**Severity:** Sev 2
**Status:** Mitigated

## Executive summary

Between **19:31 UTC and 19:34 UTC on July 15, 2026**, the application experienced a sharp increase in HTTP 500 responses. The primary cause was an operational configuration change that enabled `ENABLE_FAILURE_MODE`, which intentionally injects failures on `/products`, `/orders`, and `/checkout`.

The spike ended after the same flag was turned off at **19:34 UTC**. A separate pre-existing application bug caused `POST /orders` to continue returning 500s briefly after the flag was disabled.

## Customer impact

The degradation affected live request traffic to:
- `POST /orders`
- `POST /checkout`
- `GET /products`

Observed impact during the incident window:
- **30 failed requests out of 75 total**
- **40% request failure rate**
- `/health` remained healthy throughout

Customer identification was limited by telemetry gaps:
- `UserId` was empty
- `SessionId` was empty
- `ClientIP` was masked as `0.0.0.0`

What can be stated confidently:
- Failed traffic came from a single observed client source located in **Gavle, Sweden**
- Specific named customers could **not** be identified from current telemetry

## Detection

The incident was visible through request failure telemetry in Application Insights / Log Analytics. Failed requests began immediately after an app-settings write and clustered around the business endpoints listed above.

Telemetry during the spike showed:
- `SIM_FAILURE_001`
- `active.flags=FAILURE_MODE`
- `SimulatedFailureException`

## Timeline

All times UTC.

- **19:31:13** — Application log records `ENABLE_FAILURE_MODE set to true`
- **19:31–19:34** — 500 errors spike across `/products`, `/orders`, and `/checkout`
- **19:33:58** — Application log records `ENABLE_FAILURE_MODE set to false`
- **19:34:05** — App settings update completes in Azure Activity Log
- **19:34 onward** — Broad spike stops, but `POST /orders` continues to produce a smaller number of 500s briefly
- **19:52** — Investigation concluded with root cause isolated

## Root cause

**Most likely root cause:** `ENABLE_FAILURE_MODE` was manually enabled during active traffic.

This directly matches the implemented behavior in [src/SreAgentDemo.Api/Middleware/FailureModeMiddleware.cs#L27](https://github.com/mimasis_microsoft/sre-agent-demo/blob/main/src/SreAgentDemo.Api/Middleware/FailureModeMiddleware.cs#L27), where requests to `/products`, `/orders`, and `/checkout` are intentionally failed when the feature flag is enabled.

Supporting evidence:
- Azure Activity Log shows app-settings writes at **19:31 UTC** and **19:34 UTC**
- Application traces explicitly show:
  - `ENABLE_FAILURE_MODE set to true`
  - `ENABLE_FAILURE_MODE set to false`
  - `SIM_FAILURE_001`
  - `active.flags=FAILURE_MODE`
- Failure timing aligns exactly with the flag state changes

## Contributing factors

A secondary application defect extended the impact on one endpoint after the primary issue was mitigated.

The `POST /orders` endpoint continued returning 500s briefly after failure mode was disabled. The most likely cause is the handler in [src/SreAgentDemo.Api/Program.cs#L97](https://github.com/mimasis_microsoft/sre-agent-demo/blob/main/src/SreAgentDemo.Api/Program.cs#L97), which uses `ctx.Session.Id` even though session is not configured in the application startup path.

This secondary defect is consistent with the observed `System.InvalidOperationException` telemetry after failure mode was turned off.

## Was a recent code change involved?

No recent **deployed** code change correlates with the incident.

The running deployment version during the incident was:

- `c7d8077b39354cb43bfe1514e847103617000711`

That maps to commit `c7d8077` (`feat: initial implementation phases 1-9`). There was **no deployment or slot swap** during the incident window.

A newer commit existed on `main`, but it was not deployed to the app during this event. The incident correlates with a **configuration change**, not a code rollout.

## Mitigation

Immediate mitigation that resolved the main incident:
- Set `ENABLE_FAILURE_MODE=false`

Additional immediate mitigation recommended:
- Restrict or pause use of `/admin/failure-mode` during active traffic
- Verify no automation or operator workflow re-enables the flag unexpectedly
- Patch the `/orders` handler to remove reliance on session, or explicitly configure session if intended

## Long-term remediation

Recommended follow-up actions:
- Add a safeguard so failure mode cannot be enabled without expiry, approval, or auto-reset
- Add an automatic post-demo reset for failure flags
- Alert on `ENABLE_FAILURE_MODE=true`
- Alert on `SIM_FAILURE_001` occurrence
- Fix the `/orders` endpoint implementation
- Add an integration test for `POST /orders` in deployed configuration
- Separate demo/chaos controls from normal application traffic paths

## What went well

- The primary trigger was quickly isolated through telemetry correlation
- The main failure mode was reversible with a single configuration change
- `/health` remained available, which helped distinguish broad service unavailability from endpoint-specific failures

## What went poorly

- Admin/demo controls were reachable during active traffic
- Telemetry did not include usable customer identity fields
- A secondary application bug complicated the post-mitigation picture
- There was no guardrail preventing accidental or prolonged failure-mode activation

## Lessons learned

- Operational toggles that intentionally degrade service need hard safety controls
- Demo-only behavior should be isolated from normal traffic paths
- Customer impact analysis is limited without user/session correlation
- Incident analysis is faster when config changes are surfaced alongside application errors

## Action items

- Add TTL/auto-reset for failure-mode flags
- Add monitoring and alerting for failure-mode activation
- Fix the `/orders` handler session dependency
- Add end-to-end tests for critical transaction paths
- Improve telemetry to capture stable customer/session correlation where appropriate

## Final assessment

This was primarily an **operationally induced incident** caused by enabling a simulated failure flag during live traffic. The main degradation was mitigated by disabling the flag. A separate pre-existing `/orders` bug was uncovered during the same window and should be remediated to prevent residual 500s in future runs.
