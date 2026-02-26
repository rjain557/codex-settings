---
name: gsd-sdlc-storyboard
description: Run storyboard-to-code generation pipeline (Phase F storyboard system) Use when the user asks for 'gsd:sdlc-storyboard', 'gsd-sdlc-storyboard', or equivalent trigger phrases.
---

# Purpose
Run the Phase F storyboard-driven full-stack code generation pipeline. Discovers Figma storyboard exports (17 deliverables from Figma Make), generates production-ready code across all 7 layers (Frontend -> Controllers -> Services -> SPs -> Views -> Tables -> Seeds).

Orchestrator role: Gather configuration from user, spawn sdlc-storyboard-generator agent, present generation results and gap analysis.

# When to use
Use when the user requests the original gsd:sdlc-storyboard flow (for example: $gsd-sdlc-storyboard).
Also use on natural-language requests that match this behavior: Run storyboard-to-code generation pipeline (Phase F storyboard system)

# Inputs
The user's text after invoking $gsd-sdlc-storyboard is the arguments. Parse it into required fields; if any required field is missing, ask targeted follow-up questions.
Expected argument shape from source: [--analysis=path] [--stubs=path] [--mode=validate|generate|regenerate].
Context from source:
```text
Flags: <parsed-arguments>
- (no flags): Interactive mode â€” prompts user for configuration
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
```

# Workflow
Load and follow these referenced artifacts first:
- @docs/sdlc/phase.f.storyboards/01-orchestrator.md
- @docs/sdlc/phase.f.storyboards/README.md
- @.planning/STATE.md
Execute the original command behavior end-to-end, preserving validation, routing, and update gates.

# Outputs / artifacts
Produce the artifacts specified by the workflow and summarize created/updated files.

# Guardrails (what not to do / how to ask for missing info)
- Do not invent missing project files, phase numbers, or state; inspect the repo first.
- Do not skip validation or checkpoint gates described in referenced workflows.
- If required context is missing, ask focused questions (one small batch) and proceed after answers.

# Source (path to original Codex command file)
- C:\Users\rjain\.codex\commands\gsd\sdlc-storyboard.md

