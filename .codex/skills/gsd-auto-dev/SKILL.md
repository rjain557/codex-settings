---
name: gsd-auto-dev
description: Codex-native autonomous SDLC remediation loop. In write mode, process pending phases with parallel research/planning fan-out, sequential phase execution, deterministic SDLC review each cycle, then require final line-level code-completeness confirmation via gsd-sdlc-finalreview before success.
---

# Purpose
Run end-to-end remediation in Codex write mode until SDLC health is truly clean and final code-completeness review is confirmed on unchanged code.

# When to use
Use for requests like "auto-dev", "run remediation loop", "fix all pending SDLC phases", or "keep iterating until clean".

# Inputs
The text after `$gsd-auto-dev` is parsed as arguments.
Supported arguments:
- `--max-cycles <n>`: Maximum remediation cycles (default `20`).
- `--parallelism <n>`: Max concurrent agents for research/plan/review fan-out (default `4`).
- `--layer=frontend|backend|database|auth`: Optional review scope forwarded to `$gsd-sdlc-review`.
- `--phase=<n>`: Optional phase filter. Only process this phase if pending.
- `--stop-on-failure`: Stop immediately when a phase stage fails.
- `--write` or `--read-only`: Execution mode. Default is `--write`.
- `--project-root <path>`: Canonical root to run from when strict-root execution is required.
- `--roadmap-path <path>`: Explicit roadmap path (typically `.planning/ROADMAP.md`).
- `--state-path <path>`: Explicit state path (typically `.planning/STATE.md`).
- `--strict-root`: Fail fast when root/roadmap/state are ambiguous.

# Workflow
1. Preflight
- Require `.planning/ROADMAP.md` and `.planning/STATE.md`.
- Require `docs/review/` to be writable in write mode.
- Require companion skills: `$gsd-batch-research`, `$gsd-batch-plan`, `$gsd-batch-execute`, `$gsd-sdlc-review`, `$gsd-sdlc-finalreview`.
- Resolve review-summary candidates before cycle start:
  - `docs/review/EXECUTIVE-SUMMARY.md` under `.` and `./tech-web-chatai.2` (when present).
  - If no candidate summary exists after first review run, treat as failure.

2. Enforce execution mode
- Default to write mode.
- If user explicitly requests read-only mode, do not execute phases; report what would run.

3. Cycle loop (`cycle = 1..max_cycles`)
- Read pending phases from unchecked ROADMAP phase headers: `- [ ] **Phase N:`.
- If `--phase` is set, intersect pending list with that phase.
- Sort ascending once and use the same deterministic order throughout the cycle.
- Emit progress updates every 1 minute while running long stages.
- Each progress update must include:
  - current stage/action (what the script is doing right now),
  - phase counts: completed, in progress, pending,
  - target metrics: health `100`, drift `0`, unmapped `0`,
  - current metrics: health/drift/unmapped from latest review summary,
  - number of git commits completed during the run.

4. Three-stage phase processing per cycle
- Stage A: Research fan-out (parallel)
  - Build `researchNeeded` from pending phases missing `*RESEARCH.md`.
  - Dispatch multiple agents in parallel (bounded by `--parallelism`) running `$gsd-batch-research <phase>`.
  - Wait for all research agents to finish, collect per-phase results, and surface failures with evidence.
  - With `--stop-on-failure`, stop cycle immediately on any research failure.
- Stage B: Planning fan-out (parallel)
  - Build `planNeeded` from pending phases missing `*-PLAN.md` after Stage A completes.
  - Dispatch multiple agents in parallel (bounded by `--parallelism`) running `$gsd-batch-plan <phase>`.
  - Wait for all planning agents to finish, collect per-phase results, and surface failures with evidence.
  - With `--stop-on-failure`, stop cycle immediately on any planning failure.
- Stage C: Execution (sequential)
  - Determine executable phase set in ascending order:
    - pending phases with required research+plan artifacts present and no unresolved Stage A/B failure for that phase.
  - Run `$gsd-batch-execute <phase>` sequentially in roadmap order.
  - If execute fails:
    - With `--stop-on-failure`, stop immediately.
    - Otherwise, record failure and continue to next executable phase.

5. Re-review after phase execution
- Run `$gsd-sdlc-review` (pass `--layer` when provided).
- Parse health from every candidate summary as `X/100`.
- Parse deterministic drift totals from:
  - `Deterministic Drift Totals: ... TOTAL=<n>`
- Parse runtime gate totals from:
  - `Runtime Gate Totals: ... FAILURES=<n> UNVERIFIED=<n>`
- Parse mapping integrity from:
  - `Unmapped findings: <n>`
- Re-read pending phases from ROADMAP.

