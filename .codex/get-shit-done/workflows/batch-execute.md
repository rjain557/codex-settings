<purpose>
Execute all plans in a phase sequentially, one at a time. Headless-safe variant of execute-phase that avoids parallel Task spawning. Designed for `claude -p` automation where parallel subagents die when the parent process exits.

Use this instead of execute-phase when running via `claude -p` (headless), PowerShell scripts, CI/CD pipelines, or any non-interactive environment.
</purpose>

<core_principle>
One plan at a time. Never spawn multiple Task agents in the same message. This prevents the headless-mode race condition where parallel agents die when the parent process finishes its text response before tool calls complete.
</core_principle>

<required_reading>
Read STATE.md before any operation to load project context.
</required_reading>

<process>

<step name="initialize" priority="first">
Load all context in one call:

```bash
INIT=$(node C:/Users/rjain/.codex/get-shit-done/bin/gsd-tools.js init execute-phase "${PHASE_ARG}")
```

Parse JSON for: `executor_model`, `verifier_model`, `commit_docs`, `phase_found`, `phase_dir`, `phase_number`, `phase_name`, `phase_slug`, `plans`, `incomplete_plans`, `plan_count`, `incomplete_count`, `state_exists`, `roadmap_exists`.

**If `phase_found` is false:** Error -- phase directory not found.
**If `plan_count` is 0:** Error -- no plans found in phase.
**If `incomplete_count` is 0:** "All plans complete. Nothing to execute." -- exit.

**IMPORTANT:** Override parallelization to false. This skill always runs sequentially regardless of config.
</step>

<step name="discover_plans">
Load plan inventory:

```bash
PLAN_INDEX=$(node C:/Users/rjain/.codex/get-shit-done/bin/gsd-tools.js phase-plan-index "${PHASE_NUMBER}")
```

Parse JSON for: `plans[]` (each with `id`, `wave`, `autonomous`, `objective`, `has_summary`), `incomplete`.

Filter to only plans where `has_summary: false`. Sort by wave number then plan ID to respect dependency order.

Report:
```
## Batch Execution Plan (Sequential)

**Phase {X}: {Name}** -- {incomplete_count} plans to execute

| # | Plan | Objective |
|---|------|-----------|
| 1 | 14-01 | {from plan objective, 10-15 words} |
| 2 | 14-02 | ... |
```
</step>

<step name="execute_plans_sequentially">
Execute each incomplete plan ONE AT A TIME. Never spawn more than one Task agent per message.

**For each plan (in order):**

1. **Describe what's being built:**

   Read the plan's `<objective>`. Extract what's being built and why.

   ```
   ---
   ## Plan {Plan ID}: {Plan Name} [{N} of {total}]

   {2-3 sentences: what this builds, technical approach, why it matters}

   Spawning executor agent...
   ---
   ```

2. **Spawn ONE executor agent and WAIT for it to complete:**

   ```
   Task(
     subagent_type="gsd-executor",
     model="{executor_model}",
     prompt="
       <objective>
       Execute plan {plan_number} of phase {phase_number}-{phase_name}.
       Commit each task atomically. Create SUMMARY.md. Update STATE.md.
       </objective>

       <execution_context>
       @C:/Users/rjain/.codex/get-shit-done/workflows/execute-plan.md
       @C:/Users/rjain/.codex/get-shit-done/templates/summary.md
       @C:/Users/rjain/.codex/get-shit-done/references/checkpoints.md
       @C:/Users/rjain/.codex/get-shit-done/references/tdd.md
       </execution_context>

       <files_to_read>
       Read these files at execution start using the Read tool:
       - Plan: {phase_dir}/{plan_file}
       - State: .planning/STATE.md
       - Config: .planning/config.json (if exists)
       </files_to_read>

       <success_criteria>
       - [ ] All tasks executed
       - [ ] Each task committed individually
       - [ ] SUMMARY.md created in plan directory
       - [ ] STATE.md updated with position and decisions
       </success_criteria>
     "
   )
   ```

   **CRITICAL:** Do NOT spawn the next plan's agent in the same message. Wait for this Task to return before proceeding.

