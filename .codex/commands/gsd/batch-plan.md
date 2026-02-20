---
name: gsd:batch-plan
description: Ensure executable phase plans exist before execution
argument-hint: "<phase-number>"
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
---
<objective>
Run `$gsd-batch-plan` behavior for the provided phase number.
Create/update missing `*-PLAN.md` artifacts for that phase.
</objective>
<context>
Phase: $ARGUMENTS
@.planning/ROADMAP.md
@.planning/STATE.md
</context>
<process>
1) Resolve phase and directory (`.planning/phases/<NN>-*`).
2) Ensure research exists; generate research first if missing.
3) Create/update plan files (`<NN>-01-PLAN.md`, `<NN>-02-PLAN.md`, ...).
4) Ensure plans include objective, file-level tasks, validation, and exit criteria.
5) Summarize outputs and next step: `/gsd:batch-execute <phase>`.
</process>
