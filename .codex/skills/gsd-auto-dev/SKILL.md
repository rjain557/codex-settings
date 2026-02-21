---
name: gsd-auto-dev
description: Codex-native autonomous SDLC remediation loop. In write mode, process all pending phases, run deterministic SDLC review each cycle, resolve drift findings into remediation phases, and continue until health is 100/100 with no pending remediation phases.
---

# Purpose
Run end-to-end remediation in Codex write mode until SDLC health is truly clean.

# When to use
Use for requests like "auto-dev", "run remediation loop", "fix all pending SDLC phases", or "keep iterating until clean".

# Inputs
The text after `$gsd-auto-dev` is parsed as arguments.
Supported arguments:
- `--max-cycles <n>`: Maximum remediation cycles (default `20`).
- `--layer=frontend|backend|database|auth`: Optional review scope forwarded to `$gsd-sdlc-review`.
- `--phase=<n>`: Optional phase filter. Only process this phase if pending.
- `--stop-on-failure`: Stop immediately when a phase stage fails.
- `--write` or `--read-only`: Execution mode. Default is `--write`.

# Workflow
1. Preflight
- Require `.planning/ROADMAP.md` and `.planning/STATE.md`.
- Require `docs/review/` to be writable in write mode.
- Require companion skills: `$gsd-batch-research`, `$gsd-batch-plan`, `$gsd-batch-execute`, `$gsd-sdlc-review`.

2. Enforce execution mode
- Default to write mode.
- If user explicitly requests read-only mode, do not execute phases; report what would run.

3. Cycle loop (`cycle = 1..max_cycles`)
- Read pending phases from unchecked ROADMAP phase headers: `- [ ] **Phase N:`.
- If `--phase` is set, intersect pending list with that phase.
- Sort ascending and process sequentially.

4. For each pending phase (sequential)
- Research gate: if phase directory has no `*RESEARCH.md`, run `$gsd-batch-research <phase>`.
- Planning gate: if phase directory has no `*-PLAN.md`, run `$gsd-batch-plan <phase>`.
- Execute gate: run `$gsd-batch-execute <phase>`.
- If a stage fails:
  - With `--stop-on-failure`, stop immediately and report failure.
  - Otherwise, record failure and continue with next pending phase.

5. Re-review after phase execution
- Run `$gsd-sdlc-review` (pass `--layer` when provided).
- Parse health from canonical `docs/review/EXECUTIVE-SUMMARY.md` as `X/100`.
- Parse deterministic evidence section and verify it exists.
- Re-read pending phases from ROADMAP.

6. Root-conflict and drift hardening
- Read all candidate review summaries in known roots (`docs/review/` under `.` and `./tech-web-chatai.2` when present).
- If health values or deterministic mismatch totals conflict across roots, classify cycle as non-clean (`REVIEW_ROOT_CONFLICT`).
- Parse prioritized tasks and verify findings-to-phase mapping is complete.
- If unmapped findings exist, create remediation phases immediately and continue loop.

7. Stop conditions
- Success only if all are true:
  - health is exactly `100/100`,
  - pending phase list is empty,
  - no root conflict,
  - no unmapped findings.
- Limit: `cycle > max_cycles`.
- Stuck guard: no phase execution occurred in a cycle and health did not improve.

8. Final output
- Report cycles run, phases processed per cycle, failures, final health, deterministic parity state, remaining pending phases, and stop reason.

# Outputs / artifacts
Summarize and reference:
- `docs/review/EXECUTIVE-SUMMARY.md`
- `docs/review/FULL-REPORT.md`
- `docs/review/DEVELOPER-HANDOFF.md`
- `docs/review/PRIORITIZED-TASKS.md`
- `docs/review/TRACEABILITY-MATRIX.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/phases/*`

# Guardrails
- Always run in write mode by default for auto-dev.
- Always run `$gsd-sdlc-review` after remediation work in each cycle.
- Do not substitute `$gsd-code-review` for `$gsd-sdlc-review` in this skill.
- Do not skip research/planning gates before execution.
- Do not process phases in parallel; keep order deterministic.
- Do not claim success unless all clean-state conditions are satisfied.
