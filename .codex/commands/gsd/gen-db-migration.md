---
name: gsd:gen-db-migration
description: Generate idempotent database migration scripts with rollback (SQL Server/PostgreSQL)
argument-hint: "[--type <diff|specific|baseline|seed>] [--name <migration-name>] [--db <sqlserver|postgres|both>]"
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
Generate versioned, idempotent database migration scripts for schema changes. Creates forward migration and rollback scripts. Validates all migrations follow the SPOnly pattern.

The user chooses the scope:
- **Schema diff**: Auto-detect changes by comparing db/sql/ files against last baseline
- **Specific change**: Generate migration for a described change (add column, create table, etc.)
- **Full baseline**: Generate complete baseline migration from all db/sql/ files
- **Seed data**: Wrap seed/reference data changes in migration format

Supports SQL Server (primary) and PostgreSQL (secondary).
</objective>

<execution_context>
@C:/Users/rjain/.codex/get-shit-done/workflows/gen-db-migration.md
</execution_context>

<context>
Target: $ARGUMENTS (optional flags)

@.planning/STATE.md
@db/sql/tables/
@db/sql/procedures/
</context>

<process>
Execute the gen-db-migration workflow from @C:/Users/rjain/.codex/get-shit-done/workflows/gen-db-migration.md end-to-end.
Scan existing db/sql/ files for current schema state. Ask migration scope and target database. Generate idempotent scripts with IF EXISTS guards and matching rollback scripts.
</process>

