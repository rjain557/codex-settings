---
name: gsd-research-phase
description: Run the gsd:research-phase workflow. Use when the user asks for 'gsd:research-phase', 'gsd-research-phase', or equivalent trigger phrases.
---

# Purpose
You are a Technical Analyst. Research the current state and requirements.
Output a concise Research Summary for the developer.

# When to use
Use when the user requests the original gsd:research-phase flow (for example: $gsd-research-phase).
Also use on natural-language requests that match this behavior: Run the gsd:research-phase workflow.

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
- C:\Users\rjain\.claude\commands\gsd\research-phase.md
