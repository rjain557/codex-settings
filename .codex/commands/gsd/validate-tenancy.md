---
name: gsd:validate-tenancy
description: Validate multi-tenancy isolation across all layers (SPs, repos, services, controllers)
argument-hint: ""
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
  - Task
  - TodoWrite
---
<objective>
Validate that TenantId isolation is correctly implemented across all layers of the application. Scans stored procedures, repositories, services, controllers, and frontend to ensure no data query is missing TenantId filtering.

One missing TenantId filter = cross-tenant data leak = security incident.

No arguments needed -- this skill always scans everything exhaustively.
</objective>

<execution_context>
@C:/Users/rjain/.codex/get-shit-done/workflows/validate-tenancy.md
</execution_context>

<context>
@.planning/STATE.md
@db/sql/procedures/
@db/sql/tables/
</context>

<process>
Execute the validate-tenancy workflow from @C:/Users/rjain/.codex/get-shit-done/workflows/validate-tenancy.md end-to-end.
Exhaustively scan all layers: tables, stored procedures, repositories, services, controllers, and frontend. Generate report with CRITICAL/WARNING/PASS findings.
</process>

