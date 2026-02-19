---
name: gsd-resume-work
description: Resume work from previous session with full context restoration Use when the user asks for 'gsd:resume-work', 'gsd-resume-work', or equivalent trigger phrases.
---

# Purpose
Restore complete project context and resume work seamlessly from previous session.

Routes to the resume-project workflow which handles:

- STATE.md loading (or reconstruction if missing)
- Checkpoint detection (.continue-here files)
- Incomplete work detection (PLAN without SUMMARY)
- Status presentation
- Context-aware next action routing

# When to use
Use when the user requests the original gsd:resume-work flow (for example: $gsd-resume-work).
Also use on natural-language requests that match this behavior: Resume work from previous session with full context restoration

# Inputs
No required positional arguments. If the request lacks needed context, ask concise targeted questions before proceeding.

# Workflow
Load and follow these referenced artifacts first:
- @C:/Users/rjain/.claude/get-shit-done/workflows/resume-project.md
Then execute this process:
```text
**Follow the resume-project workflow** from `@C:/Users/rjain/.claude/get-shit-done/workflows/resume-project.md`.

The workflow handles all resumption logic including:

1. Project existence verification
2. STATE.md loading or reconstruction
3. Checkpoint and incomplete work detection
4. Visual status presentation
5. Context-aware option offering (checks CONTEXT.md before suggesting plan vs discuss)
6. Routing to appropriate next command
7. Session continuity updates
```

# Outputs / artifacts
Produce the artifacts specified by the workflow and summarize created/updated files.

# Guardrails (what not to do / how to ask for missing info)
- Do not invent missing project files, phase numbers, or state; inspect the repo first.
- Do not skip validation or checkpoint gates described in referenced workflows.
- If required context is missing, ask focused questions (one small batch) and proceed after answers.

# Source (path to original Claude command file)
- C:\Users\rjain\.claude\commands\gsd\resume-work.md
