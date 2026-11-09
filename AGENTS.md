# Project Rules — Virtual Product Team

## Language
- Talk to the user in Persian (فارسی). Code, identifiers, comments, commit messages, docs inside the repo: English.

## Stack (default; change only via an ADR in docs/adr/)
- Mobile: Flutter (Dart, null-safety, Riverpod or Bloc — pick ONE in the first ADR), go_router, freezed/json_serializable.
- Backend: Supabase (Postgres, Auth, RLS, Storage, Realtime, Edge Functions). Python (FastAPI) ONLY for heavy/AI/long-running work that does not fit Edge Functions.
- CI/CD: GitHub Actions, Supabase CLI migrations, Fastlane for store delivery.

## Team (subagents live in .agents/agents/)
project-manager (lead/orchestrator) · solution-architect · ui-ux-designer · flutter-engineer · supabase-backend · python-backend · devops-cicd · test-automation · qa-lead · security-engineer · code-reviewer

## Delivery phases (project-manager drives these; never skip a gate)
0 Discovery → docs/PRD.md  | 1 Architecture → docs/ARCHITECTURE.md + docs/adr/ | 2 Design → docs/design/
3 Build (vertical slices) | 4 Verify (tests + QA + security) | 5 Release | 6 Operate/iterate
A phase is done only when its Definition of Done (below) is met and docs/STATUS.md is updated.

## Source-of-truth files
docs/PRD.md · docs/ARCHITECTURE.md · docs/adr/NNNN-title.md · docs/design/ · docs/api/ (OpenAPI / DB schema) · docs/BACKLOG.md · docs/STATUS.md · docs/test-plan.md · docs/security/ · CHANGELOG.md
Read the relevant file before working. Update it when you change reality. Never invent requirements — ask project-manager.

## Handoff format (every agent ends its work with this)
```
HANDOFF
From: <agent> → To: <agent>
Done: <what, with file paths>
Decisions: <and why; link ADR if any>
Open questions / risks:
Next action for receiver:
```

## Definition of Done (feature)
Acceptance criteria met · unit/widget/integration tests added · RLS policies + pgTAP tests for any new table · no secrets in code · lint/analyze clean · reviewed by code-reviewer · docs updated · CI green.

## Hard rules
- Never commit secrets, service_role keys, or .env files. Use env/secret managers only.
- Every table has RLS enabled in the same migration that creates it. No exceptions.
- Schema changes only via versioned migrations (supabase/migrations/). Never edit the production DB by hand.
- Small, reviewable changes. Conventional Commits. Feature branches, PRs, no direct pushes to main.
- Destructive commands (rm -rf, db reset, force push, prod deploys) need explicit user approval.
- If requirements are ambiguous, ask ONE batch of concise questions instead of guessing.
