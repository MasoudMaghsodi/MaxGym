---
description: Triage and fix a bug with a regression test
---
1. qa-lead: reproduce, document steps/expected/actual, assign severity.
2. solution-architect: only if the root cause is architectural.
3. Owning engineer (flutter-engineer / supabase-backend / python-backend): write a failing test first, then fix.
4. security-engineer: review if it touches auth, data access or secrets.
5. code-reviewer: review. 6. qa-lead: verify the fix and neighbors. 7. project-manager: update BACKLOG/STATUS and CHANGELOG.
