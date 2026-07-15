# SRE Agent — Prompt 5 Response (verbatim)

> **Prompt sent to agent:** *"Recommend immediate mitigation and long-term remediation."*
>
> **Captured on:** 2026-07-15 during first rehearsal run.
> **Purpose:** Screenshot backup / Plan B fallback content for live executive demo — see `docs/demo-script.md`.
>
> **What to highlight when narrating this response in the demo:**
> - **Clean two-tier structure:** immediate mitigation (what stops bleeding now) vs long-term remediation (what prevents recurrence). This is the SRE playbook standard, and the agent applies it without being told
> - **Immediate items are concrete and actionable** — each is a specific command or ownership boundary, not vague advice
> - **Security-aware mitigation:** suggests rotating the admin token if multiple operators can flip flags — shows the agent thinks about attack surface, not just availability
> - **Long-term items go beyond the fix** — guardrails, TTL, alerting, integration tests, and separation of chaos controls from prod. This is what a mature engineering org would ask for after an incident
> - **Cites line-level GitHub link** for the specific fix location — no ambiguity
> - **Proactive offer to patch:** "I can patch the `/orders` bug now and prepare the smallest safe fix" — demonstrates the agent can move from advisor to executor
>
> **Narrative for demo:** *"This is what makes this different from a chatbot. Look at the immediate list — every item is actionable in the next 15 minutes. Look at the long-term list — every item is something a mature engineering org would put in its post-mortem action tracker. And then it offers to make the fix itself. That's the difference between an assistant and an operator."*

---

## Response

Immediate mitigation:

- Keep `ENABLE_FAILURE_MODE=false` and verify no further app-setting writes are re-enabling it.
- Stop or restrict use of the `/admin/failure-mode` toggle during active traffic.
- Rotate or limit the admin token if multiple operators/scripts can flip the flag.
- If `POST /orders` is still failing after failure mode is off, hotfix and redeploy the `/orders` handler in [src/SreAgentDemo.Api/Program.cs#L97](https://github.com/mimasis_microsoft/sre-agent-demo/blob/main/src/SreAgentDemo.Api/Program.cs#L97), or temporarily avoid that route if this is just a demo flow.

Long-term remediation:

- Add a guardrail so failure mode cannot be enabled in production-like runs without expiry, approval, or auto-reset.
- Add an automatic rollback/reset job for demo flags after rehearsals.
- Add an alert on `ENABLE_FAILURE_MODE=true` and on traces containing `SIM_FAILURE_001`.
- Fix the `/orders` implementation to stop using `ctx.Session.Id` without session middleware, or explicitly configure session if that is intended.
- Add an integration test that exercises `POST /orders` in the deployed configuration.
- Separate "chaos/demo" controls from the main app, or disable those admin endpoints outside controlled test windows.

If you want, I can patch the `/orders` bug now and prepare the smallest safe fix.
