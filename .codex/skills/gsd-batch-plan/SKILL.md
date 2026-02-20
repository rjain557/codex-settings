---
name: gsd-batch-plan
description: Codex-native sequential phase planning. Ensure each target phase has executable plan files before execution.
---

# Purpose
Create missing plan artifacts for a phase in a deterministic, sequential way.

# When to use
Use when a phase is pending and missing plan files, or when asked to run `$gsd-batch-plan`.

# Inputs
Expected argument: `<phase-number>`.
Optional flags:
- `--force`: Regenerate plan files even when they already exist.

# Workflow
1. Parse and validate phase number.
2. Resolve phase directory under `.planning/phases/<NN>-*`.
3. Ensure research exists for the phase.
- If missing, run `$gsd-batch-research <phase>` first.
4. Detect plan files (`<NN>-*-PLAN.md`).
- If present and `--force` is not set, report skip.
5. Create/update phase plans with atomic execution steps:
- Objective and scope
- File-level task list
- Validation steps
- Exit criteria
6. Name plans with stable ordering (`<NN>-01-PLAN.md`, `<NN>-02-PLAN.md`, ...).
7. Report created/updated files and next step (`$gsd-batch-execute <phase>`).

# Guardrails
- Plans must be executable and file-specific.
- Do not execute implementation in this skill.
- Do not leave placeholder-only plan content.
