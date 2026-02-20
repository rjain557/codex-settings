---
name: gsd:sdlc-review
description: Run SDLC review and generate parseable health/finding reports
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
8) Return top risks and recommended remediation focus.
</process>
