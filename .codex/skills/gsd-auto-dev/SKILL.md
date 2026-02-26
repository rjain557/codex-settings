---
name: gsd-auto-dev
description: Codex-only autonomous SDLC remediation loop. In write mode, process all pending phases by ensuring research and planning exist, execute each phase, rerun SDLC review, and repeat until health is 100/100 with no pending remediation phases.
---

# Purpose
Run end-to-end remediation in Codex write mode until SDLC health is clean.

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

# Model policy
- Review pass (`$gsd-sdlc-review`): use Codex `extra-high` reasoning when available.
- Execute pass (`$gsd-batch-execute`): use Codex `high` reasoning.
- Compatibility fallback: if `extra-high` is unavailable for the account/workspace, automatically fall back to the highest supported Codex model/reasoning level and continue (do not stop the loop).

# Workflow
1. Preflight
- Require `.planning/ROADMAP.md` and `.planning/STATE.md`.
- Require `docs/review/` to be writable in write mode.
- Require companion skills: `$gsd-batch-research`, `$gsd-batch-plan`, `$gsd-batch-execute`, `$gsd-sdlc-review`.
- Resolve candidate review summary paths:
  - `docs/review/EXECUTIVE-SUMMARY.md`
  - `tech-web-chatai.2/docs/review/EXECUTIVE-SUMMARY.md`

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
- Execute gate: run `$gsd-batch-execute <phase>` (high reasoning).
- If a stage fails:
- With `--stop-on-failure`, stop immediately and report failure.
- Otherwise, record failure and continue with next pending phase.

5. Re-review after each cycle (mandatory, even if no phases executed)
- Run `$gsd-sdlc-review` once at the end of every cycle (pass `--layer` when provided, use extra-high if available).
- Parse health from available review summary paths as `X/100`.
- If multiple summary files exist and health values differ, treat cycle as not clean and record a failure `REVIEW_ROOT_CONFLICT`.
- Re-read pending phases from ROADMAP.


6. Confirmation review gate (required before success)
- If cycle-end review reports `100/100` and pending phase list is empty, immediately run one additional confirmation `$gsd-sdlc-review` in the same cycle.
- Re-parse health from all available review summary paths and re-read pending phases from ROADMAP.
- If summary paths disagree, confirmation fails automatically.
- Success is allowed only when both consecutive reviews in that cycle are `100/100` and pending list remains empty.
- If confirmation review regresses health or introduces pending phases, continue cycling (do not stop).

7. Stop conditions
- Success: two consecutive cycle-end reviews are exactly `100/100` and pending phase list is empty after the confirmation pass.
- Limit: `cycle > max_cycles`.
- Stuck guard: no phase execution occurred in a cycle and health did not improve.

8. Final output
- Report cycles run, phases processed per cycle, failures, final health, remaining pending phases, stop reason, and whether confirmation review passed.

# Outputs / artifacts
Summarize and reference:
- `docs/review/EXECUTIVE-SUMMARY.md`
- `docs/review/FULL-REPORT.md`
- `docs/review/DEVELOPER-HANDOFF.md`
- `docs/review/PRIORITIZED-TASKS.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/phases/*`

# Guardrails
- Codex-only execution: use Codex-only execution; do not run non-Codex CLI wrappers.
- Always run in write mode by default for auto-dev.
- Always run `$gsd-sdlc-review` after remediation work in each cycle.
- Do not substitute `$gsd-code-review` for `$gsd-sdlc-review` in this skill.
- Do not skip research/planning gates before execution.
- Do not process phases in parallel; keep order deterministic.
- Do not claim success unless both conditions hold: 100/100 and no pending phases.
- Do not stop after a single clean review pass; require the confirmation review gate to pass.
- Do not treat health as clean when review summary roots conflict.


