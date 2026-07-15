# Prompt 1 — Investigate the spike in 500 errors in the last 10 minutes

**Session:** 500 Error Spike Investigation  
**Date:** 2026-07-15  
**Prompt sent:**
> *Investigate the spike in 500 errors in the last 10 minutes.*

---

## Screenshots

![Step 1 — Agent reads knowledge files and begins telemetry investigation](prompt-1-screenshot-1.png)

![Step 2 — Agent correlates telemetry with failure mode toggle and code path](prompt-1-screenshot-2.png)

![Step 3 — Agent isolates root cause: 30/75 requests failed, endpoints identified](prompt-1-screenshot-3.png)

![Step 4 — Full RCA with evidence, secondary issue, and next steps](prompt-1-screenshot-4.png)

---

## Agent Response

Primary cause: `ENABLE_FAILURE_MODE` was turned on at **2026-07-15 19:31:13 UTC**, which triggered simulated 500s on `/products`, `/orders`, and `/checkout`. It was turned back off at **2026-07-15 19:33:58 UTC**.

Impact in the last 10 minutes:
- **30 failed requests out of 75** total requests (**40%** failed).
- Failures were concentrated in app endpoints, while `/health` stayed healthy.
- Main failing routes were `POST /orders`, `POST /checkout`, and `GET /products`.

**Evidence:**
- Trace logs show `ENABLE_FAILURE_MODE set to true` at 19:31:13 UTC and `...false` at 19:33:58 UTC.
- App traces during the spike include `SIM_FAILURE_001` and `active.flags=FAILURE_MODE`.
- The behavior matches the middleware in [src/SreAgentDemo.Api/Middleware/FailureModeMiddleware.cs#L27](https://github.com/mimasis_microsoft/sre-agent-demo/blob/main/src/SreAgentDemo.Api/Middleware/FailureModeMiddleware.cs#L27), which injects failures for those three routes when the flag is enabled.
- The admin toggle endpoint is implemented in [src/SreAgentDemo.Api/Program.cs#L121](https://github.com/mimasis_microsoft/sre-agent-demo/blob/main/src/SreAgentDemo.Api/Program.cs#L121).

There is also a **secondary issue**:
- After failure mode was disabled, `POST /orders` kept returning 500s at **19:34 UTC**.
- Those later failures were `System.InvalidOperationException`, not `SimulatedFailureException`.
- The likely cause is [src/SreAgentDemo.Api/Program.cs#L97](https://github.com/mimasis_microsoft/sre-agent-demo/blob/main/src/SreAgentDemo.Api/Program.cs#L97), where the orders handler uses `ctx.Session.Id` even though session is not configured anywhere in startup.

**RCA summary:**
- **Primary trigger for the spike:** failure mode was manually enabled.
- **Contributing bug:** `/orders` has an independent runtime error that continued briefly after the flag was turned off.

**Next steps:**
- Keep `ENABLE_FAILURE_MODE=false`.
- Fix `/orders` by removing `ctx.Session.Id` usage or properly configuring session.

---

## Narration Notes (for live demo)

> *"SRE Agent is querying Application Insights directly. Notice it read the architecture and known-issues files first — it has context about how this app works before it touches a single log. It's correlating the error spike timing with the trace logs, identifying which endpoints are failing and the exact moment the failure mode flag was toggled on."*

**Highlight in the response:**
- The exact timestamps: `19:31:13` (on) → `19:33:58` (off)
- The 40% failure rate and which routes were hit
- That `/health` stayed healthy — the middleware is correctly scoped
- The secondary `ctx.Session.Id` bug — *unexpected discovery that makes the demo more authentic*

**If asked about the secondary issue:**
> *"This is the most impressive part — SRE Agent didn't just find the obvious cause (the flag). It found a latent bug in the `/orders` handler that had been there all along but was masked. This is exactly what a senior SRE would look for: 'why did orders keep failing for 1 minute after I turned the flag off?'"*
