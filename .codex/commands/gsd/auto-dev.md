---
name: gsd:auto-dev
description: Autonomous write-mode SDLC remediation loop to 100/100 health with no pending phases
argument-hint: "[--max-cycles <n>] [--layer=frontend|backend|database|auth] [--phase=<n>] [--stop-on-failure]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
---
<objective>
Run autonomous remediation in write mode:
process pending phases (research -> plan -> execute), then rerun code review, repeating until health is 100/100 and no pending phases remain.
</objective>
<context>
Options: $ARGUMENTS
@.planning/ROADMAP.md
@.planning/STATE.md
@docs/review/EXECUTIVE-SUMMARY.md
</context>
<process>
1) Parse options and enforce write mode by default.
2) Discover pending phases from unchecked ROADMAP phase headers.
3) For each pending phase in ascending order:
   - ensure research (`/gsd:batch-research <phase>` when missing)
   - ensure plans (`/gsd:batch-plan <phase>` when missing)
   - execute (`/gsd:batch-execute <phase>`)
4) Run `/gsd:code-review`.
5) Parse health from executive summary (`X/100`) and re-read pending phases.
6) If health < 100 or findings > 0 while pending phase count is 0, force remediation phase creation in ROADMAP from the latest review findings, then continue.
7) Repeat until health is 100 and no pending phases remain, or stop at max cycles/failure policy.
8) Return cycle report with phases processed, failures, final health, and stop reason.
</process>
