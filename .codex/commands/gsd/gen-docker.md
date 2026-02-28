---
name: gsd:gen-docker
description: Generate Dockerfiles, docker-compose, and container orchestration config
argument-hint: "[--components <api|spa|db|all>] [--registry <acr|dockerhub|ghcr>]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
  - Task
  - TodoWrite
  - AskUserQuestion
---
<objective>
Generate Docker infrastructure for your project. Creates multi-stage Dockerfiles, docker-compose for local development, and optional Kubernetes manifests.

The user chooses:
- **Orchestration**: docker-compose only, docker-compose + Kubernetes, or Dockerfiles only

Tailored to: ASP.NET Core 8 (multi-stage .NET SDK â†’ runtime), React/Vite (Node â†’ nginx), SQL Server (dev container with auto-init).
</objective>

<execution_context>
@C:/Users/rjain/.codex/get-shit-done/workflows/gen-docker.md
</execution_context>

<context>
Target: $ARGUMENTS (optional flags)

@.planning/STATE.md
</context>

<process>
Execute the gen-docker workflow from @C:/Users/rjain/.codex/get-shit-done/workflows/gen-docker.md end-to-end.
Detect project components, generate optimized Dockerfiles with security best practices, and compose files for one-command local dev.
</process>

