---
name: gsd-add-phase
description: Add phase to end of current milestone in roadmap Use when the user asks for 'gsd:add-phase', 'gsd-add-phase', or equivalent trigger phrases.
---

# Purpose
Add a new integer phase to the end of the current milestone in the roadmap.

Routes to the add-phase workflow which handles:
- Phase number calculation (next sequential integer)
- Directory creation with slug generation
- Roadmap structure updates
- STATE.md roadmap evolution tracking

# When to use
Use when the user requests the original gsd:add-phase flow (for example: $gsd-add-phase).
Also use on natural-language requests that match this behavior: Add phase to end of current milestone in roadmap

# Inputs
The user's text after invoking $gsd-add-phase is the arguments. Parse it into required fields; if any required field is missing, ask targeted follow-up questions.
Expected argument shape from source: <description>.

# Workflow
Load and follow these referenced artifacts first:
- @.planning/ROADMAP.md
- @.planning/STATE.md
- @C:/Users/rjain/.codex/get-shit-done/workflows/add-phase.md
Then execute this process:
```text
**Follow the add-phase workflow** from `@C:/Users/rjain/.codex/get-shit-done/workflows/add-phase.md`.

The workflow handles all logic including:
1. Argument parsing and validation
2. Roadmap existence checking
3. Current milestone identification
4. Next phase number calculation (ignoring decimals)
5. Slug generation from description
6. Phase directory creation
7. Roadmap entry insertion
8. STATE.md updates
```

# Outputs / artifacts
Produce the artifacts specified by the workflow and summarize created/updated files.

# Guardrails (what not to do / how to ask for missing info)
- Do not invent missing project files, phase numbers, or state; inspect the repo first.
- Do not skip validation or checkpoint gates described in referenced workflows.
- If required context is missing, ask focused questions (one small batch) and proceed after answers.

# Source (path to original Codex command file)
- C:\Users\rjain\.codex\commands\gsd\add-phase.md

