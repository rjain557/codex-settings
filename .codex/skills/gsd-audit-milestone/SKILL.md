---
name: gsd-audit-milestone
description: Audit milestone completion against original intent before archiving Use when the user asks for 'gsd:audit-milestone', 'gsd-audit-milestone', or equivalent trigger phrases.
---

# Purpose
Verify milestone achieved its definition of done. Check requirements coverage, cross-phase integration, and end-to-end flows.

**This command IS the orchestrator.** Reads existing VERIFICATION.md files (phases already verified during execute-phase), aggregates tech debt and deferred gaps, then spawns integration checker for cross-phase wiring.

# When to use
Use when the user requests the original gsd:audit-milestone flow (for example: $gsd-audit-milestone).
Also use on natural-language requests that match this behavior: Audit milestone completion against original intent before archiving

# Inputs
The user's text after invoking $gsd-audit-milestone is the arguments. Parse it into required fields; if any required field is missing, ask targeted follow-up questions.
Expected argument shape from source: [version].
Context from source:
```text
Version: <parsed-arguments> (optional â€” defaults to current milestone)

**Original Intent:**
@.planning/PROJECT.md
@.planning/REQUIREMENTS.md

**Planned Work:**
@.planning/ROADMAP.md
@.planning/config.json (if exists)

**Completed Work:**
Glob: .planning/phases/*/*-SUMMARY.md
Glob: .planning/phases/*/*-VERIFICATION.md
```

# Workflow
Load and follow these referenced artifacts first:
- @C:/Users/rjain/.claude/get-shit-done/workflows/audit-milestone.md
Then execute this process:
```text
Execute the audit-milestone workflow from @C:/Users/rjain/.claude/get-shit-done/workflows/audit-milestone.md end-to-end.
Preserve all workflow gates (scope determination, verification reading, integration check, requirements coverage, routing).
```

# Outputs / artifacts
Produce the artifacts specified by the workflow and summarize created/updated files.

# Guardrails (what not to do / how to ask for missing info)
- Do not invent missing project files, phase numbers, or state; inspect the repo first.
- Do not skip validation or checkpoint gates described in referenced workflows.
- If required context is missing, ask focused questions (one small batch) and proceed after answers.

# Source (path to original Claude command file)
- C:\Users\rjain\.claude\commands\gsd\audit-milestone.md
