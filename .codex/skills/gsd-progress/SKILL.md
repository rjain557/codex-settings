---
name: gsd-progress
description: Check project progress, show context, and route to next action (execute or plan) Use when the user asks for 'gsd:progress', 'gsd-progress', or equivalent trigger phrases.
---

# Purpose
Check project progress, summarize recent work and what's ahead, then intelligently route to the next action - either executing an existing plan or creating the next one.

Provides situational awareness before continuing work.

# When to use
Use when the user requests the original gsd:progress flow (for example: $gsd-progress).
Also use on natural-language requests that match this behavior: Check project progress, show context, and route to next action (execute or plan)

# Inputs
No required positional arguments. If the request lacks needed context, ask concise targeted questions before proceeding.

# Workflow
Load and follow these referenced artifacts first:
- @C:/Users/rjain/.claude/get-shit-done/workflows/progress.md
Then execute this process:
```text
Execute the progress workflow from @C:/Users/rjain/.claude/get-shit-done/workflows/progress.md end-to-end.
Preserve all routing logic (Routes A through F) and edge case handling.
```

# Outputs / artifacts
Produce the artifacts specified by the workflow and summarize created/updated files.

# Guardrails (what not to do / how to ask for missing info)
- Do not invent missing project files, phase numbers, or state; inspect the repo first.
- Do not skip validation or checkpoint gates described in referenced workflows.
- If required context is missing, ask focused questions (one small batch) and proceed after answers.

# Source (path to original Claude command file)
- C:\Users\rjain\.claude\commands\gsd\progress.md
