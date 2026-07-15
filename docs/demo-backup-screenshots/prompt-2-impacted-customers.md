# SRE Agent — Prompt 2 Response (verbatim)

> **Prompt sent to agent:** *"What customers are impacted by the degradation?"*
>
> **Captured on:** 2026-07-15 during first rehearsal run.
> **Purpose:** Screenshot backup / Plan B fallback content for live executive demo — see `docs/demo-script.md`.
>
> **What to highlight when narrating this response in the demo:**
> - The agent **does not hallucinate customer names** when the telemetry doesn't support it — this is a critical trust behavior for executive audiences
> - It cites the exact fields it inspected: `UserId`, `SessionId`, `ClientIP` — traceable and reproducible
> - It explains **why** identification failed (empty fields, masked IP) rather than saying "no data"
> - It surfaces geo signal (Gävle, Sweden) which is useful directional information even without user identity
> - Proactively offers two next moves: estimate user journeys, or add correlation for the future
>
> **Narrative recovery for demo:** *"In a production system with real authentication, this is where the agent would list impacted users with IDs. Here we see it refuses to guess — instead it names exactly which fields are missing and suggests how to fix the telemetry for next time. That's the behavior you want in an AI agent looking at a real incident."*

---

## Response

I can't identify named customers from the current telemetry.

What I do see:
- Failed traffic came from a single client source in **Gavle, Sweden**.
- `UserId` and `SessionId` are empty on the failed requests.
- `ClientIP` is masked as `0.0.0.0`, so it is not usable for customer identification.

So the impact is:
- **At least one active client/session source** was affected.
- Failures hit `POST /orders`, `POST /checkout`, and `GET /products`.
- The telemetry does **not** let me map this to specific customer accounts.

If you want, I can next estimate **how many user journeys** were affected from request patterns, or help add customer/session correlation so future incidents can identify impacted customers directly.
