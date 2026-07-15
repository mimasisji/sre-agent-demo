# Recording Script — Azure SRE Agent Demo

**Target duration:** 10–12 minutes final cut
**Format:** Screen recording + voice-over
**Audience:** Enterprise IT decision makers (CIO, VP Engineering, Head of SRE/Ops)
**Language of narration:** English (adjust to Spanish if the audience is Latam)

> **Legend used in this script**
> - 🎬 **CUT** — natural breakpoint where you can pause/resume the recording between takes
> - 🖥️ **ON-SCREEN** — what the viewer sees
> - 🗣️ **VOICE-OVER** — what you say (verbatim; adjust naturally)
> - ⚡ **ACTION** — physical clicks / typing you do
> - 💡 **PRESENTER NOTE** — coaching for you, not on camera

---

## 0. Pre-recording setup — do this 15 minutes before recording

### 0.1 Fresh telemetry
Run this to have "recent" incident data — the agent will cite timestamps from the last few minutes, which is much more credible than 2-day-old data:

```powershell
cd C:\Projects\sre-agent-demo
.\scripts\toggle-failure.ps1 -FailureMode $false   # ensure clean baseline
.\scripts\toggle-failure.ps1 -DbTimeout $false
```

Then wait ~2 minutes for the app to stabilize before recording.

💡 Do NOT run `seed-telemetry.ps1` right before recording. You want a clean baseline in the app's `/health` for the opening shot. The failure will be introduced live on camera.

### 0.2 Browser tabs — arrange in this order (left to right)

| Tab # | URL / App | Purpose |
|---|---|---|
| 1 | `https://sredemo-mim-app.azurewebsites.net` | Show the app's index page (health signals) |
| 2 | Azure Portal — SRE Agent chat: `https://portal.azure.com/#resource/subscriptions/8e6e91bf-61fa-4262-b049-3f28f5aee367/resourceGroups/rg-sredemo-swe/providers/Microsoft.App/agents/sredemo-sre-agent` | Main demo surface |
| 3 | Azure Portal — Application Insights `sredemo-mim-ai` (Failures blade) | Cross-reference telemetry |
| 4 | `https://github.com/mimasis_microsoft/sre-agent-demo` | Repo — for when the agent cites code |
| 5 | Windows Terminal / PowerShell — cwd = `C:\Projects\sre-agent-demo` | For the toggle |

💡 In the SRE Agent tab, **start a New Chat Thread** so the recording begins with a clean slate.

### 0.3 Recording environment

- Close every notification-producing app (Teams, Outlook, Slack)
- Enable **Do Not Disturb** (Focus mode) on Windows
- Set display scale to 125–150 % so viewers can read at 1080p
- Full-screen the browser during the recording; use F11 to toggle
- Enable presentation mode / hide taskbar

### 0.4 Hydrate the admin token in your clipboard

```powershell
az webapp config appsettings list -g rg-sredemo-swe -n sredemo-mim-app --query "[?name=='ADMIN_TOKEN'].value" -o tsv | Set-Clipboard
```

You will use it once, mid-demo, to toggle failure mode.

### 0.5 Open the Plan B folder

Open a File Explorer window with `C:\Projects\sre-agent-demo\docs\demo-backup-screenshots\` on a **second monitor** (not shared on the recording). If the agent times out or produces a weaker answer, you can glance at the coaching notes without breaking flow.

---

## 🎬 CUT 1 — Cold open (0:00 – 0:30)

🖥️ **ON-SCREEN:** Full-screen the Azure Portal on Tab 2 — the SRE Agent overview with the "Configuration Overview" cards (Code ✅, Logs ✅, Azure resources ✅, Knowledge files ✅). Nothing else moving.

🗣️ **VOICE-OVER:**
> "This is Azure SRE Agent. In the next ten minutes, I'll show you how it takes an unknown production incident, investigates it end to end, correlates configuration, code, and telemetry, and writes a full post-mortem — all without a human writing a single query."

⚡ **ACTION:** Slowly pan the mouse across the four ✅ cards (Code, Logs, Azure resources, Knowledge files). Do not click.

🗣️ **VOICE-OVER (continued):**
> "The agent is already connected to a live application, its Application Insights, its Log Analytics workspace, its GitHub repository, and our runbook documentation. Let's see what happens when something breaks."

🎬 **CUT** — this is the intro, keep it under 30 seconds.

---

## 🎬 CUT 2 — Healthy baseline (0:30 – 1:15)

🖥️ **ON-SCREEN:** Switch to Tab 1 (the app URL).

⚡ **ACTION:** Refresh the page. The dashboard should show green traffic light, "fast" latency, flags OFF.

🗣️ **VOICE-OVER:**
> "This is our application — a checkout API running on Azure App Service in Sweden Central. Green light, sub-second responses, flags off. Everything healthy."

⚡ **ACTION:** Open a new tab briefly to hit `https://sredemo-mim-app.azurewebsites.net/health` and let viewers see the raw JSON response with `"status":"healthy"`. Then close that tab and return to the dashboard view.

