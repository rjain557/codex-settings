---
name: gsd-new-milestone
description: Start a new milestone cycle â€” update PROJECT.md and route to requirements Use when the user asks for 'gsd:new-milestone', 'gsd-new-milestone', or equivalent trigger phrases.
---

# Purpose
Start a new milestone: questioning â†’ research (optional) â†’ requirements â†’ roadmap.

Brownfield equivalent of new-project. Project exists, PROJECT.md has history. Gathers "what's next", updates PROJECT.md, then runs requirements â†’ roadmap cycle.

**Creates/Updates:**
- `.planning/PROJECT.md` â€” updated with new milestone goals
- `.planning/research/` â€” domain research (optional, NEW features only)
- `.planning/REQUIREMENTS.md` â€” scoped requirements for this milestone
- `.planning/ROADMAP.md` â€” phase structure (continues numbering)
- `.planning/STATE.md` â€” reset for new milestone

**After:** `$gsd-plan-phase [N]` to start execution.

# When to use
Use when the user requests the original gsd:new-milestone flow (for example: $gsd-new-milestone).
Also use on natural-language requests that match this behavior: Start a new milestone cycle â€” update PROJECT.md and route to requirements

# Inputs
The user's text after invoking $gsd-new-milestone is the arguments. Parse it into required fields; if any required field is missing, ask targeted follow-up questions.
Expected argument shape from source: [milestone name, e.g., 'v1.1 Notifications'].
Context from source:
```text
Milestone name: <parsed-arguments> (optional - will prompt if not provided)

**Load project context:**
@.planning/PROJECT.md
@.planning/STATE.md
@.planning/MILESTONES.md
@.planning/config.json

**Load milestone context (if exists, from $gsd-discuss-milestone):**
@.planning/MILESTONE-CONTEXT.md
```

# Workflow
Load and follow these referenced artifacts first:
- @C:/Users/rjain/.claude/get-shit-done/workflows/new-milestone.md
- @C:/Users/rjain/.claude/get-shit-done/references/questioning.md
- @C:/Users/rjain/.claude/get-shit-done/references/ui-brand.md
- @C:/Users/rjain/.claude/get-shit-done/templates/project.md
- @C:/Users/rjain/.claude/get-shit-done/templates/requirements.md
Then execute this process:
```text
Execute the new-milestone workflow from @C:/Users/rjain/.claude/get-shit-done/workflows/new-milestone.md end-to-end.
Preserve all workflow gates (validation, questioning, research, requirements, roadmap approval, commits).
```

# Outputs / artifacts
Produce the artifacts specified by the workflow and summarize created/updated files.

# Guardrails (what not to do / how to ask for missing info)
- Do not invent missing project files, phase numbers, or state; inspect the repo first.
- Do not skip validation or checkpoint gates described in referenced workflows.
- If required context is missing, ask focused questions (one small batch) and proceed after answers.

# Source (path to original Claude command file)
- C:\Users\rjain\.claude\commands\gsd\new-milestone.md
