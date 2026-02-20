<purpose>
Generate idempotent database migration scripts for schema changes. Supports SQL Server (primary) and PostgreSQL (secondary). Creates both forward migration and rollback scripts. Validates all migrations follow the SPOnly pattern -- tables, views, functions, and stored procedures only.

Fills the schema evolution gap in Technijian SDLC v6.0 by providing versioned, repeatable migrations with dependency ordering and safety guards.
</purpose>

<core_principle>
Every schema change is a versioned, idempotent migration with a matching rollback. Migrations follow the SPOnly pattern: no Entity Framework, no ORM migrations, no raw SQL in application code. All database objects are managed through explicit SQL scripts with IF EXISTS guards.
</core_principle>

<required_reading>
Read STATE.md and ROADMAP.md before any operation to load project context.
Read existing table schemas in db/sql/tables/ for current schema state.
Read existing stored procedures in db/sql/procedures/ for SP inventory.
Read existing views in db/sql/views/ and functions in db/sql/functions/.
</required_reading>

<process>

<step name="initialize" priority="first">
Determine project context:

1. Check if `.planning/` exists (GSD project) or standalone generation
2. Scan `db/sql/tables/` for current table definitions
3. Scan `db/sql/procedures/` for stored procedures
4. Scan `db/sql/views/` and `db/sql/functions/` for views and functions
5. Check for existing migration history in `db/migrations/`
6. Detect database engine from connection strings or config

Parse arguments:
- `$ARGUMENTS` may contain: `--type <table|sp|view|function|seed|full>`, `--name <migration-name>`, `--db <sqlserver|postgres|both>`
- If no type specified, auto-detect from recent changes or ask
</step>

<step name="ask_migration_scope">
Present the migration scope:

```
AskUserQuestion(
  header="Scope",
  question="What type of database migration should be generated?",
  options=[
    {
      label: "Schema diff (Recommended)",
      description: "Compare current db/sql/ files against last migration baseline. Auto-detect added/modified/removed tables, columns, SPs, views, and functions."
    },
    {
      label: "Specific change",
      description: "Generate migration for a specific change you describe (add column, create table, modify SP). You'll specify the change."
    },
    {
      label: "Full baseline",
      description: "Generate a complete baseline migration from all existing db/sql/ files. Use for first-time migration setup or new database provisioning."
    },
    {
      label: "Seed data",
      description: "Generate a migration for seed/reference data changes. Wraps db/seeds/ scripts in migration format with idempotency guards."
    }
  ]
)
```

Store choice as `SCOPE`: `diff`, `specific`, `baseline`, or `seed`.
</step>

<step name="ask_target_db">
If not specified in arguments:

```
AskUserQuestion(
  header="Target DB",
  question="Which database engine(s) should the migration target?",
  options=[
    {
      label: "SQL Server (Recommended)",
      description: "Primary target. T-SQL syntax with SQL Server-specific features (IDENTITY, NVARCHAR, datetime2, computed columns)."
    },
    {
      label: "PostgreSQL",
      description: "Secondary target. PostgreSQL syntax with appropriate type mappings (SERIAL, VARCHAR, TIMESTAMPTZ)."
    },
    {
      label: "Both",
      description: "Generate parallel migration scripts for both engines. Shared migration metadata, engine-specific SQL."
    }
  ]
)
```

Store as `TARGET_DB`.
</step>

<step name="detect_changes">
If SCOPE is `diff`, auto-detect changes:

1. **Load baseline**: Read last migration's schema snapshot (or scan db/sql/ files if no migrations exist)
2. **Load current**: Read all current db/sql/ files
3. **Diff tables**: Detect added/removed tables, added/removed/modified columns, index changes
4. **Diff SPs**: Detect new/modified/removed stored procedures
5. **Diff views**: Detect new/modified/removed views
6. **Diff functions**: Detect new/modified/removed functions

Present detected changes:
```
## Detected Changes

### Tables
- ADD: dbo.AgentHeartbeat (new table)
- ALTER: dbo.Users -- add column LastLoginAt datetime2
- ALTER: dbo.Conversations -- modify column Title nvarchar(200) â†’ nvarchar(500)

### Stored Procedures
- ADD: usp_Agent_Heartbeat
- MODIFY: usp_User_GetById (added LastLoginAt to SELECT)
- REMOVE: usp_Legacy_Cleanup (deleted from source)

### Views
- MODIFY: vw_User_Active (added LastLoginAt)

Proceed with migration generation?
```

If SCOPE is `specific`, ask the user to describe the change.
If SCOPE is `baseline`, include all db/sql/ objects.
</step>

<step name="generate_project_structure">
Generate the directory structure:

