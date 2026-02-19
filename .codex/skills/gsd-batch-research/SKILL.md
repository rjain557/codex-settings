---
name: gsd-batch-research
description: Research all plans in a phase sequentially (headless-safe, no parallel agents) Use when the user asks for 'gsd:batch-research', 'gsd-batch-research', or equivalent trigger phrases.
---

# Purpose
Research all plans in a phase sequentially, one at a time. Headless-safe variant that avoids parallel Task spawning.

Use this instead of research-phase when running via `claude -p` (headless mode), PowerShell/bash automation scripts, CI/CD pipelines, or any non-interactive environment where parallel subagents die when the parent process exits.

Each plan is researched by a fresh gsd-phase-researcher agent. Plans run one at a time -- never multiple in the same message. This prevents the headless-mode race condition.

# When to use
Use when the user requests the original gsd:batch-research flow (for example: $gsd-batch-research).
Also use on natural-language requests that match this behavior: Research all plans in a phase sequentially (headless-safe, no parallel agents)

# Inputs
The user's text after invoking $gsd-batch-research is the arguments. Parse it into required fields; if any required field is missing, ask targeted follow-up questions.
Expected argument shape from source: <phase-number>.
Context from source:
```text
Phase: <parsed-arguments>

@.planning/ROADMAP.md
@.planning/STATE.md
```

# Workflow
Load and follow these referenced artifacts first:
- @C:/Users/rjain/.claude/get-shit-done/workflows/research-phase.md
- @C:/Users/rjain/.claude/get-shit-done/references/ui-brand.md
Then execute this process:
```text
## Step 0: Resolve Phase

Parse <parsed-arguments> to get the phase number. Look up all plans for this phase in ROADMAP.md.

## Step 1: Enumerate Plans

Find all plans listed under the target phase in ROADMAP.md. Build an ordered list of plan identifiers (e.g., 56-01, 56-02, 56-03).

## Step 2: Sequential Research Loop

For each plan in order:
1. Display which plan is being researched (e.g., "Researching plan 56-01...")
2. Spawn ONE gsd-phase-researcher Task agent for this plan
3. Wait for completion before proceeding to the next plan
4. CRITICAL: Never spawn more than one Task agent per message

## Step 3: Summary

After all plans are researched:
1. Display a summary of all research outputs
2. Offer next steps: "Run `$gsd-batch-plan` to create plans from research"

Key constraint: NEVER spawn more than one Task agent per message. This is critical for headless reliability.
```

# Outputs / artifacts
Produce the artifacts specified by the workflow and summarize created/updated files.

# Guardrails (what not to do / how to ask for missing info)
- Do not invent missing project files, phase numbers, or state; inspect the repo first.
- Do not skip validation or checkpoint gates described in referenced workflows.
- If required context is missing, ask focused questions (one small batch) and proceed after answers.

# Source (path to original Claude command file)
- C:\Users\rjain\.claude\commands\gsd\batch-research.md
