---
name: gsd-gen-ci-pipeline
description: Generate CI/CD pipeline (GitHub Actions / Azure DevOps) for build, test, and deploy Use when the user asks for 'gsd:gen-ci-pipeline', 'gsd-gen-ci-pipeline', or equivalent trigger phrases.
---

# Purpose
Generate a complete CI/CD pipeline for your project. Creates build, test, and deploy stages with environment promotion (dev â†’ staging â†’ production).

The user chooses:
- **CI platform**: GitHub Actions or Azure DevOps Pipelines
- **Deploy target**: Azure App Service, Docker container, self-hosted VM, or build-only

Tailored to the Technijian stack: ASP.NET Core 8 API + React/Vite SPA + SQL Server migrations.

# When to use
Use when the user requests the original gsd:gen-ci-pipeline flow (for example: $gsd-gen-ci-pipeline).
Also use on natural-language requests that match this behavior: Generate CI/CD pipeline (GitHub Actions / Azure DevOps) for build, test, and deploy

# Inputs
The user's text after invoking $gsd-gen-ci-pipeline is the arguments. Parse it into required fields; if any required field is missing, ask targeted follow-up questions.
Expected argument shape from source: [--platform <github|azure>] [--deploy-target <azure-app-service|docker|vm>].
Context from source:
```text
Target: <parsed-arguments> (optional flags)

@.planning/STATE.md
```

# Workflow
Load and follow these referenced artifacts first:
- @C:/Users/rjain/.claude/get-shit-done/workflows/gen-ci-pipeline.md
Then execute this process:
```text
Execute the gen-ci-pipeline workflow from @C:/Users/rjain/.claude/get-shit-done/workflows/gen-ci-pipeline.md end-to-end.
Detect project components, ask platform and deploy target, generate pipeline YAML with build/test/deploy stages.
```

# Outputs / artifacts
Produce the artifacts specified by the workflow and summarize created/updated files.

# Guardrails (what not to do / how to ask for missing info)
- Do not invent missing project files, phase numbers, or state; inspect the repo first.
- Do not skip validation or checkpoint gates described in referenced workflows.
- If required context is missing, ask focused questions (one small batch) and proceed after answers.

# Source (path to original Claude command file)
- C:\Users\rjain\.claude\commands\gsd\gen-ci-pipeline.md