```
db/migrations/
  config/
    migration.json                     # Migration configuration
    type-mappings.json                 # SQL Server â†” PostgreSQL type mappings

  {version}/                           # e.g., V001, V002, V003
    up/
      01-tables.sql                    # Table changes (CREATE/ALTER)
      02-views.sql                     # View changes (CREATE OR ALTER)
      03-functions.sql                 # Function changes (CREATE OR ALTER)
      04-procedures.sql                # Stored procedure changes (CREATE OR ALTER)
      05-indexes.sql                   # Index changes
      06-constraints.sql               # Constraint changes (FK, CHECK, DEFAULT)
      07-seeds.sql                     # Seed data (if applicable)
      08-permissions.sql               # Permission grants
    down/
      01-rollback.sql                  # Combined rollback script (reverse order)
    metadata.json                      # Migration metadata (version, date, description, checksum)
    CHANGELOG.md                       # Human-readable change description

  scripts/
    migrate.ps1                        # PowerShell migration runner (Windows)
    migrate.sh                         # Bash migration runner (Mac/Linux)
    validate.ps1                       # Validate migration scripts (syntax, idempotency)
    snapshot.ps1                       # Create schema snapshot for diff baseline
    generate-report.ps1                # Generate migration history report

  __baseline/                          # Schema baseline snapshot
    tables.json                        # Table definitions snapshot
    procedures.json                    # SP definitions snapshot
    views.json                         # View definitions snapshot
    functions.json                     # Function definitions snapshot

  README.md                            # Migration documentation
```
</step>

<step name="generate_migration_scripts">
Generate SQL migration scripts with safety guards:

**Table changes** (01-tables.sql):
```sql
-- Migration: V{version} - {description}
-- Date: {date}
-- Author: Claude Code (gen-db-migration)

-- ============================================================
-- TABLE CHANGES
-- ============================================================

-- New table: AgentHeartbeat
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'AgentHeartbeat' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE dbo.AgentHeartbeat (
        Id UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
        AgentId UNIQUEIDENTIFIER NOT NULL,
        TenantId UNIQUEIDENTIFIER NOT NULL,
        Status NVARCHAR(50) NOT NULL,
        LastHeartbeat DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
        Metadata NVARCHAR(MAX) NULL,
        CreatedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_AgentHeartbeat PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_AgentHeartbeat_Tenant FOREIGN KEY (TenantId) REFERENCES dbo.Tenants(Id)
    );
    PRINT 'Created table: dbo.AgentHeartbeat';
END
ELSE
    PRINT 'Table dbo.AgentHeartbeat already exists -- skipping';
GO

-- Alter table: Users -- add column
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Users') AND name = 'LastLoginAt')
BEGIN
    ALTER TABLE dbo.Users ADD LastLoginAt DATETIME2(7) NULL;
    PRINT 'Added column: dbo.Users.LastLoginAt';
END
GO
```

**SP changes** (04-procedures.sql):
```sql
-- Use CREATE OR ALTER for idempotency (SQL Server 2016+)
CREATE OR ALTER PROCEDURE dbo.usp_Agent_Heartbeat
    @AgentId UNIQUEIDENTIFIER,
    @TenantId UNIQUEIDENTIFIER,
    @Status NVARCHAR(50),
    @Metadata NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- ... SP body from db/sql/procedures/
END
GO
PRINT 'Created/Updated procedure: usp_Agent_Heartbeat';
GO
```

**Rollback** (down/01-rollback.sql):
```sql
-- Rollback: V{version}
-- IMPORTANT: Run in reverse order of forward migration

-- Remove SP
IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'usp_Agent_Heartbeat')
    DROP PROCEDURE dbo.usp_Agent_Heartbeat;
GO

-- Remove column
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Users') AND name = 'LastLoginAt')
    ALTER TABLE dbo.Users DROP COLUMN LastLoginAt;
GO

-- Remove table
IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'AgentHeartbeat')
    DROP TABLE dbo.AgentHeartbeat;
GO
```

**PostgreSQL variant** (if both engines):
- Map types: `UNIQUEIDENTIFIER` â†’ `UUID`, `NVARCHAR` â†’ `VARCHAR`, `DATETIME2` â†’ `TIMESTAMPTZ`
- Map syntax: `IF NOT EXISTS` â†’ `CREATE TABLE IF NOT EXISTS`, `CREATE OR ALTER` â†’ `CREATE OR REPLACE`
- Generate in parallel directory: `{version}/up-pg/`
</step>

<step name="generate_metadata">
Generate migration metadata:

