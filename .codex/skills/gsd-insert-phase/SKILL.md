---
name: gsd-insert-phase
description: Insert urgent work as decimal phase (e.g., 72.1) between existing phases Use when the user asks for 'gsd:insert-phase', 'gsd-insert-phase', or equivalent trigger phrases.
---

# Purpose
Insert a decimal phase for urgent work discovered mid-milestone that must be completed between existing integer phases.

Uses decimal numbering (72.1, 72.2, etc.) to preserve the logical sequence of planned phases while accommodating urgent insertions.

Purpose: Handle urgent work discovered during execution without renumbering entire roadmap.

# When to use
Use when the user requests the original gsd:insert-phase flow (for example: $gsd-insert-phase).
Also use on natural-language requests that match this behavior: Insert urgent work as decimal phase (e.g., 72.1) between existing phases

# Inputs
The user's text after invoking $gsd-insert-phase is the arguments. Parse it into required fields; if any required field is missing, ask targeted follow-up questions.
Expected argument shape from source: <after> <description>.
Context from source:
```text
Arguments: <parsed-arguments> (format: <after-phase-number> <description>)

@.planning/ROADMAP.md
@.planning/STATE.md
```

# Workflow
Load and follow these referenced artifacts first:
- @C:/Users/rjain/.claude/get-shit-done/workflows/insert-phase.md
Then execute this process:
```text
Execute the insert-phase workflow from @C:/Users/rjain/.claude/get-shit-done/workflows/insert-phase.md end-to-end.
Preserve all validation gates (argument parsing, phase verification, decimal calculation, roadmap updates).
```

# Outputs / artifacts
Produce the artifacts specified by the workflow and summarize created/updated files.

# Guardrails (what not to do / how to ask for missing info)
- Do not invent missing project files, phase numbers, or state; inspect the repo first.
- Do not skip validation or checkpoint gates described in referenced workflows.
- If required context is missing, ask focused questions (one small batch) and proceed after answers.

# Source (path to original Claude command file)
- C:\Users\rjain\.claude\commands\gsd\insert-phase.md