6. Root-conflict and drift hardening
- If health values or deterministic drift totals conflict across roots, classify cycle as non-clean (`REVIEW_ROOT_CONFLICT`) and continue remediation.
- If deterministic drift line is missing in any candidate summary, classify as non-clean (`REVIEW_PARSE_FAILURE`).
- If runtime gate line is missing in any candidate summary, classify as non-clean (`RUNTIME_GATE_PARSE_FAILURE`).
- If runtime gate `FAILURES>0` or `UNVERIFIED>0`, classify as non-clean (`RUNTIME_GATE_NOT_CLEAN`) and continue remediation.
- Parse prioritized tasks and verify findings-to-phase mapping is complete.
- If unmapped findings exist, create remediation phases immediately and continue loop.
- If deterministic drift total is non-zero, ensure mapped remediation phases exist for each non-zero category before next cycle.

7. Final code-completeness gate (mandatory clean-candidate step)
- If and only if cycle metrics are clean-candidate:
  - health `100/100`,
  - deterministic drift total `0`,
  - runtime gate failures `0`,
  - runtime gate unverified count `0`,
  - pending phase list empty,
  - no root conflict,
  - no unmapped findings,
  run:
  - `$gsd-sdlc-finalreview --code-scope=generated+src --figma-version=v8 --spec-mode=phase-ae+spec`
- Parse `docs/review/layers/finalreview-summary.json` (or `FINALREVIEW_*` output lines) for:
  - `health`, `drift_total`, `unmapped_lines`, `coverage_percent`, `pending_remediation`, `commit_sha`, `summary_hash`, `status`, `stop_reason`.
- If finalreview fails:
  - classify cycle as non-clean (`FINALREVIEW_UNMAPPED` or `FINALREVIEW_PARSE_FAILURE`),
  - create remediation phases for unmapped findings immediately,
  - continue next cycle.
- If finalreview passes:
  - run `$gsd-sdlc-finalreview --confirm-only --code-scope=generated+src --figma-version=v8 --spec-mode=phase-ae+spec`.
  - require confirmation pass with:
    - unchanged commit SHA,
    - identical summary hash.
  - if confirmation fails, classify non-clean (`FINALREVIEW_CONFIRMATION_MISMATCH`) and continue loop.

8. Stop conditions
- Success only if all are true:
  - health is exactly `100/100`,
  - deterministic drift total is `0`,
  - runtime gate failures are `0`,
  - runtime gate unverified count is `0`,
  - pending phase list is empty,
  - no root conflict,
  - no unmapped findings,
  - finalreview pass reports:
    - `coverage_percent=100`,
    - `unmapped_lines=0`,
    - `drift_total=0`,
    - `pending_remediation=0`,
  - finalreview confirm-only pass reports unchanged commit SHA and identical summary hash,
  - final confirmation `$gsd-sdlc-review` still reports `100/100` and drift total `0` after no execution work in between.
- Limit: `cycle > max_cycles`.
- Stuck guard: no phase execution occurred in a cycle and health/drift did not improve.

9. Final output
- Report cycles run, phases processed per cycle, failures, final health, deterministic drift totals, runtime gate totals, finalreview metrics (`coverage_percent`, `unmapped_lines`, `summary_hash`, `commit_sha`), remaining pending phases, stop reason, exact summary paths/values used, and git commits completed during the run.
- Include per-cycle fan-out telemetry:
  - `research_dispatched`, `research_failed`,
  - `plan_dispatched`, `plan_failed`,
  - `executed_sequential_count`.

# Outputs / artifacts
Summarize and reference:
- `docs/review/EXECUTIVE-SUMMARY.md`
- `docs/review/FULL-REPORT.md`
- `docs/review/DEVELOPER-HANDOFF.md`
- `docs/review/PRIORITIZED-TASKS.md`
- `docs/review/TRACEABILITY-MATRIX.md`
- `docs/review/layers/finalreview-summary.json`
- `docs/review/layers/finalreview-line-map.jsonl`
- `docs/review/FINAL-SDLC-LINE-TRACEABILITY.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/phases/*`

# Guardrails
- Always run in write mode by default for auto-dev.
- Always run `$gsd-sdlc-review` after remediation work in each cycle.
- Always run `$gsd-sdlc-finalreview` before declaring success.
- Do not substitute `$gsd-code-review` for `$gsd-sdlc-review` in this skill.
- Do not skip research/planning gates before execution.
- Do not execute phases in parallel; execution remains strictly sequential and deterministic.
- Parallelism is allowed only for research/planning fan-out and must preserve deterministic phase ordering in result aggregation.
- Do not claim success unless all clean-state conditions and finalreview confirmation conditions are satisfied.
- Do not treat missing runtime gate lines, `UNVERIFIED` runtime gates, or runtime gate failures as clean.