```json
{
  "version": "V001",
  "name": "add-agent-heartbeat-and-user-login-tracking",
  "description": "Add AgentHeartbeat table and LastLoginAt column to Users",
  "date": "2026-02-11T00:00:00Z",
  "author": "gen-db-migration",
  "changes": {
    "tables_added": ["AgentHeartbeat"],
    "tables_altered": ["Users"],
    "tables_removed": [],
    "procedures_added": ["usp_Agent_Heartbeat"],
    "procedures_modified": ["usp_User_GetById"],
    "procedures_removed": [],
    "views_modified": ["vw_User_Active"],
    "functions_modified": []
  },
  "dependencies": [],
  "checksum": "{sha256 of combined up/ scripts}",
  "sponly_compliant": true
}
```
</step>

<step name="generate_migration_runner">
Generate migration runner scripts:

**PowerShell runner** (migrate.ps1):
- Discovers pending migrations by comparing metadata table against migration directories
- Executes migrations in version order within a transaction
- Records success/failure in migration history table (`__MigrationHistory`)
- Supports: `--up` (apply next), `--up-all` (apply all pending), `--down` (rollback last), `--status` (show state)
- Validates each script before execution (syntax check, idempotency markers)

**Validation script** (validate.ps1):
- Checks all migrations have matching rollbacks
- Verifies IF EXISTS / IF NOT EXISTS guards on all DDL
- Checks for forbidden patterns: raw SQL in C# code, EF migrations, inline SQL
- Verifies SPOnly compliance: only tables, views, functions, SPs, indexes, constraints
- Reports: PASS/WARN/FAIL per migration
</step>

<step name="generate_snapshot">
Generate schema snapshot for future diffs:

After migration generation, snapshot current state of db/sql/ into `__baseline/`:
- Tables: column definitions, types, nullability, defaults, constraints
- Procedures: SP names, parameter lists, checksums
- Views: view names, column lists, checksums
- Functions: function names, parameter lists, return types, checksums

This snapshot serves as the "before" state for the next diff operation.
</step>

<step name="validate_sponly">
Validate generated migrations against SPOnly pattern:

Checks:
- [ ] No Entity Framework migration files generated
- [ ] No `DbContext`, `ModelBuilder`, or LINQ-to-SQL references
- [ ] All data access through stored procedures
- [ ] Tables only have DDL (CREATE/ALTER/DROP), no DML outside seeds
- [ ] Seeds use IF NOT EXISTS guards and explicit IDs
- [ ] All SPs use `SET NOCOUNT ON`
- [ ] TenantId present on all multi-tenant tables

Report any violations as warnings.
</step>

<step name="commit_and_report">
Commit all generated files:

```bash
git add db/migrations/
git commit -m "feat: generate migration V{version} -- {description}"
```

Report:
```
## Migration Generated: V{version}

**Scope**: {diff | specific | baseline | seed}
**Target**: {SQL Server | PostgreSQL | Both}
**SPOnly Compliant**: {Yes | Warnings}

### Changes
| Type | Added | Modified | Removed |
|------|-------|----------|---------|
| Tables | {n} | {n} | {n} |
| Procedures | {n} | {n} | {n} |
| Views | {n} | {n} | {n} |
| Functions | {n} | {n} | {n} |

### Files Generated
- Forward: db/migrations/V{version}/up/ ({n} scripts)
- Rollback: db/migrations/V{version}/down/ (1 script)
- Metadata: db/migrations/V{version}/metadata.json

### Next Steps
1. Review generated scripts in db/migrations/V{version}/
2. Validate: .\db\migrations\scripts\validate.ps1
3. Apply to dev: .\db\migrations\scripts\migrate.ps1 --up
4. Test rollback: .\db\migrations\scripts\migrate.ps1 --down
5. Check status: .\db\migrations\scripts\migrate.ps1 --status
```
</step>

</process>

<success_criteria>
- [ ] Migration scripts generated with IF EXISTS guards (idempotent)
- [ ] Rollback scripts generated (reversible)
- [ ] Correct dependency ordering (tables before SPs/views that reference them)
- [ ] SPOnly pattern validated (no EF, no raw SQL in app code)
- [ ] TenantId isolation verified on multi-tenant tables
- [ ] Migration metadata with version, description, checksum
- [ ] Migration runner script for automated execution
- [ ] Schema snapshot updated for future diffs
</success_criteria>

<failure_handling>
- **No db/sql/ directory found**: Create initial directory structure; generate baseline from user-described schema
- **No existing migrations**: Initialize migration system with V001 baseline from current db/sql/ files
- **SPOnly violation detected**: Warn but still generate migration; flag violations in report
- **Circular dependencies**: Detect and report; suggest manual ordering with user input
- **PostgreSQL type mapping unknown**: Use TEXT as fallback; flag for manual review
</failure_handling>