3. **After agent returns -- spot-check results:**

   - Verify SUMMARY.md exists: `ls {phase_dir}/{plan_id}-SUMMARY.md`
   - Check git commits: `git log --oneline --all --grep="{phase}-{plan}"` returns >= 1 commit
   - Check for self-check failure: `grep "Self-Check: FAILED" {phase_dir}/{plan_id}-SUMMARY.md`

   **Known Claude Code bug (classifyHandoffIfNeeded):** If agent reports "failed" with error containing `classifyHandoffIfNeeded is not defined`, this is a Claude Code runtime bug. Run spot-checks; if they pass, treat as successful.

4. **Report result:**

   If SUMMARY exists:
   ```
   Plan {Plan ID}: COMPLETE ({duration})
   {One-liner from SUMMARY.md}
   Progress: {completed}/{total} plans done
   ```

   If SUMMARY missing:
   ```
   Plan {Plan ID}: FAILED -- no SUMMARY created
   Continuing with remaining plans...
   ```

   **On failure:** Log the failure but continue to the next plan. Some plans may not depend on the failed one.

5. **Proceed to next plan.** Do NOT batch -- spawn only after the previous one completes.
</step>

<step name="aggregate_results">
After all plans attempted:

```markdown
## Phase {X}: {Name} Batch Execution Complete

**Mode:** Sequential (headless-safe)
**Plans:** {completed}/{total} complete

| # | Plan | Status | Duration |
|---|------|--------|----------|
| 1 | 14-01 | Complete | 8m |
| 2 | 14-02 | Complete | 12m |
| 3 | 14-03 | Failed | -- |

### Issues
{Aggregate from SUMMARYs, or "None"}
```
</step>

<step name="verify_phase_goal">
Only if ALL plans completed successfully.

```
Task(
  prompt="Verify phase {phase_number} goal achievement.
Phase directory: {phase_dir}
Phase goal: {goal from ROADMAP.md}
Check must_haves against actual codebase. Create VERIFICATION.md.",
  subagent_type="gsd-verifier",
  model="{verifier_model}"
)
```

Read status from VERIFICATION.md:

| Status | Action |
|--------|--------|
| `passed` | update_roadmap |
| `human_needed` | Present items for human testing |
| `gaps_found` | Present gap summary, offer `/gsd:plan-phase {phase} --gaps` |
</step>

<step name="update_roadmap">
Mark phase complete in ROADMAP.md (date, status).

```bash
node C:/Users/rjain/.codex/get-shit-done/bin/gsd-tools.js commit "docs(phase-{X}): complete phase execution" --files .planning/ROADMAP.md .planning/STATE.md .planning/phases/{phase_dir}/*-VERIFICATION.md .planning/REQUIREMENTS.md
```
</step>

<step name="offer_next">
**If more phases:**
```
## Next Up

**Phase {X+1}: {Name}** -- {Goal}

For headless continuation:
  claude -p "/gsd:batch-execute {X+1}" --model opus --dangerously-skip-permissions --max-turns 200

For interactive:
  /gsd:execute-phase {X+1}

/clear first for fresh context
```

**If milestone complete:**
```
MILESTONE COMPLETE!

All {N} phases executed.

/gsd:complete-milestone
```
</step>

</process>

<context_efficiency>
Orchestrator: ~15-20% context. Each plan executor gets fresh 200k context. Slightly higher orchestrator usage than execute-phase because plans run sequentially (more result processing in main context), but this is the tradeoff for headless reliability.
</context_efficiency>

<failure_handling>
- **classifyHandoffIfNeeded false failure:** Agent reports "failed" with `classifyHandoffIfNeeded is not defined` -- Claude Code bug. Spot-check SUMMARY + commits. If pass, treat as success.
- **Agent fails mid-plan:** Missing SUMMARY.md -- log failure, continue to next plan. Some plans are independent.
- **All plans fail:** Systemic issue -- stop, report. Likely a project configuration problem.
- **Context window filling:** With many plans, orchestrator context may grow. If > 60% used, summarize completed plan results to free space.
- **Process killed externally:** Safe to re-run. Discovers completed SUMMARYs on init and skips them.
</failure_handling>

<resumption>
Re-run `/gsd:batch-execute {phase}` after interruption. The init step discovers existing SUMMARYs and only executes plans that are still incomplete. Safe to run repeatedly.
</resumption>
</content>
</invoke>
