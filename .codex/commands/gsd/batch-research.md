---
name: gsd:batch-research
description: Ensure phase research exists before planning/execution
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
Run `$gsd-batch-research` behavior for the provided phase number.
Create/update missing `*RESEARCH.md` artifacts for that phase.
</objective>
<context>
Phase: $ARGUMENTS
@.planning/ROADMAP.md
@.planning/STATE.md
</context>
<process>
1) Resolve phase and directory (`.planning/phases/<NN>-*`).
2) If research exists, report skip unless regeneration is explicitly requested.
3) Otherwise create/update `<NN>-RESEARCH.md` with scope, findings mapping, target files, risks, and assumptions.
4) Summarize outputs and next step: `/gsd:batch-plan <phase>`.
</process>
