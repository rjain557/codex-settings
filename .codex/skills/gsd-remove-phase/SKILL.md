---
name: gsd-remove-phase
description: Remove a future phase from roadmap and renumber subsequent phases Use when the user asks for 'gsd:remove-phase', 'gsd-remove-phase', or equivalent trigger phrases.
---

# Purpose
Remove an unstarted future phase from the roadmap and renumber all subsequent phases to maintain a clean, linear sequence.

Purpose: Clean removal of work you've decided not to do, without polluting context with cancelled/deferred markers.
Output: Phase deleted, all subsequent phases renumbered, git commit as historical record.

# When to use
Use when the user requests the original gsd:remove-phase flow (for example: $gsd-remove-phase).
Also use on natural-language requests that match this behavior: Remove a future phase from roadmap and renumber subsequent phases

# Inputs
The user's text after invoking $gsd-remove-phase is the arguments. Parse it into required fields; if any required field is missing, ask targeted follow-up questions.
Expected argument shape from source: <phase-number>.
Context from source:
```text
Phase: <parsed-arguments>

@.planning/ROADMAP.md
@.planning/STATE.md
```

# Workflow
Load and follow these referenced artifacts first:
- @C:/Users/rjain/.claude/get-shit-done/workflows/remove-phase.md
Then execute this process:
```text
Execute the remove-phase workflow from @C:/Users/rjain/.claude/get-shit-done/workflows/remove-phase.md end-to-end.
Preserve all validation gates (future phase check, work check), renumbering logic, and commit.
```

# Outputs / artifacts
Produce the artifacts specified by the workflow and summarize created/updated files.

# Guardrails (what not to do / how to ask for missing info)
- Do not invent missing project files, phase numbers, or state; inspect the repo first.
- Do not skip validation or checkpoint gates described in referenced workflows.
- If required context is missing, ask focused questions (one small batch) and proceed after answers.

# Source (path to original Claude command file)
- C:\Users\rjain\.claude\commands\gsd\remove-phase.md
