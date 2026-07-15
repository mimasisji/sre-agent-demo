# Demo Backup Screenshots — Plan B for Live Demo

**Purpose:** Verbatim responses captured from the Azure SRE Agent during rehearsal on **2026-07-15**. Use these as fallback content if, during the live executive demo, the agent is slow, unresponsive, or produces a materially worse answer.

## When to use these

- Agent takes longer than ~90 seconds on a prompt and you can feel the room drifting
- Agent output is materially worse than the rehearsal (missing citations, no timestamps, hallucinates)
- Network / portal issue mid-demo

**Do not read these verbatim.** Skim, narrate the key points in your own voice, and let the audience see the file if useful.

## Files

| Demo prompt # | Prompt (verbatim) | File |
|---|---|---|
| 1 | *Investigate the spike in 500 errors in the last 30 minutes.* | *(not captured — used to fix bug during rehearsal)* |
| 2 | *What customers are impacted by the degradation?* | [prompt-2-impacted-customers.md](prompt-2-impacted-customers.md) |
| 3 | *Were there any recent code changes that correlate with this incident?* | [prompt-3-code-changes.md](prompt-3-code-changes.md) |
| 4 | *What is the most likely root cause?* | [prompt-4-root-cause.md](prompt-4-root-cause.md) |
| 5 | *Recommend immediate mitigation and long-term remediation.* | [prompt-5-remediation.md](prompt-5-remediation.md) |
| 6 | *Generate a complete post-incident report.* | [prompt-6-post-incident-report.md](prompt-6-post-incident-report.md) |

Each file contains:
- The exact prompt sent
- The agent's verbatim response
- **Coaching notes** for the presenter — what to highlight when narrating
- A ready-to-use narrative recovery line if you have to switch to the backup mid-demo

## Pre-demo checklist (15 min before)

- [ ] Open `docs/demo-backup-screenshots/` in a hidden browser tab
- [ ] Confirm the 5 files above are present
- [ ] Bring the folder up on your machine independent of the demo laptop if possible
- [ ] Have `ADMIN_TOKEN` in your clipboard (retrievable with the command in the main `README.md`)

## When to re-capture

Re-capture every time you:
- Redeploy the app with meaningfully different code
- Re-seed telemetry (`.\scripts\seed-telemetry.ps1`) — timestamps and details will change
- Add or remove knowledge files in the SRE Agent
- Reconnect the code repository to a different branch or repo

Ideally, do a fresh rehearsal capture the morning of the demo so the timestamps in your Plan B match the timestamps the audience sees in the live App Insights blade.
