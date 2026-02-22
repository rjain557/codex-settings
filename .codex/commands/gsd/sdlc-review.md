---
name: gsd:sdlc-review
description: Run SDLC review, generate parseable health/finding reports, and create remediation phases when needed
argument-hint: "[--layer=frontend|backend|database|auth]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
---
<objective>
Run SDLC code review and refresh `docs/review/*` reports used by remediation loops.
When review health is below 100 or findings exist, create actionable remediation phases so auto-dev can continue toward 100/100.
</objective>
<context>
Options: $ARGUMENTS
@.planning/STATE.md
@.planning/ROADMAP.md
</context>
<process>
1) Determine scope from options (default full review).
2) Inspect code and run relevant build/typecheck checks for scope.
3) Run mandatory cross-artifact coverage checks on every full-scope pass (and whenever evidence exists in layer mode):
   - **Design parity check**:
     - Detect design sources (for example `design/figma/*`, `docs/phases/phase-c/*`, storyboard outputs).
     - Compare design routes/screens/components against implemented frontend routes/screens/components.
     - Report explicit counts: total, implemented, partial, missing.
   - **Specification parity check**:
     - Validate `docs/spec/*` (UI contract, OpenAPI, API-to-SP map, DB plan, test plan) against current code.
     - Verify route/controller alignment, endpoint-to-service/repository/SP mapping, and schema/SP existence.
     - Do not assume docs are complete because they exist; verify implementation evidence.
   - **Remote-agent parity check**:
     - If repo docs/spec mention remote agent / workstation connector / moltbot-like behavior, verify code presence (for example `src/Agent`, `src/Services/RemoteAgent`, related APIs and DB objects).
     - If missing, raise explicit findings and recommended remediation phase(s).
4) Refresh traceability artifacts with evidence-backed status and counts.
5) Produce/update:
   - docs/review/EXECUTIVE-SUMMARY.md
   - docs/review/FULL-REPORT.md
   - docs/review/DEVELOPER-HANDOFF.md
   - docs/review/PRIORITIZED-TASKS.md
   - docs/review/TRACEABILITY-MATRIX.md
6) Ensure executive summary contains a parseable health score in `X/100` form and severity totals.
7) Ensure FULL-REPORT contains a section named `Coverage Checks` with:
   - Design parity result (counts + top missing items)
   - Spec parity result (counts + top mismatches)
   - Remote-agent result (implemented vs missing evidence)
8) Determine whether remediation phases are required:
   - Required if health score < 100, or any Blocker/High/Medium/Low findings exist.
   - Not required only when health is exactly 100 and findings total is 0.
9) When remediation is required, create/update planning artifacts in the same pass:
   - Read `.planning/ROADMAP.md` and find current unchecked phases.
   - If no pending phase already maps to the current findings, append new unchecked phase entry/entries using next numeric phase id(s).
   - Create corresponding phase folder(s) under `.planning/phases/NN-*` with at least one actionable `*-PLAN.md` per phase that maps directly to `docs/review/PRIORITIZED-TASKS.md` task IDs.
   - Grouping rule:
     - Blocker/High findings must be assigned to at least one near-term remediation phase.
     - Medium/Low findings can be grouped into follow-on phase(s) but must still be explicitly represented.
   - Update `.planning/STATE.md` current focus and last activity to reference the new phase ids.
10) Add explicit evidence to `docs/review/EXECUTIVE-SUMMARY.md`:
   - `Remediation Phases Created:` followed by phase numbers and task IDs covered.
   - If phases were not created despite required remediation, mark review as failed and explain why.
11) Return top risks, remediation focus, and the exact phase numbers created/updated.
</process>
