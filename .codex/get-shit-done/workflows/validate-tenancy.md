<purpose>
Validate that multi-tenancy isolation is correctly implemented across all layers of the application. Scans stored procedures, repositories, services, controllers, and frontend code to ensure TenantId is never missing from data queries.

One missing TenantId filter = cross-tenant data leak = security incident. This skill catches those gaps before they reach production.
</purpose>

<core_principle>
Every data query must be tenant-scoped. There are zero exceptions for multi-tenant tables. This skill performs exhaustive scanning -- not sampling -- across all layers to verify that TenantId isolation is complete and correct.
</core_principle>

<required_reading>
Read STATE.md and ROADMAP.md before any operation to load project context.
Scan all stored procedures in db/sql/procedures/.
Scan all repositories in src/Server/*/Repositories/.
Scan all controllers in src/Server/*/Controllers/.
</required_reading>

<process>

<step name="initialize" priority="first">
Determine project context:

1. Check if `.planning/` exists (GSD project) or standalone
2. Identify multi-tenant tables (tables with TenantId column)
3. Catalog all stored procedures
4. Catalog all repositories
5. Catalog all controllers
6. Check for tenant middleware or helper methods

No arguments needed -- this skill always scans everything.
</step>

<step name="scan_database_layer">
**Scan 1: Tables**

Identify all tables and classify:
- **Multi-tenant**: Has TenantId column (MUST have isolation)
- **Global/system**: No TenantId (shared across tenants, e.g., SystemSettings, LookupValues)
- **Ambiguous**: Should have TenantId but doesn't (potential design flaw)

```
| Table | TenantId Column | Classification |
|-------|----------------|----------------|
| Users | Yes | Multi-tenant |
| Conversations | Yes | Multi-tenant |
| SystemSettings | No | Global |
| AuditLog | Yes | Multi-tenant |
```

**Scan 2: Stored Procedures**

For each SP that touches a multi-tenant table:
- [ ] Has `@TenantId` parameter
- [ ] Uses `WHERE TenantId = @TenantId` (or equivalent JOIN filter)
- [ ] All JOINed tables also filtered by TenantId
- [ ] INSERT includes TenantId value
- [ ] UPDATE/DELETE filtered by TenantId
- [ ] No `SELECT *` without TenantId filter on multi-tenant tables

**Red flags:**
```sql
-- BAD: Missing TenantId filter
SELECT * FROM Users WHERE Id = @Id
-- Should be: WHERE Id = @Id AND TenantId = @TenantId

-- BAD: JOIN without tenant filter on both sides
SELECT u.*, c.* FROM Users u
JOIN Conversations c ON c.UserId = u.Id
WHERE u.TenantId = @TenantId
-- Missing: AND c.TenantId = @TenantId

-- BAD: INSERT without TenantId
INSERT INTO Users (Name, Email) VALUES (@Name, @Email)
-- Missing: TenantId column in INSERT
```
</step>

<step name="scan_repository_layer">
**Scan 3: Repository implementations**

For each repository method:
- [ ] Passes TenantId to stored procedure call
- [ ] TenantId parameter is not nullable (required)
- [ ] TenantId comes from method parameter (not hardcoded)
- [ ] No repository method bypasses TenantId

**Red flags:**
```csharp
// BAD: Missing TenantId in SP call
await connection.QueryAsync<User>("usp_User_GetById",
    new { Id = id },  // Missing TenantId!
    commandType: CommandType.StoredProcedure);

// BAD: TenantId is optional
public async Task<User?> GetById(string id, string? tenantId = null)
// Should be: string tenantId (required, not nullable)
```

**Pattern check:**
- Every `QueryAsync`, `ExecuteAsync`, etc. call should include TenantId
- Grep for SP calls that don't include `TenantId` in the parameter object
</step>

<step name="scan_service_layer">
**Scan 4: Service implementations**

For each service method:
- [ ] Receives TenantId as parameter (from controller)
- [ ] Passes TenantId to repository calls
- [ ] Does not fabricate or override TenantId
- [ ] Cross-entity operations use same TenantId

**Red flags:**
```csharp
// BAD: Service doesn't pass TenantId to repo
public async Task<UserResponseDto> GetUser(string id)
{
    var user = await _repo.GetById(id); // Where's TenantId?
}

// BAD: Service hardcodes TenantId
var tenantId = "default-tenant"; // Should come from controller
```
</step>

<step name="scan_controller_layer">
**Scan 5: Controller implementations**

For each controller:
- [ ] Has `GetTenantId()` helper method (or uses tenant middleware)
- [ ] Every action method calls `GetTenantId()` and passes to service
- [ ] TenantId extraction is consistent (same header/claim source)
- [ ] No endpoint skips TenantId (unless explicitly global)

**Red flags:**
```csharp
// BAD: Controller doesn't extract TenantId
[HttpGet]
public async Task<IActionResult> GetUsers()
{
    var users = await _service.GetUsers(); // No TenantId passed!
}

// BAD: TenantId from wrong source
var tenantId = User.FindFirst("tid")?.Value; // Inconsistent with other controllers
```

