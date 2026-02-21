---
name: gsd-gen-db-migration
description: Generate idempotent database migration scripts with rollback (SQL Server/PostgreSQL) Use when the user asks for 'gsd:gen-db-migration', 'gsd-gen-db-migration', or equivalent trigger phrases.
---

# Purpose
Generate versioned, idempotent database migration scripts for schema changes. Creates forward migration and rollback scripts. Validates all migrations follow the SPOnly pattern.

The user chooses the scope:
- **Schema diff**: Auto-detect changes by comparing db/sql/ files against last baseline
- **Specific change**: Generate migration for a described change (add column, create table, etc.)
- **Full baseline**: Generate complete baseline migration from all db/sql/ files
- **Seed data**: Wrap seed/reference data changes in migration format

Supports SQL Server (primary) and PostgreSQL (secondary).

# When to use
Use when the user requests the original gsd:gen-db-migration flow (for example: $gsd-gen-db-migration).
Also use on natural-language requests that match this behavior: Generate idempotent database migration scripts with rollback (SQL Server/PostgreSQL)

# Inputs
The user's text after invoking $gsd-gen-db-migration is the arguments. Parse it into required fields; if any required field is missing, ask targeted follow-up questions.
Expected argument shape from source: [--type <diff|specific|baseline|seed>] [--name <migration-name>] [--db <sqlserver|postgres|both>].
Context from source:
```text
Target: <parsed-arguments> (optional flags)

@.planning/STATE.md
@db/sql/tables/
@db/sql/procedures/
```

# Workflow
Load and follow these referenced artifacts first:
- @C:/Users/rjain/.claude/get-shit-done/workflows/gen-db-migration.md
Then execute this process:
```text
Execute the gen-db-migration workflow from @C:/Users/rjain/.claude/get-shit-done/workflows/gen-db-migration.md end-to-end.
Scan existing db/sql/ files for current schema state. Ask migration scope and target database. Generate idempotent scripts with IF EXISTS guards and matching rollback scripts.
```

# Outputs / artifacts
Produce the artifacts specified by the workflow and summarize created/updated files.

# Guardrails (what not to do / how to ask for missing info)
- Do not invent missing project files, phase numbers, or state; inspect the repo first.
- Do not skip validation or checkpoint gates described in referenced workflows.
- If required context is missing, ask focused questions (one small batch) and proceed after answers.

# Source (path to original Claude command file)
- C:\Users\rjain\.claude\commands\gsd\gen-db-migration.md
