---
name: gsd-sdlc-review
description: Codex-native SDLC code review. Generate review reports with a parseable health score and prioritized remediation findings.
---

# Purpose
Run SDLC review and produce remediation-grade reports used by auto-dev loops.

# When to use
Use when asked for `$gsd-sdlc-review`, or when a remediation loop needs a fresh health score and findings.

# Inputs
Optional argument:
- `--layer=frontend|backend|database|auth`

# Workflow
1. Determine scope from `--layer`; default is full-project review.
2. Read project context:
- `.planning/STATE.md` (if present)
- `.planning/ROADMAP.md` (if present)
- `docs/sdlc/phase.g.codedebugger/code-debugger.md` (if present)
3. Inspect repository and assess findings by severity (BLOCKER/HIGH/MEDIUM/LOW).
4. Run relevant build/typecheck checks for reviewed scope when feasible.
5. Generate/update review artifacts:
- `docs/review/EXECUTIVE-SUMMARY.md`
- `docs/review/FULL-REPORT.md`
- `docs/review/DEVELOPER-HANDOFF.md`
- `docs/review/PRIORITIZED-TASKS.md`
6. Ensure executive summary includes parseable health line in `X/100` form.
7. Return concise summary with top risks and next remediation actions.

# Guardrails
- Do not skip artifact generation.
- Do not report clean status without writing updated evidence.
- Keep severity mapping and findings IDs stable across iterations when possible.
