---
name: gsd-pause-work
description: Create context handoff when pausing work mid-phase Use when the user asks for 'gsd:pause-work', 'gsd-pause-work', or equivalent trigger phrases.
---

# Purpose
Create `.continue-here.md` handoff file to preserve complete work state across sessions.

Routes to the pause-work workflow which handles:
- Current phase detection from recent files
- Complete state gathering (position, completed work, remaining work, decisions, blockers)
- Handoff file creation with all context sections
- Git commit as WIP
- Resume instructions

# When to use
Use when the user requests the original gsd:pause-work flow (for example: $gsd-pause-work).
Also use on natural-language requests that match this behavior: Create context handoff when pausing work mid-phase

# Inputs
No required positional arguments. If the request lacks needed context, ask concise targeted questions before proceeding.

# Workflow
Load and follow these referenced artifacts first:
- @.planning/STATE.md
- @C:/Users/rjain/.claude/get-shit-done/workflows/pause-work.md
Then execute this process:
```text
**Follow the pause-work workflow** from `@C:/Users/rjain/.claude/get-shit-done/workflows/pause-work.md`.

The workflow handles all logic including:
1. Phase directory detection
2. State gathering with user clarifications
3. Handoff file writing with timestamp
4. Git commit
5. Confirmation with resume instructions
```

# Outputs / artifacts
Produce the artifacts specified by the workflow and summarize created/updated files.

# Guardrails (what not to do / how to ask for missing info)
- Do not invent missing project files, phase numbers, or state; inspect the repo first.
- Do not skip validation or checkpoint gates described in referenced workflows.
- If required context is missing, ask focused questions (one small batch) and proceed after answers.

# Source (path to original Claude command file)
- C:\Users\rjain\.claude\commands\gsd\pause-work.md
