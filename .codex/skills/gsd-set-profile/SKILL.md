---
name: gsd-set-profile
description: Switch model profile for GSD agents (quality/balanced/budget) Use when the user asks for 'gsd:set-profile', 'gsd-set-profile', or equivalent trigger phrases.
---

# Purpose
Switch the model profile used by GSD agents. Controls which Claude model each agent uses, balancing quality vs token spend.

Routes to the set-profile workflow which handles:
- Argument validation (quality/balanced/budget)
- Config file creation if missing
- Profile update in config.json
- Confirmation with model table display

# When to use
Use when the user requests the original gsd:set-profile flow (for example: $gsd-set-profile).
Also use on natural-language requests that match this behavior: Switch model profile for GSD agents (quality/balanced/budget)

# Inputs
The user's text after invoking $gsd-set-profile is the arguments. Parse it into required fields; if any required field is missing, ask targeted follow-up questions.
Expected argument shape from source: <profile>.

# Workflow
Load and follow these referenced artifacts first:
- @C:/Users/rjain/.claude/get-shit-done/workflows/set-profile.md
Then execute this process:
```text
**Follow the set-profile workflow** from `@C:/Users/rjain/.claude/get-shit-done/workflows/set-profile.md`.

The workflow handles all logic including:
1. Profile argument validation
2. Config file ensuring
3. Config reading and updating
4. Model table generation from MODEL_PROFILES
5. Confirmation display
```

# Outputs / artifacts
Produce the artifacts specified by the workflow and summarize created/updated files.

# Guardrails (what not to do / how to ask for missing info)
- Do not invent missing project files, phase numbers, or state; inspect the repo first.
- Do not skip validation or checkpoint gates described in referenced workflows.
- If required context is missing, ask focused questions (one small batch) and proceed after answers.

# Source (path to original Claude command file)
- C:\Users\rjain\.claude\commands\gsd\set-profile.md
