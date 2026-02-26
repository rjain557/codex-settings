---
name: gsd-sdlc-validate
description: Run SpecSync contract validation (OpenAPI <-> API-SP Map <-> Controllers <-> DTOs <-> SPs) Use when the user asks for 'gsd:sdlc-validate', 'gsd-sdlc-validate', or equivalent trigger phrases.
---

# Purpose
Run contract/SpecSync validation across the entire chain. Detects mismatches between OpenAPI, API-SP Map, controllers, DTOs, stored procedures, and typed clients.

Orchestrator role: Parse flags, spawn sdlc-contract-validator agent, present results with actionable fix recommendations.

# When to use
Use when the user requests the original gsd:sdlc-validate flow (for example: $gsd-sdlc-validate).
Also use on natural-language requests that match this behavior: Run SpecSync contract validation (OpenAPI <-> API-SP Map <-> Controllers <-> DTOs <-> SPs)

# Inputs
The user's text after invoking $gsd-sdlc-validate is the arguments. Parse it into required fields; if any required field is missing, ask targeted follow-up questions.
Expected argument shape from source: [--full | --dto-only | --sp-only].
Context from source:
```text
Flags: <parsed-arguments>
- (no flags): Full chain validation
- --dto-only: Only validate DTO-Model property matching
- --sp-only: Only validate SP existence and parameter matching
- --full: Explicit full chain validation (same as no flags)
```

# Workflow
Load and follow these referenced artifacts first:
- @docs/sdlc/docs/01_Technijian_SDLC_v6_0.md
- @.planning/STATE.md
Then execute this process:
```text
## 1. Parse Flags

Determine validation scope from <parsed-arguments>:
- Default or --full: validate entire chain
- --dto-only: only DTO-Model property matching
- --sp-only: only SP existence and parameter matching

## 2. Quick Prerequisite Check

Verify contract artifacts exist before spawning agent:
- docs/spec/openapi.yaml (or .json)
- docs/spec/apitospmap.csv

If neither exists: warn user that no contract artifacts found and suggest running Phase E first.

## 3. Spawn sdlc-contract-validator Agent

Spawn via Task tool:
- description: "SDLC SpecSync Validation ({scope})"
- prompt: Include scope (full/dto-only/sp-only) and paths to contract artifacts

The agent will:
1. Locate and parse all contract artifacts
2. Validate each chain link based on scope
3. Check DTO-Model property matching (MANDATORY)
4. Verify SP-Only compliance
5. Return a SpecSync report with all mismatches

## 4. Present Results

If zero mismatches:
> SpecSync validation **PASSED**. Contract chain is consistent across all layers.

If mismatches found:
> SpecSync found **{N} mismatches** across the contract chain.
> - {count} CRITICAL | {count} HIGH | {count} MEDIUM
>
> Top issues:
> {List top 5 mismatches with file paths and fix recommendations}

Offer next steps:
- "Run `$gsd-sdlc-review` for comprehensive code review"
- "Run `$gsd-sdlc-gate G exit` to check Phase G readiness"
```

# Outputs / artifacts
Produce the artifacts specified by the workflow and summarize created/updated files.

# Guardrails (what not to do / how to ask for missing info)
- Do not invent missing project files, phase numbers, or state; inspect the repo first.
- Do not skip validation or checkpoint gates described in referenced workflows.
- If required context is missing, ask focused questions (one small batch) and proceed after answers.

# Source (path to original Codex command file)
- C:\Users\rjain\.codex\commands\gsd\sdlc-validate.md

