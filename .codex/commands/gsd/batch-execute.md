---
name: gsd:batch-execute
description: Execute all plans in a phase sequentially (headless-safe, no parallel agents)
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
---
<objective>
Execute all plans in a phase sequentially, one at a time. Headless-safe variant of execute-phase that avoids parallel Task spawning.

Use this instead of execute-phase when running via `claude -p` (headless mode), PowerShell/bash automation scripts, CI/CD pipelines, or any non-interactive environment where parallel subagents die when the parent process exits.

Each plan is executed by a fresh gsd-executor agent. Plans run one at a time -- never multiple in the same message. This prevents the headless-mode race condition.
</objective>

<execution_context>
@C:/Users/rjain/.claude/get-shit-done/workflows/batch-execute.md
@C:/Users/rjain/.claude/get-shit-done/references/ui-brand.md
</execution_context>

<context>
Phase: $ARGUMENTS

@.planning/ROADMAP.md
@.planning/STATE.md
</context>

<process>
Execute the batch-execute workflow from @C:/Users/rjain/.claude/get-shit-done/workflows/batch-execute.md end-to-end.
Preserve all workflow gates (sequential execution, spot-check verification, state updates, routing).
Key constraint: NEVER spawn more than one Task agent per message. This is critical for headless reliability.
</process>
