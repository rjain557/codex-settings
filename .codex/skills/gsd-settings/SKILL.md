---
name: gsd-settings
description: Configure GSD workflow toggles and model profile Use when the user asks for 'gsd:settings', 'gsd-settings', or equivalent trigger phrases.
---

# Purpose
Interactive configuration of GSD workflow agents and model profile via multi-question prompt.

Routes to the settings workflow which handles:
- Config existence ensuring
- Current settings reading and parsing
- Interactive 5-question prompt (model, research, plan_check, verifier, branching)
- Config merging and writing
- Confirmation display with quick command references

# When to use
Use when the user requests the original gsd:settings flow (for example: $gsd-settings).
Also use on natural-language requests that match this behavior: Configure GSD workflow toggles and model profile

# Inputs
No required positional arguments. If the request lacks needed context, ask concise targeted questions before proceeding.

# Workflow
Load and follow these referenced artifacts first:
- @C:/Users/rjain/.codex/get-shit-done/workflows/settings.md
Then execute this process:
```text
**Follow the settings workflow** from `@C:/Users/rjain/.codex/get-shit-done/workflows/settings.md`.

The workflow handles all logic including:
1. Config file creation with defaults if missing
2. Current config reading
3. Interactive settings presentation with pre-selection
4. Answer parsing and config merging
5. File writing
6. Confirmation display
```

# Outputs / artifacts
Produce the artifacts specified by the workflow and summarize created/updated files.

# Guardrails (what not to do / how to ask for missing info)
- Do not invent missing project files, phase numbers, or state; inspect the repo first.
- Do not skip validation or checkpoint gates described in referenced workflows.
- If required context is missing, ask focused questions (one small batch) and proceed after answers.

# Source (path to original Codex command file)
- C:\Users\rjain\.codex\commands\gsd\settings.md

