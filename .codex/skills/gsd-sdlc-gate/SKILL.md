---
name: gsd-sdlc-gate
description: Check entrance/exit criteria for an SDLC phase (A-R) Use when the user asks for 'gsd:sdlc-gate', 'gsd-sdlc-gate', or equivalent trigger phrases.
---

# Purpose
Validate SDLC phase entrance or exit criteria against the current codebase.

Given a phase letter (A-R) and direction (entrance or exit), spawn the sdlc-gate-validator agent to check every criterion and produce a structured pass/fail report.

Orchestrator role: Parse the phase letter and direction, validate inputs, spawn agent, present results.

# When to use
Use when the user requests the original gsd:sdlc-gate flow (for example: $gsd-sdlc-gate).
Also use on natural-language requests that match this behavior: Check entrance/exit criteria for an SDLC phase (A-R)

# Inputs
The user's text after invoking $gsd-sdlc-gate is the arguments. Parse it into required fields; if any required field is missing, ask targeted follow-up questions.
Expected argument shape from source: <phase-letter> [entrance|exit].
Context from source:
```text
Phase and direction: <parsed-arguments> (e.g., "F entrance", "G exit", or just "F" which defaults to entrance)

Valid phase letters: A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R

Phase name mapping:
- A=Intake & Requirements, B=Specification, C=UI Prototyping & Code Generation
- D=Business & Design Approval, E=Contract Freeze (SCG1), F=Validate Enhance & Build
- G=Completion & Release Readiness, H=Clone & Intake, I=Figma Design Update
- J=Spec Refresh, K=AI Code Update & Handoff, L=Alpha Deploy & Tests
- M=Beta UI Regression, N=DB Rehearsal, O=DB Promote, P=RTM UI Beta
- Q=Go Live, R=Closeout & Telemetry Pruning
```

# Workflow
Load and follow these referenced artifacts first:
- @docs/sdlc/docs/01_Technijian_SDLC_v6_0.md
- @.planning/STATE.md
Then execute this process:
```text
## 1. Parse Arguments

Extract phase letter and direction from <parsed-arguments>.
- If only a letter provided, default direction to "entrance"
- Validate letter is A-R (case insensitive, normalize to uppercase)
- If invalid: show error with usage: `$gsd-sdlc-gate <A-R> [entrance|exit]`

## 2. Spawn sdlc-gate-validator Agent

Spawn via Task tool:
- description: "SDLC Gate: Phase {letter} {direction}"
- subagent_type: use the sdlc-gate-validator agent definition
- prompt: Include phase letter, phase name, direction, and reference to SDLC master doc

The agent will:
1. Read the SDLC master document for the phase
2. Extract entrance or exit criteria table
3. Verify each criterion against the codebase
4. Return a structured pass/fail report

## 3. Present Results

Display the gate validation report to the user.

If ALL criteria pass:
> Phase {letter} ({phase_name}) {direction} gate **PASSED**. Ready to proceed.

If any criteria failed:
> Phase {letter} ({phase_name}) {direction} gate **BLOCKED**. {N} of {M} criteria failed.
> {List each failure with its recommendation}

If exit gate failed, include routing:
> **Route to:** Phase {X} to resolve {issue type}
```

# Outputs / artifacts
Produce the artifacts specified by the workflow and summarize created/updated files.

# Guardrails (what not to do / how to ask for missing info)
- Do not invent missing project files, phase numbers, or state; inspect the repo first.
- Do not skip validation or checkpoint gates described in referenced workflows.
- If required context is missing, ask focused questions (one small batch) and proceed after answers.

# Source (path to original Claude command file)
- C:\Users\rjain\.claude\commands\gsd\sdlc-gate.md
