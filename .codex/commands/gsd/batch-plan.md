---
name: gsd:batch-plan
description: Plan all sub-plans in a phase sequentially (headless-safe, no parallel agents)
argument-hint: "<phase-number>"
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
  - Task
  - TodoWrite
  - AskUserQuestion
  - WebSearch
  - WebFetch
---
<objective>
Create implementation plans for all sub-plans in a phase sequentially, one at a time. Headless-safe variant that avoids parallel Task spawning.

Use this instead of plan-phase when running via `claude -p` (headless mode), PowerShell/bash automation scripts, CI/CD pipelines, or any non-interactive environment where parallel subagents die when the parent process exits.

Each plan is created by a fresh gsd-planner agent. Plans run one at a time -- never multiple in the same message. This prevents the headless-mode race condition.
</objective>

<execution_context>
@C:/Users/rjain/.claude/get-shit-done/workflows/plan-phase.md
@C:/Users/rjain/.claude/get-shit-done/references/ui-brand.md
</execution_context>

<context>
Phase: $ARGUMENTS

@.planning/ROADMAP.md
@.planning/STATE.md
</context>

<process>
## Step 0: Resolve Phase

Parse $ARGUMENTS to get the phase number. Look up all plans for this phase in ROADMAP.md.

## Step 1: Enumerate Plans

Find all plans listed under the target phase in ROADMAP.md. Build an ordered list of plan identifiers (e.g., 56-01, 56-02, 56-03).

## Step 2: Load Research (if available)

Check for existing research files:
```bash
ls .planning/phases/${PHASE}-*/RESEARCH.md 2>/dev/null
```

If research exists, load it as context for planning. If not, proceed without (planner will research inline).

## Step 3: Sequential Planning Loop

For each plan in order:
1. Display which plan is being created (e.g., "Planning 56-01...")
2. Spawn ONE gsd-planner Task agent for this plan with:
   - Phase context from ROADMAP.md
   - Research output (if available)
   - Prior plan outputs (for dependency awareness)
3. Wait for completion before proceeding to the next plan
4. CRITICAL: Never spawn more than one Task agent per message

## Step 4: Verification (Optional)

After all plans are created:
1. Optionally spawn ONE gsd-plan-checker to verify plan quality
2. Display a summary of all created plans

## Step 5: Summary

After all plans are created:
1. Display a summary table of all plans with task counts
2. Offer next steps: "Run `/gsd:batch-execute` to execute all plans"

Key constraint: NEVER spawn more than one Task agent per message. This is critical for headless reliability.
</process>
