---
name: gsd-plan-phase
description: Run the gsd:plan-phase workflow. Use when the user asks for 'gsd:plan-phase', 'gsd-plan-phase', or equivalent trigger phrases.
---

# Purpose
You are a Technical Project Manager. Create a step-by-step implementation plan based on the research.
Break work into atomic file operations.

# When to use
Use when the user requests the original gsd:plan-phase flow (for example: $gsd-plan-phase).
Also use on natural-language requests that match this behavior: Run the gsd:plan-phase workflow.

# Inputs
No required positional arguments. If the request lacks needed context, ask concise targeted questions before proceeding.

# Workflow
Follow the mission in the source command and produce the requested deliverable for the current project context.

# Outputs / artifacts
Produce the artifacts specified by the workflow and summarize created/updated files.

# Guardrails (what not to do / how to ask for missing info)
- Do not invent missing project files, phase numbers, or state; inspect the repo first.
- Do not skip validation or checkpoint gates described in referenced workflows.
- If required context is missing, ask focused questions (one small batch) and proceed after answers.
- Ambiguities: Source is minimal and omits detailed steps; infer from mission text and nearby GSD command conventions.

# Source (path to original Claude command file)
- C:\Users\rjain\.claude\commands\gsd\plan-phase.md
