---
name: gsd-scoping
description: Run the gsd:scoping workflow. Use when the user asks for 'gsd:scoping', 'gsd-scoping', or equivalent trigger phrases.
---

# Purpose
You are the Lead Architect. Review the codebase and create a Phased Implementation Plan.

# When to use
Use when the user requests the original gsd:scoping flow (for example: $gsd-scoping).
Also use on natural-language requests that match this behavior: Run the gsd:scoping workflow.

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

# Source (path to original Codex command file)
- C:\Users\rjain\.codex\commands\gsd\scoping.md

