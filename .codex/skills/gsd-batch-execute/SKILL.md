---
name: gsd-batch-execute
description: Codex-native sequential phase execution. Execute each incomplete plan in order and produce matching summary artifacts.
---

# Purpose
Execute a phase end-to-end by running incomplete plans sequentially in write mode.

# When to use
Use when asked to run `$gsd-batch-execute` or when a phase has plans ready for implementation.

# Inputs
Expected argument: `<phase-number>`.
Optional flags:
- `--stop-on-failure`: Stop on first failed plan.

# Workflow
1. Parse and validate phase number.
2. Resolve phase directory under `.planning/phases/<NN>-*`.
3. Ensure planning exists.
- If no plan files are present, run `$gsd-batch-plan <phase>`.
4. Build ordered execution list from `<NN>-*-PLAN.md`.
5. For each plan in order:
- Skip if matching summary exists (`<NN>-*-SUMMARY.md`).
- Read the plan and implement tasks in write mode.
- Run plan validation checks.
- Create/update matching summary file with outcomes and remaining risks.
- If plan fails:
- With `--stop-on-failure`, stop.
- Otherwise continue to next plan and record failure.
6. After all plans, update roadmap/state progress for completed plans/phases.
7. Report completed plans, failed plans, and changed files.

# Guardrails
- Sequential only, no parallel phase-plan execution.
- Do not mark plan complete without a matching summary file.
- Do not mark phase complete if incomplete plans remain.

