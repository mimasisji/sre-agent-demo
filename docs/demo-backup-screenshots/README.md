# Demo Backup Screenshots

This folder contains pre-captured screenshots of Azure SRE Agent responses, taken during rehearsal runs. Use these as a **Plan B fallback** if the live SRE Agent is slow or unresponsive during the executive demo.

---

## What to Capture (During Rehearsal)

Capture one screenshot per SRE Agent prompt response. Save them with these exact filenames:

| Filename | Prompt |
|---|---|
| `01-investigate-500s.png` | "Investigate the spike in 500 errors in the last 30 minutes." |
| `02-impacted-customers.png` | "What customers are impacted by the degradation?" |
| `03-recent-changes.png` | "Were there any recent code changes that correlate with this incident?" |
| `04-root-cause.png` | "What is the most likely root cause?" |
| `05-mitigation.png` | "Recommend immediate mitigation and long-term remediation." |
| `06-post-mortem.png` | "Generate a complete post-incident report." |

---

## Screenshot Quality Checklist

For each screenshot, verify:

- [ ] The full SRE Agent response is visible (scroll to capture everything)
- [ ] The response clearly identifies the root cause (prompt 4 is the most important)
- [ ] `DEPLOYMENT_VERSION` or `ENABLE_FAILURE_MODE` is mentioned in the response (for credibility)
- [ ] The post-mortem (prompt 6) includes timeline, root cause, and recommendations
- [ ] Browser UI is clean — close other tabs, hide bookmarks bar

---

## How to Use During Live Demo

1. Before the demo, open this folder in a browser tab and minimize it
2. If SRE Agent gives a weak or slow response to any prompt:
   - Say: *"Let me pull up the response from our rehearsal run — it captures everything we found."*
   - Switch to the screenshot tab
   - Navigate to the relevant screenshot
   - Continue narrating as planned

**The audience experiences the same value — they see detailed AI-driven investigation results. Screenshots from a real rehearsal are just as compelling as a live response.**

---

## Refresh These Screenshots

Retake screenshots **within 1 week of each demo** to ensure:
- The `DEPLOYMENT_VERSION` in responses is recent
- The telemetry timestamps are plausible
- The response quality reflects the latest SRE Agent model version
