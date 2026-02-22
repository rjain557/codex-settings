---
name: gsd-list-phase-assumptions
description: Surface Claude's assumptions about a phase approach before planning Use when the user asks for 'gsd:list-phase-assumptions', 'gsd-list-phase-assumptions', or equivalent trigger phrases.
---

# Purpose
Analyze a phase and present Claude's assumptions about technical approach, implementation order, scope boundaries, risk areas, and dependencies.

Purpose: Help users see what Claude thinks BEFORE planning begins - enabling course correction early when assumptions are wrong.
Output: Conversational output only (no file creation) - ends with "What do you think?" prompt

# When to use
Use when the user requests the original gsd:list-phase-assumptions flow (for example: $gsd-list-phase-assumptions).
Also use on natural-language requests that match this behavior: Surface Claude's assumptions about a phase approach before planning

# Inputs
The user's text after invoking $gsd-list-phase-assumptions is the arguments. Parse it into required fields; if any required field is missing, ask targeted follow-up questions.
Expected argument shape from source: [phase].
Context from source:
```text
Phase number: <parsed-arguments> (required)

**Load project state first:**
@.planning/STATE.md

**Load roadmap:**
@.planning/ROADMAP.md
```

# Workflow
Load and follow these referenced artifacts first:
- @C:/Users/rjain/.claude/get-shit-done/workflows/list-phase-assumptions.md
Then execute this process:
```text
1. Validate phase number argument (error if missing or invalid)
2. Check if phase exists in roadmap
3. Follow list-phase-assumptions.md workflow:
   - Analyze roadmap description
   - Surface assumptions about: technical approach, implementation order, scope, risks, dependencies
   - Present assumptions clearly
   - Prompt "What do you think?"
4. Gather feedback and offer next steps
```

# Outputs / artifacts
Produce the artifacts specified by the workflow and summarize created/updated files.

# Guardrails (what not to do / how to ask for missing info)
- Do not invent missing project files, phase numbers, or state; inspect the repo first.
- Do not skip validation or checkpoint gates described in referenced workflows.
- If required context is missing, ask focused questions (one small batch) and proceed after answers.

# Source (path to original Claude command file)
- C:\Users\rjain\.claude\commands\gsd\list-phase-assumptions.md
