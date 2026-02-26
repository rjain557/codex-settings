---
name: gsd-help
description: Show available GSD commands and usage guide Use when the user asks for 'gsd:help', 'gsd-help', or equivalent trigger phrases.
---

# Purpose
Display the complete GSD command reference.

Output ONLY the reference content below. Do NOT add:
- Project-specific analysis
- Git status or file context
- Next-step suggestions
- Any commentary beyond the reference

# When to use
Use when the user requests the original gsd:help flow (for example: $gsd-help).
Also use on natural-language requests that match this behavior: Show available GSD commands and usage guide

# Inputs
No required positional arguments. If the request lacks needed context, ask concise targeted questions before proceeding.

# Workflow
Load and follow these referenced artifacts first:
- @C:/Users/rjain/.claude/get-shit-done/workflows/help.md
Then execute this process:
```text
Output the complete GSD command reference from @C:/Users/rjain/.claude/get-shit-done/workflows/help.md.
Display the reference content directly â€” no additions or modifications.
```

# Outputs / artifacts
Produce the artifacts specified by the workflow and summarize created/updated files.

# Guardrails (what not to do / how to ask for missing info)
- Do not invent missing project files, phase numbers, or state; inspect the repo first.
- Do not skip validation or checkpoint gates described in referenced workflows.
- If required context is missing, ask focused questions (one small batch) and proceed after answers.

# Source (path to original Claude command file)
- C:\Users\rjain\.claude\commands\gsd\help.md