🗣️ **VOICE-OVER:**
> "Now, let's simulate what happens in the real world. A bad configuration change is about to hit production."

🎬 **CUT**

---

## 🎬 CUT 3 — Introduce the regression (1:15 – 2:00)

🖥️ **ON-SCREEN:** Switch to Tab 5 (PowerShell).

⚡ **ACTION:** Type slowly, so viewers can read:

```powershell
.\scripts\toggle-failure.ps1 -FailureMode $true
```

Press Enter.

🗣️ **VOICE-OVER (while it runs):**
> "I'm enabling a feature flag that makes about a third of production requests fail — the kind of change a busy engineer might roll out on a Friday afternoon."

⚡ **ACTION:** When the output shows `failureMode : True`, switch to Tab 1 (the app) and refresh a few times. Some requests will now return 500s. The dashboard's traffic light should turn red.

🗣️ **VOICE-OVER:**
> "And there it is. The traffic light turns red. But the dashboard only tells you *something* is wrong. It doesn't tell you *what*, or *why*, or *who* is affected, or *how to fix it*. That's where most teams open a bridge call and start firefighting."

💡 **PRESENTER NOTE:** Do not open App Insights yet. The whole point of the demo is that the agent will do the investigation. Resist the urge to preempt it.

🎬 **CUT** — pause the recording here and take a breath before the main act.

---

## 🎬 CUT 4 — Prompt 1: Investigate (2:00 – 3:30)

🖥️ **ON-SCREEN:** Switch to Tab 2 (SRE Agent chat).

⚡ **ACTION:** In the chat input, paste this prompt exactly:

```
Investigate the spike in 500 errors in the last 10 minutes.
```

Press Enter. The agent will take 30–90 seconds. Do not talk over the "thinking" indicator — let the viewer see it work.

🗣️ **VOICE-OVER (while it thinks):**
> "I'm giving the agent one line — the same line a tired on-call engineer might type at 2 AM. Notice I'm not telling it what tools to use, what queries to run, or where to look. The agent decides that itself."

⚡ **ACTION:** When the answer appears, scroll slowly so viewers can read the key parts. Pause on the timeline (`19:31 UTC → 19:34 UTC`), the 30/75 requests, and the `SIM_FAILURE_001` evidence line.

🗣️ **VOICE-OVER:**
> "In under two minutes, the agent has: identified the exact minute the issue started, quantified the impact — 40 percent failure rate — named the three affected endpoints, cited the exact log entries as evidence, and — this one is important — it caught a *second*, unrelated bug in the orders handler that we didn't even know about."

⚡ **ACTION:** Click the GitHub deep link (`FailureModeMiddleware.cs#L27`) in the agent's response. The repo tab opens on the exact line.

🗣️ **VOICE-OVER (viewing the code):**
> "Every claim the agent made is traceable back to a line of code in your repo. This isn't a hallucination — it's forensic evidence."

⚡ **ACTION:** Return to Tab 2 (agent chat).

🎬 **CUT**

---

## 🎬 CUT 5 — Prompt 2: Customer impact (3:30 – 4:30)

⚡ **ACTION:** Paste:

```
What customers are impacted by the degradation?
```

Press Enter, wait for response.

🗣️ **VOICE-OVER (while it thinks):**
> "The next question your executives will ask: who is affected? And here's where you find out if you can trust the agent."

⚡ **ACTION:** When the answer appears, highlight the section: "I can't identify named customers from the current telemetry."

🗣️ **VOICE-OVER:**
> "Look at that. The agent refuses to guess. It tells us exactly which telemetry fields are empty — user ID, session ID, client IP — and it suggests how to fix the observability gap for next time. This is the behavior you want in a tool that leadership is going to trust with real incidents. It's honest about the limits of what the data can prove."

🎬 **CUT**

---

## 🎬 CUT 6 — Prompt 3: Recent code changes (4:30 – 5:30)

⚡ **ACTION:** Paste:

```
Were there any recent code changes that correlate with this incident?
```

Press Enter, wait for response.

🗣️ **VOICE-OVER (while it thinks):**
> "Ninety percent of production incidents come from a recent deployment. Or do they? Let's check."

⚡ **ACTION:** When the answer appears, scroll to the sentence: "No recent **deployed code change** correlates with the spike. What does correlate is a **configuration change**, not a code rollout."

🗣️ **VOICE-OVER:**
> "This is a distinction that senior SREs make and that most tools get wrong. The agent inspected the deployment history, mapped the running commit SHA to its actual commit message, and *ruled out* a newer commit on main because it hasn't been deployed. It's not guessing. It's reasoning."

🎬 **CUT**

---

## 🎬 CUT 7 — Prompt 4: Root cause (5:30 – 6:15)

⚡ **ACTION:** Paste:

```
What is the most likely root cause?
```

Press Enter, wait for response.

⚡ **ACTION:** When the answer appears, highlight the decisive first sentence.

