---
name: gsd:batch-research
description: Research all plans in a phase sequentially (headless-safe, no parallel agents)
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
Research all plans in a phase sequentially, one at a time. Headless-safe variant that avoids parallel Task spawning.

Use this instead of research-phase when running via `claude -p` (headless mode), PowerShell/bash automation scripts, CI/CD pipelines, or any non-interactive environment where parallel subagents die when the parent process exits.

Each plan is researched by a fresh gsd-phase-researcher agent. Plans run one at a time -- never multiple in the same message. This prevents the headless-mode race condition.
</objective>

<execution_context>
@C:/Users/rjain/.claude/get-shit-done/workflows/research-phase.md
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

## Step 2: Sequential Research Loop

For each plan in order:
1. Display which plan is being researched (e.g., "Researching plan 56-01...")
2. Spawn ONE gsd-phase-researcher Task agent for this plan
3. Wait for completion before proceeding to the next plan
4. CRITICAL: Never spawn more than one Task agent per message

## Step 3: Summary

After all plans are researched:
1. Display a summary of all research outputs
2. Offer next steps: "Run `/gsd:batch-plan` to create plans from research"

Key constraint: NEVER spawn more than one Task agent per message. This is critical for headless reliability.
</process>
