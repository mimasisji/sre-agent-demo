# Demo Script — Azure SRE Agent (10-Minute Executive Demo)

---

## Overview

This is a scripted 10-minute executive demo showing how Azure SRE Agent reduces MTTR. The narrative arc:

> *"Something broke. An alert fired. Within minutes, SRE Agent tells us exactly what happened, who is impacted, what changed, and how to fix it — without a human writing a single KQL query."*

---

## Demo Preparation — Run 3 Days Before (R4)

### Seed Historical Telemetry

Azure SRE Agent's pattern matching requires **real historical telemetry** in Application Insights, not just Markdown knowledge files. Run this at least 3 days before the executive demo:

```powershell
.\scripts\seed-telemetry.ps1 -Cycles 3
```

For a quick smoke test (completes in ~21 minutes):
```powershell
.\scripts\seed-telemetry.ps1 -Cycles 1 -Quick
```

**What the script does per cycle:**
1. Enables `ENABLE_FAILURE_MODE=true`
2. Waits 10–15 minutes (accumulates ~50–100 failed requests)
3. Disables `ENABLE_FAILURE_MODE=false`
4. Waits 30 minutes (recovery telemetry)
5. Pushes a trivial commit to rotate `DEPLOYMENT_VERSION`

**Verify after seeding:**
```kql
requests
| where success == false
| summarize count() by bin(timestamp, 1d)
| order by timestamp asc
```
Expected: At least 3 distinct error spikes across 2–3 days.

### Capture Backup Screenshots (R5)

Before the live demo, run through all 6 SRE Agent prompts during a rehearsal and capture screenshots of the responses. Save to `docs/demo-backup-screenshots/`:

| File | Content |
|---|---|
| `01-investigate-500s.png` | Response to prompt 1 |
| `02-impacted-customers.png` | Response to prompt 2 |
| `03-recent-changes.png` | Response to prompt 3 |
| `04-root-cause.png` | Response to prompt 4 |
| `05-mitigation.png` | Response to prompt 5 |
| `06-post-mortem.png` | Response to prompt 6 |

---

## Pre-Demo Checklist — 15 Minutes Before (R5)

Run through this checklist before every executive demo:

- [ ] `curl https://sredemo-mim-app.azurewebsites.net/health` returns HTTP 200
- [ ] `/health` response shows `failureMode: false, dbTimeout: false`
- [ ] Azure SRE Agent is reachable (open browser tab)
- [ ] All knowledge files show **"Indexed"** status in SRE Agent
- [ ] Azure Monitor portal open — Alerts tab visible
- [ ] Feature flags are **OFF** (`ENABLE_FAILURE_MODE=false`)
- [ ] `ADMIN_TOKEN` is in clipboard:
  ```powershell
  az webapp config appsettings list `
    -g rg-sredemo-swe -n sredemo-mim-app `
    --query "[?name=='ADMIN_TOKEN'].value" -o tsv
  ```
