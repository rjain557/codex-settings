---
name: gsd-quick
description: Execute a quick task with GSD guarantees (atomic commits, state tracking) but skip optional agents Use when the user asks for 'gsd:quick', 'gsd-quick', or equivalent trigger phrases.
---

# Purpose
Execute small, ad-hoc tasks with GSD guarantees (atomic commits, STATE.md tracking) while skipping optional agents (research, plan-checker, verifier).

Quick mode is the same system with a shorter path:
- Spawns gsd-planner (quick mode) + gsd-executor(s)
- Skips gsd-phase-researcher, gsd-plan-checker, gsd-verifier
- Quick tasks live in `.planning/quick/` separate from planned phases
- Updates STATE.md "Quick Tasks Completed" table (NOT ROADMAP.md)

Use when: You know exactly what to do and the task is small enough to not need research or verification.

# When to use
Use when the user requests the original gsd:quick flow (for example: $gsd-quick).
Also use on natural-language requests that match this behavior: Execute a quick task with GSD guarantees (atomic commits, state tracking) but skip optional agents

# Inputs
No required positional arguments. If the request lacks needed context, ask concise targeted questions before proceeding.
Context from source:
```text
@.planning/STATE.md
```

# Workflow
Load and follow these referenced artifacts first:
- @C:/Users/rjain/.claude/get-shit-done/workflows/quick.md
Then execute this process:
```text
Execute the quick workflow from @C:/Users/rjain/.claude/get-shit-done/workflows/quick.md end-to-end.
Preserve all workflow gates (validation, task description, planning, execution, state updates, commits).
```

# Outputs / artifacts
Produce the artifacts specified by the workflow and summarize created/updated files.

# Guardrails (what not to do / how to ask for missing info)
- Do not invent missing project files, phase numbers, or state; inspect the repo first.
- Do not skip validation or checkpoint gates described in referenced workflows.
- If required context is missing, ask focused questions (one small batch) and proceed after answers.

# Source (path to original Claude command file)
- C:\Users\rjain\.claude\commands\gsd\quick.md