**Also check:**
- [ ] `X-Tenant-ID` header is required (middleware or per-action)
- [ ] Missing header returns 400 (not null propagation)
- [ ] No controller uses a different tenant header name
</step>

<step name="scan_frontend_layer">
**Scan 6: Frontend API calls**

For each API call in the frontend:
- [ ] Includes `X-Tenant-ID` header (or uses interceptor that adds it)
- [ ] Tenant ID comes from auth context (not hardcoded)
- [ ] API client has tenant interceptor configured

**Red flags:**
```typescript
// BAD: API call without tenant header
const response = await fetch('/api/users');

// BAD: Hardcoded tenant
headers: { 'X-Tenant-ID': 'tenant-001' }
```
</step>

<step name="scan_cross_cutting">
**Scan 7: Cross-cutting concerns**

- [ ] **Middleware**: Is there a global tenant middleware that rejects requests without X-Tenant-ID?
- [ ] **Logging**: Does logging include TenantId for correlation?
- [ ] **Caching**: Is cached data scoped by TenantId? (cache key includes tenant)
- [ ] **Background jobs**: Do async jobs preserve TenantId context?
- [ ] **SSE/streaming**: Do streaming endpoints filter by TenantId?
- [ ] **File uploads**: Are uploaded files stored in tenant-scoped paths?
- [ ] **Search**: Are search queries filtered by TenantId?
</step>

<step name="generate_report">
Generate validation report:

```
docs/security/
  tenancy-validation-{date}.md         # Main report
```

**Report format:**
```markdown
# Multi-Tenancy Validation Report

**Date**: {date}
**Project**: {project name}
**Score**: {pass_count}/{total_checks} checks passed ({percentage}%)

## Summary

| Layer | Checked | Passed | Failed | Score |
|-------|---------|--------|--------|-------|
| Database (Tables) | {n} | {n} | {n} | {%} |
| Database (SPs) | {n} | {n} | {n} | {%} |
| Repository | {n} | {n} | {n} | {%} |
| Service | {n} | {n} | {n} | {%} |
| Controller | {n} | {n} | {n} | {%} |
| Frontend | {n} | {n} | {n} | {%} |
| Cross-cutting | {n} | {n} | {n} | {%} |

## CRITICAL FINDINGS (Data Leak Risk)

### FAILED: usp_Message_GetByConversation missing TenantId filter
**Layer**: Database
**Severity**: CRITICAL
**File**: db/sql/procedures/usp_Message_GetByConversation.sql:15
**Finding**: SELECT joins Messages to Conversations but only filters Conversations.TenantId, not Messages.TenantId
**Risk**: Tenant B could see Tenant A's messages if ConversationId is guessed
**Fix**: Add `AND m.TenantId = @TenantId` to WHERE clause

### FAILED: ChatController.GetMessages() missing TenantId
**Layer**: Controller
**Severity**: CRITICAL
**File**: src/Server/Controllers/ChatController.cs:42
**Finding**: GetMessages() does not call GetTenantId() or pass tenant to service
**Risk**: Any authenticated user can read any tenant's messages
**Fix**: Add `var tenantId = GetTenantId();` and pass to service call

## Passed Checks
{List of all passing checks with evidence}

## Recommendations
1. Add global tenant middleware to reject requests without X-Tenant-ID
2. Add integration tests for cross-tenant access (see /gsd:gen-integration-test)
3. Consider row-level security in SQL Server for defense-in-depth
4. Add TenantId to cache keys for any cached data
```
</step>

<step name="commit_and_report">
Commit the report:

```bash
git add docs/security/
git commit -m "docs: multi-tenancy validation report ({pass_rate}% pass rate)"
```

Report summary to user with critical findings highlighted.

If any CRITICAL findings:
```
âš  CRITICAL TENANT ISOLATION GAPS FOUND

{count} critical findings that could allow cross-tenant data access.
Review docs/security/tenancy-validation-{date}.md immediately.

The most urgent fixes:
1. {finding 1 summary}
2. {finding 2 summary}
```
</step>

</process>

<success_criteria>
- [ ] All multi-tenant tables identified
- [ ] All stored procedures scanned for TenantId filters
- [ ] All repositories scanned for TenantId parameter passing
- [ ] All services scanned for TenantId propagation
- [ ] All controllers scanned for TenantId extraction
- [ ] Frontend API calls checked for tenant header
- [ ] Cross-cutting concerns checked (caching, background jobs, logging)
- [ ] Report generated with evidence for each check
- [ ] Critical findings highlighted with fix instructions
</success_criteria>

<failure_handling>
- **No TenantId column found anywhere**: Warn that project may not be multi-tenant; ask user to confirm
- **Inconsistent tenant column names**: Flag all variations (TenantId, tenant_id, TenantID) and recommend standardization
- **Too many files to scan**: Split into parallel sub-scans by layer using Task agents
- **Cannot determine if table is multi-tenant**: Flag as ambiguous for human review
</failure_handling>

