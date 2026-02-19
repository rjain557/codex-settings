---
name: gsd-sdlc-review
description: Run comprehensive multi-agent code review pipeline (Phase G Code Debugger) Use when the user asks for 'gsd:sdlc-review', 'gsd-sdlc-review', or equivalent trigger phrases.
---

# Purpose
Run the Phase G comprehensive code review pipeline. Spawns parallel review agents for each code layer, builds traceability matrix, and generates developer handoff with prioritized findings.

Orchestrator role: Parse options, spawn sdlc-code-reviewer agent, present findings summary.

# When to use
Use when the user requests the original gsd:sdlc-review flow (for example: $gsd-sdlc-review).
Also use on natural-language requests that match this behavior: Run comprehensive multi-agent code review pipeline (Phase G Code Debugger)

# Inputs
The user's text after invoking $gsd-sdlc-review is the arguments. Parse it into required fields; if any required field is missing, ask targeted follow-up questions.
Expected argument shape from source: [--layer=frontend|backend|database|auth].
Context from source:
```text
Options: <parsed-arguments>
- (no flags): Full review â€” all layers + traceability matrix + SDLC gap analysis
- --layer=frontend: Frontend layer only
- --layer=backend: Backend layer only
- --layer=database: Database layer only
- --layer=auth: Auth/SSO layer only
```

# Workflow
Load and follow these referenced artifacts first:
- @docs/sdlc/phase.g.codedebugger/code-debugger.md
- @.planning/STATE.md
Then execute this process:
```text
## 1. Parse Options

Determine review scope from <parsed-arguments>:
- Default: full review (all layers + cross-layer analysis)
- --layer=X: single layer review only

## 2. Spawn sdlc-code-reviewer Agent

Spawn via Task tool:
- description: "SDLC Code Review ({scope})"
- prompt: Include scope and reference to SDLC code debugger docs

The agent will:
1. Inventory the repository (Phase 0)
2. Spawn layer reviewers â€” 4 in parallel for full, or 1 for single-layer (Wave 1)
3. Spawn cross-layer agents â€” traceability + SDLC gaps (Wave 2, full only)
4. Spawn MCP reviewer if detected (Wave 3, conditional)
5. Run build verification (MANDATORY)
6. Consolidate findings into reports

Output locations:
- docs/review/EXECUTIVE-SUMMARY.md
- docs/review/FULL-REPORT.md
- docs/review/DEVELOPER-HANDOFF.md
- docs/review/PRIORITIZED-TASKS.md

## 3. Present Results

Display executive summary:
> **Code Review Complete** â€” Overall Health: {score}
>
> Findings: {blocker} Blocker | {high} High | {medium} Medium | {low} Low
>
> **Top 5 Risks:**
> 1. {risk description}
> ...

Offer next steps:
- "View full report at docs/review/FULL-REPORT.md"
- "View developer handoff at docs/review/DEVELOPER-HANDOFF.md"
- "Run `$gsd-sdlc-validate` to check contract consistency"
```

# Outputs / artifacts
Produce the artifacts specified by the workflow and summarize created/updated files.

# Guardrails (what not to do / how to ask for missing info)
- Do not invent missing project files, phase numbers, or state; inspect the repo first.
- Do not skip validation or checkpoint gates described in referenced workflows.
- If required context is missing, ask focused questions (one small batch) and proceed after answers.

# Source (path to original Claude command file)
- C:\Users\rjain\.claude\commands\gsd\sdlc-review.md
