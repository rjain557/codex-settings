---
name: gsd-validate-tenancy
description: Validate multi-tenancy isolation across all layers (SPs, repos, services, controllers) Use when the user asks for 'gsd:validate-tenancy', 'gsd-validate-tenancy', or equivalent trigger phrases.
---

# Purpose
Validate that TenantId isolation is correctly implemented across all layers of the application. Scans stored procedures, repositories, services, controllers, and frontend to ensure no data query is missing TenantId filtering.

One missing TenantId filter = cross-tenant data leak = security incident.

No arguments needed -- this skill always scans everything exhaustively.

# When to use
Use when the user requests the original gsd:validate-tenancy flow (for example: $gsd-validate-tenancy).
Also use on natural-language requests that match this behavior: Validate multi-tenancy isolation across all layers (SPs, repos, services, controllers)

# Inputs
No required positional arguments. If the request lacks needed context, ask concise targeted questions before proceeding.
Context from source:
```text
@.planning/STATE.md
@db/sql/procedures/
@db/sql/tables/
```

# Workflow
Load and follow these referenced artifacts first:
- @C:/Users/rjain/.claude/get-shit-done/workflows/validate-tenancy.md
Then execute this process:
```text
Execute the validate-tenancy workflow from @C:/Users/rjain/.claude/get-shit-done/workflows/validate-tenancy.md end-to-end.
Exhaustively scan all layers: tables, stored procedures, repositories, services, controllers, and frontend. Generate report with CRITICAL/WARNING/PASS findings.
```

# Outputs / artifacts
Produce the artifacts specified by the workflow and summarize created/updated files.

# Guardrails (what not to do / how to ask for missing info)
- Do not invent missing project files, phase numbers, or state; inspect the repo first.
- Do not skip validation or checkpoint gates described in referenced workflows.
- If required context is missing, ask focused questions (one small batch) and proceed after answers.

# Source (path to original Claude command file)
- C:\Users\rjain\.claude\commands\gsd\validate-tenancy.md
