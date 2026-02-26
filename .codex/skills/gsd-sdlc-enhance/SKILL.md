---
name: gsd-sdlc-enhance
description: Run Phase F multi-agent enhancement pipeline (component detection + wave-based enhancement) Use when the user asks for 'gsd:sdlc-enhance', 'gsd-sdlc-enhance', or equivalent trigger phrases.
---

# Purpose
Run the Phase F multi-agent enhancement pipeline. Detects repository components (DB, API, MCP, Web, Admin, Agent), calculates dependency waves, and spawns enhancement agents to add production-grade security, logging, error handling, and compliance features.

Orchestrator role: Parse flags, check prerequisites, spawn sdlc-enhancer agent, monitor wave progress, present completion report.

# When to use
Use when the user requests the original gsd:sdlc-enhance flow (for example: $gsd-sdlc-enhance).
Also use on natural-language requests that match this behavior: Run Phase F multi-agent enhancement pipeline (component detection + wave-based enhancement)

# Inputs
The user's text after invoking $gsd-sdlc-enhance is the arguments. Parse it into required fields; if any required field is missing, ask targeted follow-up questions.
Expected argument shape from source: [--detect-only | --wave=N | --component=name].
Context from source:
```text
Flags: <parsed-arguments>
- (no flags): Full Phase F â€” detect all components + run all waves
- --detect-only: Component detection only (no enhancement, safe/read-only)
- --wave=N: Execute specific wave only (1=DB, 2=API, 3=MCP, 4=Presentation, 5=Testing)
- --component=name: Enhance specific component only (database, api, mcp, admin, web, agent)
```

# Workflow
Load and follow these referenced artifacts first:
- @docs/sdlc/phase.f.multiagent/phase-f-orchestrate.md
- @docs/sdlc/phase.f.multiagent/Codex.md
- @.planning/STATE.md
Then execute this process:
```text
## 1. Parse Flags

Determine execution mode from <parsed-arguments>.

## 2. Check Prerequisites (skip for --detect-only)

Verify Phase E contract artifacts exist:
- docs/spec/openapi.yaml â€” needed for API and client enhancement
- docs/spec/apitospmap.csv â€” needed for SP-Only verification

If missing: warn that frozen contracts are required for full enhancement. Suggest running Phase E or `$gsd-sdlc-gate E exit` first.

## 3. Spawn sdlc-enhancer Agent

Spawn via Task tool:
- description: "SDLC Phase F Enhancement ({mode})"
- prompt: Include mode, contract paths, and references to enhancement agent docs

The agent will:
1. Detect all 6 component types in the repository
2. Calculate waves based on detected components and dependencies
3. Spawn enhancement agents wave-by-wave (DB -> API -> MCP -> Presentation -> Testing)
4. Produce PHASE-F-COMPLETE.md with compliance checklist

## 4. Present Results

If detect-only:
> **Component Detection Complete**
> | Component | Detected | Location |
> {table of findings}

If enhancement complete:
> **Phase F Enhancement Complete**
> {N} components enhanced across {M} waves.
>
> Compliance: {checklist summary}

Offer next steps:
- "Run `$gsd-sdlc-review` to validate enhanced code"
- "Run `$gsd-sdlc-validate` for SpecSync check"
- "Run `$gsd-sdlc-gate G entrance` to check Phase G readiness"
```

# Outputs / artifacts
Produce the artifacts specified by the workflow and summarize created/updated files.

# Guardrails (what not to do / how to ask for missing info)
- Do not invent missing project files, phase numbers, or state; inspect the repo first.
- Do not skip validation or checkpoint gates described in referenced workflows.
- If required context is missing, ask focused questions (one small batch) and proceed after answers.

# Source (path to original Codex command file)
- C:\Users\rjain\.codex\commands\gsd\sdlc-enhance.md

