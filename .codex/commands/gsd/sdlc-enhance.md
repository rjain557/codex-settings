---
name: gsd:sdlc-enhance
description: Run Phase F multi-agent enhancement pipeline (component detection + wave-based enhancement)
argument-hint: "[--detect-only | --wave=N | --component=name]"
allowed-tools:
  - Read
  - Write
  - Bash
  - Grep
  - Glob
  - Task
---

<objective>
Run the Phase F multi-agent enhancement pipeline. Detects repository components (DB, API, MCP, Web, Admin, Agent), calculates dependency waves, and spawns enhancement agents to add production-grade security, logging, error handling, and compliance features.

Orchestrator role: Parse flags, check prerequisites, spawn sdlc-enhancer agent, monitor wave progress, present completion report.
</objective>

<execution_context>
@docs/sdlc/phase.f.multiagent/phase-f-orchestrate.md
@docs/sdlc/phase.f.multiagent/CLAUDE.md
@.planning/STATE.md
</execution_context>

<context>
Flags: $ARGUMENTS
- (no flags): Full Phase F — detect all components + run all waves
- --detect-only: Component detection only (no enhancement, safe/read-only)
- --wave=N: Execute specific wave only (1=DB, 2=API, 3=MCP, 4=Presentation, 5=Testing)
- --component=name: Enhance specific component only (database, api, mcp, admin, web, agent)
</context>

<process>

## 1. Parse Flags

Determine execution mode from $ARGUMENTS.

## 2. Check Prerequisites (skip for --detect-only)

Verify Phase E contract artifacts exist:
- docs/spec/openapi.yaml — needed for API and client enhancement
- docs/spec/apitospmap.csv — needed for SP-Only verification

If missing: warn that frozen contracts are required for full enhancement. Suggest running Phase E or `/gsd:sdlc-gate E exit` first.

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
- "Run `/gsd:sdlc-review` to validate enhanced code"
- "Run `/gsd:sdlc-validate` for SpecSync check"
- "Run `/gsd:sdlc-gate G entrance` to check Phase G readiness"

</process>
