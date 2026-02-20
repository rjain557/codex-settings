---
name: gsd:sdlc-gate
description: Check entrance/exit criteria for an SDLC phase (A-R)
argument-hint: "<phase-letter> [entrance|exit]"
allowed-tools:
  - Read
  - Bash
  - Grep
  - Glob
  - Task
---

<objective>
Validate SDLC phase entrance or exit criteria against the current codebase.

Given a phase letter (A-R) and direction (entrance or exit), spawn the sdlc-gate-validator agent to check every criterion and produce a structured pass/fail report.

Orchestrator role: Parse the phase letter and direction, validate inputs, spawn agent, present results.
</objective>

<execution_context>
@docs/sdlc/docs/01_Technijian_SDLC_v6_0.md
@.planning/STATE.md
</execution_context>

<context>
Phase and direction: $ARGUMENTS (e.g., "F entrance", "G exit", or just "F" which defaults to entrance)

Valid phase letters: A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R

Phase name mapping:
- A=Intake & Requirements, B=Specification, C=UI Prototyping & Code Generation
- D=Business & Design Approval, E=Contract Freeze (SCG1), F=Validate Enhance & Build
- G=Completion & Release Readiness, H=Clone & Intake, I=Figma Design Update
- J=Spec Refresh, K=AI Code Update & Handoff, L=Alpha Deploy & Tests
- M=Beta UI Regression, N=DB Rehearsal, O=DB Promote, P=RTM UI Beta
- Q=Go Live, R=Closeout & Telemetry Pruning
</context>

<process>

## 1. Parse Arguments

Extract phase letter and direction from $ARGUMENTS.
- If only a letter provided, default direction to "entrance"
- Validate letter is A-R (case insensitive, normalize to uppercase)
- If invalid: show error with usage: `/gsd:sdlc-gate <A-R> [entrance|exit]`

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

</process>

