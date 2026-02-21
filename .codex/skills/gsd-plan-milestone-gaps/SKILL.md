---
name: gsd-plan-milestone-gaps
description: Create phases to close all gaps identified by milestone audit Use when the user asks for 'gsd:plan-milestone-gaps', 'gsd-plan-milestone-gaps', or equivalent trigger phrases.
---

# Purpose
Create all phases necessary to close gaps identified by `$gsd-audit-milestone`.

Reads MILESTONE-AUDIT.md, groups gaps into logical phases, creates phase entries in ROADMAP.md, and offers to plan each phase.

One command creates all fix phases â€” no manual `$gsd-add-phase` per gap.

# When to use
Use when the user requests the original gsd:plan-milestone-gaps flow (for example: $gsd-plan-milestone-gaps).
Also use on natural-language requests that match this behavior: Create phases to close all gaps identified by milestone audit

# Inputs
No required positional arguments. If the request lacks needed context, ask concise targeted questions before proceeding.
Context from source:
```text
**Audit results:**
Glob: .planning/v*-MILESTONE-AUDIT.md (use most recent)

**Original intent (for prioritization):**
@.planning/PROJECT.md
@.planning/REQUIREMENTS.md

**Current state:**
@.planning/ROADMAP.md
@.planning/STATE.md
```

# Workflow
Load and follow these referenced artifacts first:
- @C:/Users/rjain/.claude/get-shit-done/workflows/plan-milestone-gaps.md
Then execute this process:
```text
Execute the plan-milestone-gaps workflow from @C:/Users/rjain/.claude/get-shit-done/workflows/plan-milestone-gaps.md end-to-end.
Preserve all workflow gates (audit loading, prioritization, phase grouping, user confirmation, roadmap updates).
```

# Outputs / artifacts
Produce the artifacts specified by the workflow and summarize created/updated files.

# Guardrails (what not to do / how to ask for missing info)
- Do not invent missing project files, phase numbers, or state; inspect the repo first.
- Do not skip validation or checkpoint gates described in referenced workflows.
- If required context is missing, ask focused questions (one small batch) and proceed after answers.

# Source (path to original Claude command file)
- C:\Users\rjain\.claude\commands\gsd\plan-milestone-gaps.md