🗣️ **VOICE-OVER:**
> "One sentence for the root cause. Three pieces of evidence. Clean separation of the primary issue from the secondary bug. That's the standard we hold incident commanders to. The agent hit it."

🎬 **CUT**

---

## 🎬 CUT 8 — Prompt 5: Mitigation (6:15 – 7:15)

⚡ **ACTION:** Paste:

```
Recommend immediate mitigation and long-term remediation.
```

Press Enter, wait for response.

⚡ **ACTION:** When the answer appears, scroll to show both sections. Pause on the last line: "If you want, I can patch the /orders bug now and prepare the smallest safe fix."

🗣️ **VOICE-OVER:**
> "Two tiers — what to do right now, and what to do so this never happens again. Notice the long-term list: guardrails, TTL on the flag, alerts, integration tests. This is what a mature engineering org puts in its post-mortem action tracker. And notice the last line — the agent is offering to make the fix itself. This is the difference between an assistant and an operator."

🎬 **CUT**

---

## 🎬 CUT 9 — Mitigate live (7:15 – 8:00)

🖥️ **ON-SCREEN:** Switch to Tab 5 (PowerShell).

⚡ **ACTION:** Type slowly:

```powershell
.\scripts\toggle-failure.ps1 -FailureMode $false
```

Press Enter.

🗣️ **VOICE-OVER:**
> "Following the agent's immediate mitigation, we disable the flag. One line."

⚡ **ACTION:** Switch to Tab 1 (app), refresh a few times. Traffic light returns to green.

🗣️ **VOICE-OVER:**
> "Service restored. Total time from incident to green: under ten minutes, most of which was the agent thinking, not humans."

🎬 **CUT**

---

## 🎬 CUT 10 — Prompt 6: Post-incident report (8:00 – 10:30)

🖥️ **ON-SCREEN:** Switch to Tab 2 (SRE Agent).

⚡ **ACTION:** Paste:

```
Generate a complete post-incident report.
```

Press Enter. This one takes the longest — up to 2 minutes.

🗣️ **VOICE-OVER (while it thinks):**
> "The last thing every team hates about incidents is writing the post-mortem. It takes hours, sometimes days, and it never happens fast enough for leadership. Watch this."

⚡ **ACTION:** When it renders, scroll slowly from top to bottom, pausing briefly at each section: Executive Summary, Customer Impact, Timeline, Root Cause, Mitigation, What Went Well, What Went Poorly, Action Items.

🗣️ **VOICE-OVER (during scroll):**
> "Sev 2 classification. Executive summary. Customer impact — with an honest note about the telemetry gaps. Timeline down to the second. Root cause with a line-level GitHub link. Immediate and long-term mitigation. What went well, what went poorly, lessons learned, action items. This is a production-quality post-mortem written in under two minutes, by a machine that read your code, your logs, and your runbooks."

⚡ **ACTION:** Stop scrolling at the "Action items" section. Do not scroll past it.

🎬 **CUT**

---

## 🎬 CUT 11 — Closing (10:30 – 11:30)

🖥️ **ON-SCREEN:** Return to the SRE Agent Overview tab (the one from CUT 1).

🗣️ **VOICE-OVER:**
> "Everything you saw today ran on a real Azure application in Sweden Central. The agent is connected to Application Insights, Log Analytics, an Azure resource group, a GitHub repository, and eight knowledge files. The whole environment costs under fifteen dollars a month to keep running."
>
> "For your customers, this means: incidents resolved faster, post-mortems that actually get written, and a permanent SRE co-pilot that never sleeps and never leaves the company."
>
> "That's Azure SRE Agent. Let's talk about your environment next."

🎬 **CUT** — end of recording.

---

## Post-recording

- [ ] Review the raw recording for hesitations, cursor jitters, and Azure Portal loading gaps
- [ ] Cut the "agent thinking" pauses to ~5 seconds each (viewers don't need to see the full 90 seconds)
- [ ] Add lower-thirds or callouts on:
  - Prompt 1 → the "40% failure rate" number
  - Prompt 1 → the GitHub deep link click
  - Prompt 3 → the "not a code change, a config change" sentence
  - Prompt 6 → the "written in under 2 minutes" claim
- [ ] Keep the total runtime at or under 10 minutes
- [ ] Add a 3-second title card at the start and a 3-second CTA card at the end
- [ ] Export at 1080p60, H.264, and share the file for review before publishing

---

## Fallback / recovery plan (if a take goes wrong)

Because this is a recording, you can re-record any individual CUT independently. If a prompt returns a weaker answer than the rehearsal:

1. Stop the recording of that segment
2. Open a new chat thread in the agent
3. Re-run the prompt
4. Splice the new segment into the recording during editing

If the agent is materially worse for a specific prompt across multiple takes:
- Use the verbatim backup in `docs/demo-backup-screenshots/prompt-N-*.md` as a visible overlay in the editor
- Narrate over a still frame using the captured response
- Only do this as a last resort — the live investigation is the point of the demo
