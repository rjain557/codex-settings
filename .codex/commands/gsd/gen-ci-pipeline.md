---
name: gsd:gen-ci-pipeline
description: Generate CI/CD pipeline (GitHub Actions / Azure DevOps) for build, test, and deploy
argument-hint: "[--platform <github|azure>] [--deploy-target <azure-app-service|docker|vm>]"
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
Generate a complete CI/CD pipeline for your project. Creates build, test, and deploy stages with environment promotion (dev → staging → production).

The user chooses:
- **CI platform**: GitHub Actions or Azure DevOps Pipelines
- **Deploy target**: Azure App Service, Docker container, self-hosted VM, or build-only

Tailored to the Technijian stack: ASP.NET Core 8 API + React/Vite SPA + SQL Server migrations.
</objective>

<execution_context>
@C:/Users/rjain/.claude/get-shit-done/workflows/gen-ci-pipeline.md
</execution_context>

<context>
Target: $ARGUMENTS (optional flags)

@.planning/STATE.md
</context>

<process>
Execute the gen-ci-pipeline workflow from @C:/Users/rjain/.claude/get-shit-done/workflows/gen-ci-pipeline.md end-to-end.
Detect project components, ask platform and deploy target, generate pipeline YAML with build/test/deploy stages.
</process>
