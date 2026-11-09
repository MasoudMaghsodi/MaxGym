---
description: Release checklist from release candidate to production
---
1. project-manager: freeze scope, confirm release notes and version.
2. qa-lead: run regression + sign-off checklist (docs/release-checklist.md); report GO/NO-GO.
3. security-engineer: final review; no open Critical/High.
4. devops-cicd: verify staging migrations on a prod-like copy, take a production backup, confirm rollback plan.
5. ASK THE USER for explicit approval to deploy to production.
6. devops-cicd: tag, run release pipeline, staged rollout (5% → 50% → 100%).
7. qa-lead + devops-cicd: monitor crashes/errors for 24–48h; project-manager reports outcome and opens follow-ups.
