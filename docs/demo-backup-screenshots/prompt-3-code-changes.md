# SRE Agent — Prompt 3 Response (verbatim)

> **Prompt sent to agent:** *"Were there any recent code changes that correlate with this incident?"*
>
> **Captured on:** 2026-07-15 during first rehearsal run.
> **Purpose:** Screenshot backup / Plan B fallback content for live executive demo — see `docs/demo-script.md`.
>
> **What to highlight when narrating this response in the demo:**
> - Agent distinguishes **configuration change** from **code deployment** — a nuance senior SREs make
> - It walks the timeline: config write at 19:31 UTC → flag ON → traffic starts failing
> - It maps deployment SHA `c7d8077` back to a real commit message ("feat: initial implementation phases 1-9")
> - It **actively rules out** the newer commit `15c2cb0` that exists on `main` but was not deployed — evidence-based reasoning, not hallucinated correlation
> - It surfaces a pre-existing bug in `/orders` that was NOT the incident trigger but became visible during the investigation — proactive discovery

---

## Response

No recent **deployed code change** correlates with the spike.

What does correlate is a **configuration change**, not a code rollout:
- At **2026-07-15 19:31 UTC**, App Service app settings were updated and `ENABLE_FAILURE_MODE` was turned on.
- At **2026-07-15 19:34 UTC**, app settings were updated again and the flag was turned back off.

On the code side, the app was running deployment version `c7d8077b39354cb43bfe1514e847103617000711`, which maps to commit `c7d8077` (`feat: initial implementation phases 1-9`). I did not find any deployment or slot-swap activity in the incident window, so there's no evidence of a fresh code push causing the 19:31–19:34 UTC spike.

There is a newer repo commit on `main`, `15c2cb0`, but it does **not** appear to be deployed to the app, and its changes are small build/runtime fixes rather than anything that explains the incident. So my confidence is high that the **primary incident trigger was the failure-mode flag toggle**, not a recent code change.

One nuance: the lingering `POST /orders` 500s after the flag was turned off are consistent with a pre-existing code bug in [src/SreAgentDemo.Api/Program.cs#L97](https://github.com/mimasis_microsoft/sre-agent-demo/blob/main/src/SreAgentDemo.Api/Program.cs#L97), where the handler uses `ctx.Session.Id` even though session is not configured. That bug was already present in deployed commit `c7d8077`, so it correlates with the residual `/orders` failures, but not with a **recent** code change.

If you want, I can fix that `/orders` bug now.
