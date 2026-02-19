---
name: gsd-gen-docker
description: Generate Dockerfiles, docker-compose, and container orchestration config Use when the user asks for 'gsd:gen-docker', 'gsd-gen-docker', or equivalent trigger phrases.
---

# Purpose
Generate Docker infrastructure for your project. Creates multi-stage Dockerfiles, docker-compose for local development, and optional Kubernetes manifests.

The user chooses:
- **Orchestration**: docker-compose only, docker-compose + Kubernetes, or Dockerfiles only

Tailored to: ASP.NET Core 8 (multi-stage .NET SDK â†’ runtime), React/Vite (Node â†’ nginx), SQL Server (dev container with auto-init).

# When to use
Use when the user requests the original gsd:gen-docker flow (for example: $gsd-gen-docker).
Also use on natural-language requests that match this behavior: Generate Dockerfiles, docker-compose, and container orchestration config

# Inputs
The user's text after invoking $gsd-gen-docker is the arguments. Parse it into required fields; if any required field is missing, ask targeted follow-up questions.
Expected argument shape from source: [--components <api|spa|db|all>] [--registry <acr|dockerhub|ghcr>].
Context from source:
```text
Target: <parsed-arguments> (optional flags)

@.planning/STATE.md
```

# Workflow
Load and follow these referenced artifacts first:
- @C:/Users/rjain/.claude/get-shit-done/workflows/gen-docker.md
Then execute this process:
```text
Execute the gen-docker workflow from @C:/Users/rjain/.claude/get-shit-done/workflows/gen-docker.md end-to-end.
Detect project components, generate optimized Dockerfiles with security best practices, and compose files for one-command local dev.
```

# Outputs / artifacts
Produce the artifacts specified by the workflow and summarize created/updated files.

# Guardrails (what not to do / how to ask for missing info)
- Do not invent missing project files, phase numbers, or state; inspect the repo first.
- Do not skip validation or checkpoint gates described in referenced workflows.
- If required context is missing, ask focused questions (one small batch) and proceed after answers.

# Source (path to original Claude command file)
- C:\Users\rjain\.claude\commands\gsd\gen-docker.md
