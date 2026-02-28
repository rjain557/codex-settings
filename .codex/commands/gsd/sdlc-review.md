---
name: gsd:sdlc-review
description: Run comprehensive multi-agent code review pipeline (Phase G Code Debugger) and auto-create remediation phases when findings exist
argument-hint: "[--layer=frontend|backend|database|auth]"
allowed-tools:
  - Read
  - Write
  - Bash
  - Grep
  - Glob
  - Task
---

<objective>
Run the Phase G comprehensive code review pipeline. Spawns parallel review agents for each code layer, builds traceability matrix, and generates developer handoff with prioritized findings.
When health is below 100 or findings exist, create remediation phases in planning artifacts so execution can continue automatically toward 100/100.

Orchestrator role: Parse options, spawn sdlc-code-reviewer agent, enforce design/spec/remote-agent parity checks, enforce remediation phase creation, present findings summary.
</objective>

<execution_context>
@docs/sdlc/phase.g.codedebugger/code-debugger.md
@.planning/STATE.md
</execution_context>

<context>
Options: $ARGUMENTS
- (no flags): Full review - all layers + traceability matrix + SDLC gap analysis
- --layer=frontend: Frontend layer only
- --layer=backend: Backend layer only
- --layer=database: Database layer only
- --layer=auth: Auth/SSO layer only
</context>

<process>

## 1. Parse Options

Determine review scope from $ARGUMENTS:
- Default: full review (all layers + cross-layer analysis)
- --layer=X: single layer review only

## 2. Spawn sdlc-code-reviewer Agent

Spawn via Task tool:
- description: "SDLC Code Review ({scope})"
- prompt: Include scope, reference to SDLC code debugger docs, and mandatory coverage checks:
  - Design parity (Figma/storyboards/routes/components -> implemented frontend)
  - Specification parity (`docs/spec/*` -> routes/controllers/services/repositories/SP/schema)
  - Remote-agent parity when docs mention remote agent/workstation connector/moltbot-like behavior

The agent will:
1. Inventory the repository (Phase 0)
2. Spawn layer reviewers - 4 in parallel for full, or 1 for single-layer (Wave 1)
3. Spawn cross-layer agents - traceability + SDLC gaps (Wave 2, full only)
4. Spawn MCP reviewer if detected (Wave 3, conditional)
5. Run build verification (MANDATORY)
6. Consolidate findings into reports with coverage counts (implemented/partial/missing)

Output locations:
- docs/review/EXECUTIVE-SUMMARY.md
- docs/review/FULL-REPORT.md
- docs/review/DEVELOPER-HANDOFF.md
- docs/review/PRIORITIZED-TASKS.md
- docs/review/TRACEABILITY-MATRIX.md

## 3. Mandatory Remediation Phase Creation

After findings are consolidated, enforce this rule:
- If health < 100 or total findings > 0, remediation phases are required.
- Only skip phase creation when health == 100 and findings total == 0.

When required:
1. Read `.planning/ROADMAP.md` and identify existing unchecked phases.
2. If existing pending phases do not already cover current prioritized task IDs, append new unchecked phase entry/entries using next phase number(s).
3. Create matching phase folders under `.planning/phases/NN-*` with at least one actionable `*-PLAN.md` per phase.
4. Ensure Blocker/High findings are represented in near-term phase(s); Medium/Low can be batched into follow-on phase(s).
5. Update `.planning/STATE.md` current focus and last activity with the new phase ids.
6. Add `Remediation Phases Created:` section to `docs/review/EXECUTIVE-SUMMARY.md` including phase numbers and task IDs covered.
7. If phase creation fails while required, mark the review run as failed and explain the blocking cause.

## 4. Present Results

Display executive summary:
> **Code Review Complete** - Overall Health: {score}
>
> Findings: {blocker} Blocker | {high} High | {medium} Medium | {low} Low
>
> Remediation phases: {phase list or "none required"}
>
> **Top 5 Risks:**
> 1. {risk description}
> ...

Offer next steps:
- "View full report at docs/review/FULL-REPORT.md"
- "View developer handoff at docs/review/DEVELOPER-HANDOFF.md"
- "Run `/gsd:sdlc-validate` to check contract consistency"

</process>
