---
name: gsd:batch-execute
description: Execute incomplete plans for a phase sequentially and write matching summaries
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
Execute the target phase in write mode by processing incomplete plan files in deterministic order.
</objective>
<context>
Phase: $ARGUMENTS
@.planning/ROADMAP.md
@.planning/STATE.md
</context>
<process>
1) Resolve phase directory (`.planning/phases/<NN>-*`).
2) Ensure plan files exist (`<NN>-*-PLAN.md`), generating plans first if missing.
3) Iterate plans in ascending order.
4) For each plan without `<NN>-*-SUMMARY.md`:
   - Read the plan.
   - Implement the required file changes.
   - Run relevant validation checks.
   - Write/update the matching summary file.
5) Update roadmap/state progress for completed plans and completed phase.
6) Return a concise execution summary with changed files and any failures.
</process>
