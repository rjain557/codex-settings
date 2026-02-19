---
name: gsd-batch-execute
description: Execute all plans in a phase sequentially (headless-safe, no parallel agents) Use when the user asks for 'gsd:batch-execute', 'gsd-batch-execute', or equivalent trigger phrases.
---

# Purpose
Execute all plans in a phase sequentially, one at a time. Headless-safe variant of execute-phase that avoids parallel Task spawning.

Use this instead of execute-phase when running via `claude -p` (headless mode), PowerShell/bash automation scripts, CI/CD pipelines, or any non-interactive environment where parallel subagents die when the parent process exits.

Each plan is executed by a fresh gsd-executor agent. Plans run one at a time -- never multiple in the same message. This prevents the headless-mode race condition.

# When to use
Use when the user requests the original gsd:batch-execute flow (for example: $gsd-batch-execute).
Also use on natural-language requests that match this behavior: Execute all plans in a phase sequentially (headless-safe, no parallel agents)

# Inputs
The user's text after invoking $gsd-batch-execute is the arguments. Parse it into required fields; if any required field is missing, ask targeted follow-up questions.
Expected argument shape from source: <phase-number>.
Context from source:
```text
Phase: <parsed-arguments>

@.planning/ROADMAP.md
@.planning/STATE.md
```

# Workflow
Load and follow these referenced artifacts first:
- @C:/Users/rjain/.claude/get-shit-done/workflows/batch-execute.md
- @C:/Users/rjain/.claude/get-shit-done/references/ui-brand.md
Then execute this process:
```text
Execute the batch-execute workflow from @C:/Users/rjain/.claude/get-shit-done/workflows/batch-execute.md end-to-end.
Preserve all workflow gates (sequential execution, spot-check verification, state updates, routing).
Key constraint: NEVER spawn more than one Task agent per message. This is critical for headless reliability.
```

# Outputs / artifacts
Produce the artifacts specified by the workflow and summarize created/updated files.

# Guardrails (what not to do / how to ask for missing info)
- Do not invent missing project files, phase numbers, or state; inspect the repo first.
- Do not skip validation or checkpoint gates described in referenced workflows.
- If required context is missing, ask focused questions (one small batch) and proceed after answers.

# Source (path to original Claude command file)
- C:\Users\rjain\.claude\commands\gsd\batch-execute.md
