---
name: gsd-execute-phase
description: Execute all plans in a phase with wave-based parallelization Use when the user asks for 'gsd:execute-phase', 'gsd-execute-phase', or equivalent trigger phrases.
---

# Purpose
Execute all plans in a phase using wave-based parallel execution.

Orchestrator stays lean: discover plans, analyze dependencies, group into waves, spawn subagents, collect results. Each subagent loads the full execute-plan context and handles its own plan.

Context budget: ~15% orchestrator, 100% fresh per subagent.

# When to use
Use when the user requests the original gsd:execute-phase flow (for example: $gsd-execute-phase).
Also use on natural-language requests that match this behavior: Execute all plans in a phase with wave-based parallelization

# Inputs
The user's text after invoking $gsd-execute-phase is the arguments. Parse it into required fields; if any required field is missing, ask targeted follow-up questions.
Expected argument shape from source: <phase-number> [--gaps-only].
Context from source:
```text
Phase: <parsed-arguments>

**Flags:**
- `--gaps-only` â€” Execute only gap closure plans (plans with `gap_closure: true` in frontmatter). Use after verify-work creates fix plans.

@.planning/ROADMAP.md
@.planning/STATE.md
```

# Workflow
Load and follow these referenced artifacts first:
- @C:/Users/rjain/.codex/get-shit-done/workflows/execute-phase.md
- @C:/Users/rjain/.codex/get-shit-done/references/ui-brand.md
Then execute this process:
```text
Execute the execute-phase workflow from @C:/Users/rjain/.codex/get-shit-done/workflows/execute-phase.md end-to-end.
Preserve all workflow gates (wave execution, checkpoint handling, verification, state updates, routing).
```

# Outputs / artifacts
Produce the artifacts specified by the workflow and summarize created/updated files.

# Guardrails (what not to do / how to ask for missing info)
- Do not invent missing project files, phase numbers, or state; inspect the repo first.
- Do not skip validation or checkpoint gates described in referenced workflows.
- If required context is missing, ask focused questions (one small batch) and proceed after answers.

# Source (path to original Codex command file)
- C:\Users\rjain\.codex\commands\gsd\execute-phase.md

