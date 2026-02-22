---
name: gsd-new-project
description: Initialize a new project with deep context gathering and PROJECT.md Use when the user asks for 'gsd:new-project', 'gsd-new-project', or equivalent trigger phrases.
---

# Purpose
Initialize a new project through unified flow: questioning â†’ research (optional) â†’ requirements â†’ roadmap.

**Creates:**
- `.planning/PROJECT.md` â€” project context
- `.planning/config.json` â€” workflow preferences
- `.planning/research/` â€” domain research (optional)
- `.planning/REQUIREMENTS.md` â€” scoped requirements
- `.planning/ROADMAP.md` â€” phase structure
- `.planning/STATE.md` â€” project memory

**After this command:** Run `$gsd-plan-phase 1` to start execution.

# When to use
Use when the user requests the original gsd:new-project flow (for example: $gsd-new-project).
Also use on natural-language requests that match this behavior: Initialize a new project with deep context gathering and PROJECT.md

# Inputs
The user's text after invoking $gsd-new-project is the arguments. Parse it into required fields; if any required field is missing, ask targeted follow-up questions.
Expected argument shape from source: [--auto].
Context from source:
```text
**Flags:**
- `--auto` â€” Automatic mode. After config questions, runs research â†’ requirements â†’ roadmap without further interaction. Expects idea document via @ reference.
```

# Workflow
Load and follow these referenced artifacts first:
- @C:/Users/rjain/.claude/get-shit-done/workflows/new-project.md
- @C:/Users/rjain/.claude/get-shit-done/references/questioning.md
- @C:/Users/rjain/.claude/get-shit-done/references/ui-brand.md
- @C:/Users/rjain/.claude/get-shit-done/templates/project.md
- @C:/Users/rjain/.claude/get-shit-done/templates/requirements.md
Then execute this process:
```text
Execute the new-project workflow from @C:/Users/rjain/.claude/get-shit-done/workflows/new-project.md end-to-end.
Preserve all workflow gates (validation, approvals, commits, routing).
```

# Outputs / artifacts
Produce the artifacts specified by the workflow and summarize created/updated files.

# Guardrails (what not to do / how to ask for missing info)
- Do not invent missing project files, phase numbers, or state; inspect the repo first.
- Do not skip validation or checkpoint gates described in referenced workflows.
- If required context is missing, ask focused questions (one small batch) and proceed after answers.

# Source (path to original Claude command file)
- C:\Users\rjain\.claude\commands\gsd\new-project.md
