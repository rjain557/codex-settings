---
name: gsd-check-todos
description: List pending todos and select one to work on Use when the user asks for 'gsd:check-todos', 'gsd-check-todos', or equivalent trigger phrases.
---

# Purpose
List all pending todos, allow selection, load full context for the selected todo, and route to appropriate action.

Routes to the check-todos workflow which handles:
- Todo counting and listing with area filtering
- Interactive selection with full context loading
- Roadmap correlation checking
- Action routing (work now, add to phase, brainstorm, create phase)
- STATE.md updates and git commits

# When to use
Use when the user requests the original gsd:check-todos flow (for example: $gsd-check-todos).
Also use on natural-language requests that match this behavior: List pending todos and select one to work on

# Inputs
The user's text after invoking $gsd-check-todos is the arguments. Parse it into required fields; if any required field is missing, ask targeted follow-up questions.
Expected argument shape from source: [area filter].

# Workflow
Load and follow these referenced artifacts first:
- @.planning/STATE.md
- @.planning/ROADMAP.md
- @C:/Users/rjain/.claude/get-shit-done/workflows/check-todos.md
Then execute this process:
```text
**Follow the check-todos workflow** from `@C:/Users/rjain/.claude/get-shit-done/workflows/check-todos.md`.

The workflow handles all logic including:
1. Todo existence checking
2. Area filtering
3. Interactive listing and selection
4. Full context loading with file summaries
5. Roadmap correlation checking
6. Action offering and execution
7. STATE.md updates
8. Git commits
```

# Outputs / artifacts
Produce the artifacts specified by the workflow and summarize created/updated files.

# Guardrails (what not to do / how to ask for missing info)
- Do not invent missing project files, phase numbers, or state; inspect the repo first.
- Do not skip validation or checkpoint gates described in referenced workflows.
- If required context is missing, ask focused questions (one small batch) and proceed after answers.

# Source (path to original Claude command file)
- C:\Users\rjain\.claude\commands\gsd\check-todos.md
