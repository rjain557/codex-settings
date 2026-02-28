---
name: gsd:sdlc-storyboard
description: Run storyboard-to-code generation pipeline (Phase F storyboard system)
argument-hint: "[--analysis=path] [--stubs=path] [--mode=validate|generate|regenerate]"
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
Run the Phase F storyboard-driven full-stack code generation pipeline. Discovers Figma storyboard exports (17 deliverables from Figma Make), generates production-ready code across all 7 layers (Frontend -> Controllers -> Services -> SPs -> Views -> Tables -> Seeds).

Orchestrator role: Gather configuration from user, spawn sdlc-storyboard-generator agent, present generation results and gap analysis.
</objective>

<execution_context>
@docs/sdlc/phase.f.storyboards/01-orchestrator.md
@docs/sdlc/phase.f.storyboards/README.md
@.planning/STATE.md
</execution_context>

<context>
Flags: $ARGUMENTS
- (no flags): Interactive mode — prompts user for configuration
- --analysis=path: Path to _analysis folder (default: _analysis/)
- --stubs=path: Path to _stubs folder (default: _stubs/)
- --mode=validate: Check existing code against storyboards (read-only)
- --mode=generate: Generate only missing components
- --mode=regenerate: Regenerate all from storyboards (overwrites existing)

**NEW: Figma Make 17-Deliverable Format**
The skill now supports the complete Figma Make output:
- _analysis/ (12 documents)
  - 01-screen-inventory.md
  - 02-component-inventory.md
  - 03-design-system.md
  - 04-navigation-routing.md
  - 05-data-types.md
  - 06-api-contracts.md
  - 07-hooks-state.md
  - 08-mock-data-catalog.md
  - 09-storyboards.md
  - 10-screen-state-matrix.md
  - 11-api-to-sp-map.md
  - 12-implementation-guide.md
- _stubs/ (N files + 3 DB scripts)
  - backend/Controllers/*.cs
  - backend/Models/*.cs
  - database/01-tables.sql
  - database/02-stored-procedures.sql
  - database/03-seed-data.sql
</context>

<process>

## 1. Parse Flags

Determine mode, analysis path, and stubs path from $ARGUMENTS.

## 2. Discover Figma Make Deliverables

Check for the new 17-deliverable format:
- Look for `_analysis/` folder with analysis documents
- Look for `_stubs/` folder with backend/database stubs

If found, validate all 17 deliverables exist:
| Deliverable | File | Purpose |
|-------------|------|---------|
| D1 | 01-screen-inventory.md | All screens, routes, layouts |
| D2 | 02-component-inventory.md | Reusable components |
| D3 | 03-design-system.md | Colors, typography, spacing, tokens |
| D4 | 04-navigation-routing.md | Navigation tree, routes |
| D5 | 05-data-types.md | TypeScript interfaces |
| D6 | 06-api-contracts.md | API endpoints |
| D7 | 07-hooks-state.md | Custom hooks |
| D8 | 08-mock-data-catalog.md | Mock data shapes |
| D9 | 09-storyboards.md | User flows |
| D10 | 10-screen-state-matrix.md | Screen states |
| D11 | 11-api-to-sp-map.md | Frontend → API → SP → Table mapping |
| D12 | 12-implementation-guide.md | Build order |
| D13 | _stubs/database/01-tables.sql | CREATE TABLE statements |
| D14 | _stubs/database/02-stored-procedures.sql | SP stubs |
| D15 | _stubs/database/03-seed-data.sql | INSERT statements |
| D16 | _stubs/backend/Controllers/*.cs | Controller stubs |
| D17 | _stubs/backend/Models/*.cs | DTO stubs |

## 3. Gather Configuration (interactive mode)

If no flags or minimal flags, prompt user for:

Use AskUserQuestion to confirm:
- Analysis folder location (default: _analysis/)
- Stubs folder location (default: _stubs/)
- Frontend target (default: src/Client/technijian-spa/)
- Backend target (default: src/Server/Technijian.Api/)
- Database target (default: db/)
- Execution mode if not specified (validate / generate / regenerate)

## 4. Spawn sdlc-storyboard-generator Agent

Spawn via Task tool:
- description: "SDLC Storyboard Pipeline (Figma Make {mode})"
- prompt: Include mode, analysis path, stubs path, and configuration

The agent will:
1. Validate all 17 deliverables exist and are complete
2. Map analysis documents to code generation tasks
3. For each storyboard/feature:
   - Generate Tables (D13) → Seed Data (D15) → Stored Procedures (D14) → DTOs (D17) → Controllers (D16) → Frontend
4. Run full-stack validation
5. Produce generation manifest and gap analysis

## 5. Present Results

> **Storyboard Pipeline Complete** ({mode} mode)
> - Analysis documents: {N}/12
> - Stubs processed: {M}
> - Layers generated: {count per layer}
> - Validation: {pass/fail with details}

If gaps found:
> **Gaps Found:** {N} missing components
> View gap analysis at: {path}

Offer next steps:
- "Run `/gsd:sdlc-enhance` to add production enhancements"
- "Run `/gsd:sdlc-validate` to check contract alignment"

