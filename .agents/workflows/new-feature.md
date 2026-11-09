---
description: End-to-end delivery of one feature through all team roles
---
1. project-manager: clarify the request, write/refresh the story + acceptance criteria in docs/PRD.md and docs/BACKLOG.md.
2. solution-architect: assess impact on schema/API/architecture; write or update ADR if needed.
3. ui-ux-designer: produce screen specs and states in docs/design/screens/.
4. supabase-backend (and python-backend only if justified): migrations, RLS, pgTAP tests, function contracts, regenerate types.
5. flutter-engineer: implement the slice against design + contracts, with tests.
6. test-automation: add integration/journey tests, update docs/test-plan.md.
7. security-engineer: review RLS/authz/data exposure for this feature.
8. code-reviewer: review the full change; loop back to the author until APPROVE.
9. qa-lead: verify acceptance criteria on a build, exploratory pass, report.
10. devops-cicd: confirm CI green and ship to staging.
11. project-manager: update STATUS.md, close the story, note follow-ups.
Stop and ask the user whenever a scope, cost or irreversible decision appears.
