---
name: gsd-auto-dev
description: Run an autonomous SDLC remediation loop: review code quality, generate mitigation phases when needed, then run batch research, batch planning, and batch execution until review no longer creates pending remediation phases. Use when the user asks for auto-dev, autonomous fix loops, or continuous SDLC remediation.
---

# Purpose
Run a closed-loop automation flow:
1. Run `$gsd-sdlc-review`.
2. If health is less than `100/100`, process all pending remediation phases with `$gsd-batch-research`, `$gsd-batch-plan`, and `$gsd-batch-execute`.
3. Re-run review.
4. Repeat until no new/pending remediation phases remain from review output.

# When to use
Use when the user wants autonomous review-and-fix cycles, such as "auto-dev", "keep iterating until clean", or "run SDLC review and fix everything".
Use when headless-safe orchestration is required by relying on batch commands instead of parallel execute commands.

# Inputs
The user's text after invoking `$gsd-auto-dev` is the arguments. Parse it into required fields; if any required field is missing, ask targeted follow-up questions.
Supported argument patterns:
- `[--max-cycles <n>]` maximum review/remediation loops (default: `10`).
- `[--layer=frontend|backend|database|auth]` optional review scope passed to `$gsd-sdlc-review`.
- `[--phase=<phase-number>]` optional phase filter if user wants to limit execution.
- `[--stop-on-failure]` stop immediately on first failed batch stage.

# Workflow
1. Validate prerequisites:
- Ensure `.planning/ROADMAP.md` and `.planning/STATE.md` exist.
- Ensure `$gsd-sdlc-review`, `$gsd-batch-research`, `$gsd-batch-plan`, and `$gsd-batch-execute` are available.

2. Initialize loop state:
- Set `cycle = 1`.
- Set `max_cycles` from args (default `10`).
- Track phases processed in prior cycles to detect newly generated remediation phases.

3. Run SDLC review:
- Invoke `$gsd-sdlc-review` (with optional `--layer` argument when provided).
- Read review outputs, prioritizing `docs/review/EXECUTIVE-SUMMARY.md` and `docs/review/PRIORITIZED-TASKS.md` when present.
- Determine whether health is `100/100` and whether remediation phases are pending.

4. Decide whether to continue:
- If health is `100/100` and no pending remediation phases exist, stop and report success.
- Otherwise, build the list of pending phases to process in this cycle.
- If `--phase` is provided, intersect pending phases with that phase.

5. Process each pending phase sequentially:
- Run `$gsd-batch-research <phase>`.
- Run `$gsd-batch-plan <phase>`.
- Run `$gsd-batch-execute <phase>`.
- Continue phase-by-phase in ascending order.
- If any stage fails:
  - With `--stop-on-failure`, stop and report the failure.
  - Without it, record the failure and continue to next phase.

6. Repeat:
- Increment `cycle`.
- If `cycle > max_cycles`, stop and report that limit was reached.
- Return to step 3.

7. Final report:
- Provide cycles run, phases processed per cycle, failures (if any), final health score, and stop reason.

# Outputs / artifacts
Produce and summarize outputs from invoked commands, including:
- `docs/review/EXECUTIVE-SUMMARY.md`
- `docs/review/FULL-REPORT.md`
- `docs/review/DEVELOPER-HANDOFF.md`
- `docs/review/PRIORITIZED-TASKS.md`
- Any roadmap/state updates and phase artifacts created by batch workflows

# Guardrails (what not to do / how to ask for missing info)
- Do not skip the review stage; each cycle must begin with `$gsd-sdlc-review`.
- Do not use non-batch execution paths for remediation in headless workflows.
- Do not run batch commands in parallel; keep phase processing sequential and deterministic.
- Do not assume a phase list; derive pending phases from current roadmap/state each cycle.
- If pending-phase detection is unclear from available files, ask a targeted question before proceeding.
- Ambiguities: "phases generated under sdlc-review" is inferred as phases that are pending after each review cycle and require remediation; if project conventions differ, confirm with the user.

# Source (path to original Claude command file)
- No original Claude command file was found for auto-dev.
- Source is user-defined behavior provided in chat on 2026-02-19.
