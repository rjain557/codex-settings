---
name: gsd-add-todo
description: Capture idea or task as todo from current conversation context Use when the user asks for 'gsd:add-todo', 'gsd-add-todo', or equivalent trigger phrases.
---

# Purpose
Capture an idea, task, or issue that surfaces during a GSD session as a structured todo for later work.

Routes to the add-todo workflow which handles:
- Directory structure creation
- Content extraction from arguments or conversation
- Area inference from file paths
- Duplicate detection and resolution
- Todo file creation with frontmatter
- STATE.md updates
- Git commits

# When to use
Use when the user requests the original gsd:add-todo flow (for example: $gsd-add-todo).
Also use on natural-language requests that match this behavior: Capture idea or task as todo from current conversation context

# Inputs
The user's text after invoking $gsd-add-todo is the arguments. Parse it into required fields; if any required field is missing, ask targeted follow-up questions.
Expected argument shape from source: [optional description].

# Workflow
Load and follow these referenced artifacts first:
- @.planning/STATE.md
- @C:/Users/rjain/.claude/get-shit-done/workflows/add-todo.md
Then execute this process:
```text
**Follow the add-todo workflow** from `@C:/Users/rjain/.claude/get-shit-done/workflows/add-todo.md`.

The workflow handles all logic including:
1. Directory ensuring
2. Existing area checking
3. Content extraction (arguments or conversation)
4. Area inference
5. Duplicate checking
6. File creation with slug generation
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
- C:\Users\rjain\.claude\commands\gsd\add-todo.md