- [ ] `docs/demo-backup-screenshots/` open in a **hidden browser tab** (Plan B)
- [ ] Backup screenshots are current (from this week's rehearsal)

---

## The 10-Minute Script

### ACT 1 — Healthy State (0:00–1:00)

**Action:** Open `https://sredemo-mim-app.azurewebsites.net` in the browser.

**Show:** Dashboard with green traffic light, latency indicator showing "fast", both feature flag badges showing OFF.

**Say:**
> *"This is our e-commerce API. Three endpoints — products, orders, checkout. It's healthy right now: green light, fast responses. All monitoring is in place — Application Insights collecting every request, Azure Monitor watching for anomalies."*

---

### ACT 2 — Introduce the Regression (1:00–2:00)

**Action:** Click the **"Enable Failure Mode"** button on the dashboard.

**Show:** Dashboard badge flips to red "FAILURE MODE ON", latency indicator changes to "degraded".

**Say:**
> *"We just deployed a bad build — maybe a new feature introduced a regression. The dashboard shows something is wrong. Red light, degraded latency. But notice what it does NOT show — no error rates, no correlation IDs, no stack traces. The dashboard gives us a signal: something is wrong. Finding out what and why is SRE Agent's job."*

> *(This preserves the "wow" moment — the dashboard reveals the problem exists, SRE Agent reveals what the problem IS.)*

---

### ACT 3 — Alert Fires (2:00–3:00)

**Action:** Switch to Azure Monitor → Alerts tab. Show the firing alert.

**Show:** HTTP500-Spike alert in "Fired" state. Show the email notification (if present).

**Say:**
> *"Azure Monitor detected the spike in under 5 minutes. An alert fired — our on-call engineer is paged. Now, instead of manually running KQL queries and correlating logs, they hand this to Azure SRE Agent."*

---

### ACT 4 — SRE Agent Investigates (3:00–8:00)

**Action:** Open Azure SRE Agent. Type each prompt, wait for the response, narrate while it runs.

#### Prompt 1 (3:00–3:45)
```
Investigate the spike in 500 errors in the last 30 minutes.
```
**Wait for response.** **Narrate:**
> *"SRE Agent is querying Application Insights directly. It's looking at the requests table, correlating error rates with timing, identifying which endpoints are failing and when it started."*

**Highlight in response:** The exact time the errors started, the error rate percentage, which endpoints are affected.

---

#### Prompt 2 (3:45–4:30)
```
What customers are impacted by the degradation?
```
**Wait for response.** **Narrate:**
> *"Now it's telling us the blast radius — how many unique users are experiencing failures. This is the first question any executive asks: 'Who is affected?'"*

**Highlight in response:** Number of impacted sessions, geographic distribution if available.

---

#### Prompt 3 (4:30–5:30)
```
Were there any recent code changes that correlate with this incident?
```
**Wait for response.** **Narrate:**
> *"SRE Agent is cross-referencing the error spike timing with the deployment history — it reads the GitHub repository. It can see that `DEPLOYMENT_VERSION` changed just before errors started."*

**Highlight in response:** The deployment version correlation, the timing match.

---

#### Prompt 4 (5:30–6:30)
```
What is the most likely root cause?
```
**Wait for response.** **Narrate:**
> *"This is the most powerful query. SRE Agent is combining what it found in telemetry — the error patterns, the exception types, the custom dimensions — with its knowledge files: the architecture document, the known issues list, and the historical incidents. It's recognized this pattern before."*

**Highlight in response:** The `ENABLE_FAILURE_MODE` flag in `customDimensions["active.flags"]`, the match to known issue #1.

---

#### Prompt 5 (6:30–7:30)
```
Recommend immediate mitigation and long-term remediation.
```
**Wait for response.** **Narrate:**
> *"SRE Agent reads the SLO runbook — it knows the rollback procedure. It's telling us exactly what command to run right now, and what to build to prevent this from happening again."*

**Highlight in response:** The specific `az webapp config appsettings set` command, the long-term recommendations.

---

### ACT 5 — Remediate (8:00–9:00)

**Action:** Click **"Disable Failure Mode"** on the dashboard. OR run the toggle script:

```powershell
.\scripts\toggle-failure.ps1 -FailureMode $false
```

**Show:** Dashboard flips back to green. Latency shows "fast".

**Say:**
> *"30 seconds. The SRE Agent told us exactly what to do, we did it, and the service recovered immediately. No manual KQL queries, no hunting through logs, no guessing."*

---

### ACT 6 — Post-Mortem (9:00–10:00)

#### Prompt 6 (9:00–9:45)
```
Generate a complete post-incident report.
```
**Wait for response.** **Narrate:**
> *"A complete post-mortem — incident timeline, root cause, impact assessment, mitigation steps, long-term recommendations. This would take an engineer 45 minutes to write. SRE Agent generates it in seconds, ready for the incident log."*

**Closing (9:45–10:00):**
> *"That's the value of Azure SRE Agent: from alert to post-mortem in under 10 minutes. It doesn't replace the engineer — it gives them superpowers. The investigation that used to take 30–45 minutes of manual KQL and log hunting now takes 5 minutes of natural language questions."*

---

## 6 SRE Agent Prompts — Verbatim (Copy-Paste Ready)

```
1. Investigate the spike in 500 errors in the last 30 minutes.

2. What customers are impacted by the degradation?

3. Were there any recent code changes that correlate with this incident?

4. What is the most likely root cause?

5. Recommend immediate mitigation and long-term remediation.

6. Generate a complete post-incident report.
```

---

## Plan B — Screenshot Fallback (R5)

**Use this if SRE Agent is slow, unresponsive, or produces a poor response during the live demo.**

1. Switch to the hidden browser tab with `docs/demo-backup-screenshots/`
2. Open the screenshot for the prompt you just asked
3. Narrate from the pre-captured response as if it were live
4. Continue to the next prompt

**If the admin token toggle fails during the demo:**  
Azure Portal → App Service `sredemo-mim-app` → Configuration → Application settings → set `ENABLE_FAILURE_MODE=false` → Save.

**Key principle:** The audience does not need to see the agent type — they need to understand the value. Screenshots of great responses are equally compelling.

---

## Timing Tips

- Each SRE Agent prompt takes 15–45 seconds. Use that time to narrate what the agent is doing.
- If a response is too long, scroll to the summary section and highlight 2–3 key points.
- Have the Azure Monitor portal pre-loaded on a separate browser tab to switch instantly in Act 3.
- Practice the token retrieval command (`az webapp config appsettings list ...`) so it's muscle memory.

---

## Rehearsal Checklist — Run 3 Days Before

- [ ] Deploy full solution and verify health
- [ ] Run `.\.scripts\seed-telemetry.ps1 -Cycles 3`
- [ ] Verify App Insights shows ≥ 3 error spikes
- [ ] Connect SRE Agent to all resources (App Insights, LAW, GitHub, Knowledge Files)
- [ ] Run all 6 prompts — capture screenshots to `docs/demo-backup-screenshots/`
- [ ] Time yourself — confirm you complete in under 10 minutes
- [ ] Reset all flags:
  ```powershell
  .\scripts\toggle-failure.ps1 -FailureMode $false
  .\scripts\toggle-failure.ps1 -DbTimeout $false
  ```
