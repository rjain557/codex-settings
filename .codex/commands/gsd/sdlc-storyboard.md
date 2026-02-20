---
name: gsd:sdlc-storyboard
description: Run storyboard-to-code generation pipeline (Phase F storyboard system)
argument-hint: "[--storyboard=id | --mode=validate|generate|regenerate]"
allowed-tools:
  - Read
  - Write
  - Bash
  - Grep
  - Glob
  - Task
  - AskUserQuestion
---

<objective>
Run the Phase F storyboard-driven full-stack code generation pipeline. Discovers Figma storyboard exports, generates production-ready code across all 7 layers (Frontend -> Controllers -> Services -> SPs -> Views -> Tables -> Seeds).

Orchestrator role: Gather configuration from user, spawn sdlc-storyboard-generator agent, present generation results and gap analysis.
</objective>

<execution_context>
@docs/sdlc/phase.f.storyboards/01-orchestrator.md
@docs/sdlc/phase.f.storyboards/README.md
@.planning/STATE.md
</execution_context>

<context>
Flags: $ARGUMENTS
- (no flags): Interactive mode â€” prompts user for configuration
- --storyboard=id: Process specific storyboard only
- --mode=validate: Check existing code against storyboards (read-only)
- --mode=generate: Generate only missing components
- --mode=regenerate: Regenerate all from storyboards (overwrites existing)
</context>

<process>

## 1. Parse Flags

Determine mode and any storyboard filter from $ARGUMENTS.

## 2. Gather Configuration (interactive mode)

If no flags or minimal flags, prompt user for:

Use AskUserQuestion to confirm:
- Storyboard location (default: design/storyboard/)
- Frontend target (default: src/Client/technijian-spa/)
- Backend target (default: src/Server/Technijian.Api/)
- Database target (default: db/)
- Execution mode if not specified (validate / generate / regenerate)

## 3. Check Specifications

Verify specification documents exist:
- docs/spec/openapi.yaml â€” API surface
- docs/spec/ui-contract.csv â€” Screen definitions
- docs/spec/apitospmap.csv â€” Endpoint-to-SP mapping
- docs/spec/db-plan.md â€” Database schema

Warn about any missing specs (generation quality depends on complete specs).

## 4. Spawn sdlc-storyboard-generator Agent

Spawn via Task tool:
- description: "SDLC Storyboard Pipeline ({mode})"
- prompt: Include mode, storyboard filter, configuration, and spec paths

The agent will:
1. Run pre-flight configuration validation
2. Discover storyboards and build catalog
3. Create per-storyboard agents with 7-layer task lists
4. Execute storyboard agents (parallel where independent)
5. Run full-stack validation
6. Produce generation manifest and gap analysis

## 5. Present Results

> **Storyboard Pipeline Complete** ({mode} mode)
> - Storyboards discovered: {N}
> - Storyboards processed: {M}
> - Layers generated: {count per layer}
> - Validation: {pass/fail with details}

If gaps found:
> **Gaps Found:** {N} missing components
> View gap analysis at: {path}

Offer next steps:
- "Run `/gsd:sdlc-enhance` to add production enhancements"
- "Run `/gsd:sdlc-validate` to check contract alignment"

</process>

