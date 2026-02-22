<purpose>
Orchestrate a comprehensive, dev-handoff-quality code review across any project type.

Auto-detects project components (Web Frontend, Backend API, Database, Auth/SSO, MCP Server, Mobile App, Browser Extension, Remote Agent) and spawns only the relevant review agents.

Each agent writes findings directly to docs/review/layers/. The orchestrator consolidates into prioritized reports.

Output: docs/review/ folder with executive summary, full report, developer handoff, and prioritized tasks.
</purpose>

<philosophy>
**Universal, not framework-specific:**
This review works for any project type. Checklists adapt based on detected components.

**Dev-handoff quality:**
Every finding includes file path, line numbers, evidence, fix approach, and time estimate. The output is immediately actionable.

**Agents write directly:**
Sub-agents write their findings to files. The orchestrator only reads summaries. This prevents context exhaustion on large codebases.

**Build verification is mandatory:**
A review that doesn't verify the build is incomplete. Build failures are BLOCKER severity.

**Detect, don't assume:**
Never assume a component exists. Always detect first, then review only what's there.
</philosophy>

<process>

<step name="init_context" priority="first">
Load review context:

```bash
INIT=$(node C:/Users/rjain/.codex/get-shit-done/bin/gsd-tools.js init code-review 2>/dev/null || echo '{}')
```

If init fails (command not registered yet), proceed with defaults:
- `reviewer_model`: use the model from parent context
- `commit_docs`: true

Check for existing review:
```bash
ls docs/review/ 2>/dev/null
```

If exists, ask user: Refresh (delete and re-review), or Skip.

Create output directories:
```bash
mkdir -p docs/review/layers
```
</step>

<step name="repo_inventory">
Perform Phase 0 repository inventory. This runs in the orchestrator (not a sub-agent).

**1. Detect project roots:**
```bash
# Find all project manifests
find . -maxdepth 3 -name "*.sln" -o -name "*.csproj" -o -name "package.json" -o -name "go.mod" -o -name "pyproject.toml" -o -name "Cargo.toml" -o -name "manifest.json" -o -name "app.json" 2>/dev/null | grep -v node_modules | grep -v .git
```

**2. Component detection matrix:**

For each potential component, check markers and assign confidence:

| Component | HIGH confidence (2+ markers) | MEDIUM (1 marker) |
|-----------|-------|--------|
| Web Frontend | package.json + (react\|vue\|angular\|svelte) + src/**/*.tsx | Any *.tsx or *.vue files |
| Backend .NET | *.csproj + Controllers/ + Program.cs | *.csproj alone |
| Backend Node | package.json + (express\|fastify\|hono\|koa) + src/server.* | routes/ directory |
| Backend Python | (requirements.txt\|pyproject.toml) + (flask\|django\|fastapi) | app.py + requirements.txt |
| Backend Go | go.mod + main.go + internal/ | go.mod alone |
| Database SQL | db/sql/*.sql with CREATE TABLE/PROCEDURE | Any *.sql files |
| Database Mongo | mongoose in package.json + models/ | mongodb connection string |
| MCP Server | @modelcontextprotocol/sdk in package.json OR McpServer class | mcp.json file |
| Mobile RN | react-native in package.json + (ios/ OR android/) | app.json with expo |
| Browser Extension | manifest.json with manifest_version field | content_scripts/ directory |
| Remote Agent | AgentService/BackgroundService + connection management | agent.config.* file |
| Auth/SSO | MSAL config OR [Authorize] attributes OR JWT middleware | auth/ directory |

**3. Map detected components:**

For each detected component, gather:
- File count and total lines
- Key entry points
- Public API surface (endpoints, exports, tools)
- Test coverage indicators

**4. Quick red flag scan:**
```bash
# Hardcoded secrets patterns (NEVER read .env files)
grep -rn "password\s*=\s*['\"]" --include="*.cs" --include="*.ts" --include="*.json" . 2>/dev/null | grep -v node_modules | grep -v .git | head -20

# TODO/FIXME/HACK counts
grep -rc "TODO\|FIXME\|HACK\|XXX\|NotImplementedException" --include="*.cs" --include="*.ts" --include="*.tsx" . 2>/dev/null | grep -v node_modules | grep -v ":0$" | sort -t: -k2 -rn | head -20

# 'any' type usage (TypeScript)
grep -rc "as any\|: any" --include="*.ts" --include="*.tsx" . 2>/dev/null | grep -v node_modules | grep -v ":0$" | sort -t: -k2 -rn | head -10

# Empty catch blocks
grep -rn "catch.*{" --include="*.cs" --include="*.ts" -A1 . 2>/dev/null | grep -B1 "^\s*}" | grep -v node_modules | head -20
```

**5. Build state check (quick):**
Run a fast build check and note pass/fail. Full verification happens in wave 3.

Store inventory as structured notes for sub-agent prompts.
</step>

<step name="determine_review_scope">
Based on detected components, determine which review agents to spawn.

Map components to reviewer types:

| Detected Component | Reviewer Agent | Checklist Section |
|-------------------|----------------|-------------------|
| Web Frontend | frontend-reviewer | CHECKLIST_FRONTEND |
| Backend .NET | dotnet-backend-reviewer | CHECKLIST_DOTNET_BACKEND |
| Backend Node | node-backend-reviewer | CHECKLIST_NODE_BACKEND |
| Backend Python | python-backend-reviewer | CHECKLIST_PYTHON_BACKEND |
| Backend Go | go-backend-reviewer | CHECKLIST_GO_BACKEND |
| Database SQL | sql-database-reviewer | CHECKLIST_SQL_DATABASE |
| Database Mongo | mongo-database-reviewer | CHECKLIST_MONGO_DATABASE |
| MCP Server | mcp-server-reviewer | CHECKLIST_MCP_SERVER |
| Mobile RN | mobile-reviewer | CHECKLIST_MOBILE |
| Browser Extension | extension-reviewer | CHECKLIST_EXTENSION |
| Remote Agent | agent-reviewer | CHECKLIST_REMOTE_AGENT |
| Auth/SSO | auth-reviewer | CHECKLIST_AUTH |

Only spawn agents for components with HIGH or MEDIUM confidence.

Present detection results to user before proceeding:
```
Detected Components:
  [HIGH]   Web Frontend (React 18 + TypeScript)
  [HIGH]   Backend API (.NET 8)
  [HIGH]   Database (SQL Server - 45 stored procedures)
  [HIGH]   Auth/SSO (Azure AD + MSAL + JWT)
  [LOW]    MCP Server (not detected)
  [LOW]    Mobile App (not detected)
  [LOW]    Browser Extension (not detected)
  [LOW]    Remote Agent (not detected)

Spawning 4 layer reviewers + 3 cross-cutting analyzers...
```
</step>

<step name="spawn_layer_reviewers">
Spawn parallel review agents for each detected component.

Use Task tool with:
- `subagent_type: "general-purpose"`
- `run_in_background: true`
- `model: "{reviewer_model}"` (from init or parent context)

Each agent prompt includes:
1. Role description
2. Component-specific checklist (from the CHECKLISTS section below)
3. Inventory data for their component
4. Output path: `docs/review/layers/{component}-findings.md`
5. Finding format template
6. Instructions to write findings directly and return only summary counts

**Agent prompt template:**
```
You are a {component} code reviewer. Your job is to perform a thorough review of the {component} layer in this project.

## Your Checklist
{paste relevant CHECKLIST section here}

## Repository Context
{paste relevant inventory data}

## Finding Format
{paste finding_format from agent definition}

## Output
Write ALL findings to: docs/review/layers/{component}-findings.md

Structure:
# {Component} Review Findings

**Reviewed:** {date}
**Files reviewed:** {count}
**Findings:** {blocker} Blocker | {high} High | {medium} Medium | {low} Low

## Blocker
{findings}

## High
{findings}

## Medium
{findings}

## Low
{findings}

---

## Summary
- Total findings: {N}
- Estimated fix effort: {hours}h
- Key risks: {top 3}

Return ONLY the summary section (counts and key risks). Write the full report to the file.
```

Wait for all agents to complete. Read their output files to collect summary counts.
</step>

<step name="spawn_cross_cutting">
Spawn 2-3 parallel cross-cutting analysis agents.

**Agent: Traceability Matrix Builder**
```
subagent_type: "general-purpose"
run_in_background: true
description: "Build traceability matrix"
```

Prompt:
```
You are a traceability analyst. For this project, map every user-facing feature through the full stack.

For EACH feature/endpoint, trace:
  UI Component â†’ API Client method â†’ HTTP Route â†’ Controller action â†’ Service/Repository method â†’ SP/Query â†’ Database tables

Write to: docs/review/TRACEABILITY-MATRIX.md

Format as a table. FLAG any broken links:
- Frontend calls an API method that doesn't exist
- Controller calls a repository method that doesn't exist
- Repository calls a SP that doesn't exist
- SP references a table/column that doesn't exist
- API client type doesn't match backend DTO
- Orphaned endpoints (no frontend caller)
- Orphaned SPs (no backend caller)

{Include inventory data}
```

**Agent: Contract Alignment Checker**
```
subagent_type: "general-purpose"
run_in_background: true
description: "Check API contracts"
```

Prompt:
```
You are an API contract alignment checker. For every API endpoint in this project, verify the contract between frontend and backend.

For each endpoint, check:
1. Frontend TypeScript type field names match backend DTO property names exactly
2. Frontend API client sends correct HTTP method, route, query params, body shape
3. Backend DTO property types are compatible with frontend TypeScript types
4. Pagination shapes match (page/pageSize vs skip/take, response wrapper shape)
5. Search/filter parameter names match
6. Date formats are consistent
7. Enum values match between frontend and backend
8. Null/undefined handling is consistent

Write to: docs/review/CONTRACT-ALIGNMENT.md

For each mismatch found, include:
- Endpoint: {method} {route}
- Frontend: {what frontend sends/expects}
- Backend: {what backend expects/returns}
- Severity: BLOCKER if runtime failure, HIGH if data loss, MEDIUM if edge case

{Include inventory data}
```

**Agent: Dead Code Analyzer** (only if codebase > 30 files)
```
subagent_type: "general-purpose"
run_in_background: true
description: "Analyze dead code"
```

Prompt:
```
You are a dead code analyzer. Find all unreferenced, orphaned, or deprecated code in this project.

Check for:
1. Exported functions/types never imported anywhere
2. API client methods never called from any component or hook
3. React hooks defined but never used
4. Components defined but not in any route or imported
5. Controller endpoints with no frontend caller
6. Repository methods never called from any controller/service
7. Stored procedures never called from any repository
8. Database tables not referenced in any SP or query
9. CSS classes/styles not referenced
10. Config values not read anywhere
11. Test files for deleted components
12. Import statements for removed packages

Write to: docs/review/DEAD-CODE.md

Group by: Frontend Dead Code, Backend Dead Code, Database Dead Code, Other.
For each item: file path, what it is, why it's dead (no references found).

{Include inventory data}
```

Wait for all agents to complete.
</step>

<step name="build_verification">
Run build verification (MANDATORY â€” do this in the orchestrator, not a sub-agent):

**Detect and run appropriate build commands:**

For .NET backend:
```bash
dotnet build {path-to-csproj} --nologo --verbosity quiet 2>&1
```

For TypeScript/React frontend:
```bash
cd {frontend-dir} && npx tsc --noEmit 2>&1
```

For React Native mobile:
```bash
cd {mobile-dir} && npx tsc --noEmit 2>&1
# Also: npx expo doctor 2>&1
```

For Browser Extension:
```bash
cd {extension-dir} && npm run build 2>&1
```

For Go backend:
```bash
cd {go-dir} && go build ./... 2>&1
```

For Python backend:
```bash
cd {python-dir} && python -m py_compile {main-files} 2>&1
```

Record results. Build failures become BLOCKER findings in the consolidated report.
</step>

<step name="consolidation">
Read all findings from:
- `docs/review/layers/*-findings.md` (layer reviews)
- `docs/review/TRACEABILITY-MATRIX.md` (if created)
- `docs/review/CONTRACT-ALIGNMENT.md` (if created)
- `docs/review/DEAD-CODE.md` (if created)

**Count findings by severity and component.**

**Calculate health score:**
- Start at 100
- Each BLOCKER: -15 points
- Each HIGH: -5 points
- Each MEDIUM: -2 points
- Each LOW: -0.5 points
- Floor at 0

**Health grade:**
- 90-100: A (Excellent â€” ready for production)
- 80-89: B (Good â€” minor issues)
- 70-79: C (Fair â€” needs attention before production)
- 50-69: D (Poor â€” significant work needed)
- 0-49: F (Critical â€” major rework required)

**Generate 4 consolidated reports:**

### 1. docs/review/EXECUTIVE-SUMMARY.md

```markdown
# Code Review â€” Executive Summary

**Date:** {date}
**Reviewer:** Claude (gsd-code-reviewer)
**Health Score:** {score}/100 (Grade: {grade})

## Components Reviewed

| Component | Files | Lines | Findings | Health |
|-----------|-------|-------|----------|--------|
| {component} | {N} | {N} | {B}B {H}H {M}M {L}L | {emoji} |

## Build Status

| Component | Status | Errors |
|-----------|--------|--------|
| Backend | PASS/FAIL | {details} |
| Frontend | PASS/FAIL | {details} |

## Finding Summary

| Severity | Count | Est. Effort |
|----------|-------|-------------|
| Blocker | {N} | {hours}h |
| High | {N} | {hours}h |
| Medium | {N} | {hours}h |
| Low | {N} | {hours}h |
| **Total** | **{N}** | **{hours}h** |

## Top 5 Risks

1. {risk â€” severity, component, description}
2. ...

## Recommendations

{What to fix first and why}

## Next Steps

- Fix blockers: `/gsd:plan-phase {N}` to create fix plans from PRIORITIZED-TASKS.md
- Re-review after fixes: `/gsd:code-review`
- Validate contracts: `/gsd:sdlc-validate` (if available)
```

### 2. docs/review/FULL-REPORT.md

All findings organized by severity (Blocker â†’ High â†’ Medium â†’ Low).
Each finding with full detail from layer reports.
Cross-references to traceability matrix and contract alignment where applicable.

### 3. docs/review/DEVELOPER-HANDOFF.md

Actionable tasks grouped by priority:

```markdown
# Developer Handoff â€” Code Review Findings

## Priority 1: Blockers (Fix Immediately)

### Task 1: {title}
**Files:** `{path1}`, `{path2}`
**What:** {description}
**Why:** {impact if not fixed}
**How:** {step-by-step fix approach}
**Acceptance Criteria:**
- [ ] {criterion 1}
- [ ] {criterion 2}
**Estimate:** {hours}h
**Depends on:** {other tasks or "None"}

## Priority 2: High (Fix Before Release)
...

## Priority 3: Medium (Fix Before Next Milestone)
...

## Priority 4: Low (Nice to Have)
...

## Estimated Total Effort
- Blockers: {hours}h
- High: {hours}h
- Medium: {hours}h
- Low: {hours}h
- **Total: {hours}h**
```

### 4. docs/review/PRIORITIZED-TASKS.md

Flat ordered list ready for `/gsd:plan-phase` consumption:

```markdown
# Prioritized Tasks

## How to Use

These tasks can be converted to GSD phases:
1. Group related tasks into phases
2. Run `/gsd:plan-phase {N}` with these tasks as input
3. Or add to existing roadmap with `/gsd:add-phase`

## Tasks (ordered by priority)

| # | Severity | Component | Task | Files | Est. |
|---|----------|-----------|------|-------|------|
| 1 | BLOCKER | Backend | {task} | `{files}` | {h}h |
| 2 | BLOCKER | Database | {task} | `{files}` | {h}h |
| 3 | HIGH | Frontend | {task} | `{files}` | {h}h |
...
```
</step>

<step name="present_results">
Return executive summary to the orchestrator skill.

Include:
- Health score and grade
- Finding counts by severity
- Component breakdown
- Build status
- Paths to all generated reports
- Total estimated effort
</step>

</process>

<checklists>

## CHECKLIST_FRONTEND

### React / TypeScript Frontend Review

**Component Architecture:**
- [ ] Components follow single responsibility principle
- [ ] State management is appropriate (local state vs store vs context)
- [ ] Props are properly typed (no `any` types without justification)
- [ ] Hooks follow rules of hooks (no conditional hooks, proper dependency arrays)
- [ ] Custom hooks extract reusable logic from components
- [ ] Component files are reasonable size (<400 lines preferred, >600 needs justification)

**5 Component States:**
- [ ] Loading state renders skeleton/spinner (not blank page)
- [ ] Error state shows user-friendly message with retry option
- [ ] Empty state shows guidance (not just blank area)
- [ ] Forbidden state shows access denied (not broken page)
- [ ] Default/success state renders correctly

**API Client Alignment:**
- [ ] All API client methods exist and are callable
- [ ] TypeScript types match backend DTO shapes (field names, types, nullability)
- [ ] Query parameter names match backend `[FromQuery]` names
- [ ] Request body shapes match backend `[FromBody]` DTO shapes
- [ ] Response types handle pagination wrapper correctly
- [ ] Error responses are handled (network errors, 4xx, 5xx)
- [ ] Auth tokens are sent with every protected request

**UI Framework Compliance:**
- [ ] Consistent use of UI library (Fluent UI, Material UI, etc.)
- [ ] No mixing of UI libraries for same component types
- [ ] Theme tokens used for colors (no hardcoded hex values)
- [ ] Responsive breakpoints handled
- [ ] Accessibility: ARIA labels, keyboard navigation, contrast ratios

**Routing & Navigation:**
- [ ] All routes defined in router config lead to existing components
- [ ] Protected routes check authentication and authorization
- [ ] Route parameters match component expectations
- [ ] Navigation links use router navigation (not window.location)
- [ ] 404 page exists for unmatched routes
- [ ] Deep linking works (direct URL access)

**State Management:**
- [ ] Store state shape matches what components consume
- [ ] No stale closures in event handlers
- [ ] Async state (loading/error/data) managed consistently
- [ ] Store actions handle error cases
- [ ] No unnecessary re-renders from state changes

**Build & Types:**
- [ ] TypeScript strict mode enabled (or explained why not)
- [ ] No `any` types without `// eslint-disable-next-line` justification
- [ ] No unused imports or variables
- [ ] Build produces no warnings (or warnings are documented)
- [ ] Bundle size is reasonable (no massive dependencies for small features)

---

## CHECKLIST_DOTNET_BACKEND

### .NET Backend API Review

**Controller Layer:**
- [ ] All controllers have `[Route("api/[controller]")]` or explicit route prefix
- [ ] All endpoints have `[Authorize]` or explicit `[AllowAnonymous]` with justification
- [ ] Role-based authorization matches requirements (`[Authorize(Roles = "Admin")]`)
- [ ] HTTP methods are correct (GET for reads, POST for creates, PUT for updates, DELETE for deletes)
- [ ] Route parameters match method parameters
- [ ] `[FromBody]`, `[FromQuery]`, `[FromRoute]` attributes are correct
- [ ] Return types match what frontend expects (ActionResult<T>, FileContentResult, etc.)
- [ ] Async methods are properly async (no `.Result` or `.Wait()`)
- [ ] No business logic in controllers (delegate to services/repositories)

**Dependency Injection:**
- [ ] All services/repositories are registered in DI container
- [ ] Correct lifetime (Scoped for DB, Singleton for config, Transient for stateless)
- [ ] No `new` instantiation of services that should be injected
- [ ] All constructor parameters have DI registrations
- [ ] No circular dependencies

**Data Access Pattern:**
- [ ] Repository pattern used consistently (no raw SQL in controllers)
- [ ] Dapper + StoredProcedure command type if SP-Only pattern
- [ ] Connection disposal handled (using statements or DI-managed lifetime)
- [ ] Parameters are parameterized (no string concatenation for SQL)
- [ ] Async database calls used throughout

**DTOs & Validation:**
- [ ] Request DTOs have validation attributes or FluentValidation
- [ ] Response DTOs don't expose internal/sensitive fields
- [ ] DTO property names match what frontend TypeScript types expect
- [ ] Nullable properties marked correctly
- [ ] No entity objects returned directly from endpoints

**Error Handling:**
- [ ] Global exception handler configured
- [ ] ProblemDetails format for error responses
- [ ] No swallowed exceptions (empty catch blocks)
- [ ] Appropriate HTTP status codes (400 for validation, 404 for not found, 403 for forbidden)
- [ ] No stack traces in production error responses

**Security:**
- [ ] No hardcoded secrets in source code
- [ ] CORS policy restricts origins appropriately
- [ ] Anti-forgery tokens for state-changing operations (if applicable)
- [ ] Input sanitization for user-provided strings
- [ ] File upload size limits and type validation

---

## CHECKLIST_NODE_BACKEND

### Node.js Backend API Review

**Route Layer:**
- [ ] All routes have authentication middleware
- [ ] Role-based authorization applied per route
- [ ] Request validation (Zod, Joi, or similar)
- [ ] Async error handling (express-async-handler or try/catch)
- [ ] Correct HTTP methods and status codes

**Data Access:**
- [ ] Database queries are parameterized (no string interpolation)
- [ ] Connection pooling configured
- [ ] Transactions used for multi-step operations
- [ ] No N+1 query patterns

**Error Handling:**
- [ ] Global error middleware catches unhandled errors
- [ ] Structured error responses (consistent shape)
- [ ] No unhandled promise rejections
- [ ] Graceful shutdown handling

**Security:**
- [ ] Helmet.js or equivalent security headers
- [ ] Rate limiting on auth endpoints
- [ ] Input sanitization
- [ ] No eval() or dynamic requires with user input

---

## CHECKLIST_PYTHON_BACKEND

### Python Backend API Review

**Route Layer:**
- [ ] All endpoints have authentication decorators
- [ ] Request validation (Pydantic, marshmallow, or similar)
- [ ] Async views used where appropriate
- [ ] Correct HTTP methods and status codes

**Data Access:**
- [ ] ORM or parameterized queries (no f-string SQL)
- [ ] Connection management (context managers)
- [ ] Migration files up to date

**Security:**
- [ ] CORS configured
- [ ] CSRF protection
- [ ] Input sanitization
- [ ] No pickle deserialization of user input

---

## CHECKLIST_GO_BACKEND

### Go Backend API Review

**Handler Layer:**
- [ ] All handlers have auth middleware
- [ ] Request validation
- [ ] Proper error handling (no ignored errors)
- [ ] Context propagation

**Data Access:**
- [ ] Parameterized queries
- [ ] Connection pooling
- [ ] Prepared statements where beneficial

**Concurrency:**
- [ ] No data races (race detector clean)
- [ ] Goroutine leaks checked
- [ ] Channel/mutex usage correct

---

## CHECKLIST_SQL_DATABASE

### SQL Server / PostgreSQL Database Review

**Schema Integrity:**
- [ ] All tables referenced in SPs actually exist
- [ ] All columns referenced in SPs match actual table definitions
- [ ] Foreign key constraints are valid (reference existing tables/columns)
- [ ] Primary keys defined on all tables
- [ ] Indexes exist on foreign key columns and frequently queried columns
- [ ] Data types are appropriate (NVARCHAR lengths, decimal precision)

**Stored Procedures:**
- [ ] All SPs called from backend actually exist in SQL scripts
- [ ] SP parameter names and types match backend code exactly
- [ ] SP result set columns match backend DTO properties
- [ ] SET NOCOUNT ON at top of every SP
- [ ] TRY/CATCH with proper error handling
- [ ] Transaction management for multi-table operations
- [ ] No SELECT * (explicit column lists)
- [ ] Parameters are used (no dynamic SQL with string concatenation)

**Seed Data:**
- [ ] Seed script is idempotent (MERGE or IF NOT EXISTS)
- [ ] Column names in INSERT match actual table definitions
- [ ] Data types match column definitions
- [ ] Foreign key references are valid (parent records exist)
- [ ] Script executes without errors against clean database

**Migrations:**
- [ ] Migration scripts are idempotent (safe to re-run)
- [ ] Rollback scripts exist or migrations are reversible
- [ ] Schema changes don't break existing SPs
- [ ] New columns have defaults or are nullable

---

## CHECKLIST_MONGO_DATABASE

### MongoDB Database Review

**Schema Design:**
- [ ] Document structure matches application models
- [ ] Indexes defined for query patterns
- [ ] No unbounded arrays in documents
- [ ] References vs embedding decisions documented

**Queries:**
- [ ] Indexes used for frequent queries
- [ ] Aggregation pipelines are efficient
- [ ] No full collection scans in production code

---

## CHECKLIST_MCP_SERVER

### MCP Server Review

**Tool Definitions:**
- [ ] All tools have complete JSON schema (name, description, inputSchema)
- [ ] Tool descriptions clearly explain what they do and when to use them
- [ ] Input parameters have descriptions and appropriate types
- [ ] Required vs optional parameters marked correctly

**Tool Implementations:**
- [ ] Each defined tool has a corresponding handler
- [ ] Handlers validate inputs before processing
- [ ] Handlers return structured results (not raw strings)
- [ ] Error handling returns MCP-compatible error responses
- [ ] No unhandled exceptions that crash the server

**Resources & Prompts:**
- [ ] Resources have valid URI patterns
- [ ] Resource content is properly formatted (text/markdown/json)
- [ ] Prompt templates have all required arguments defined

**Transport & Security:**
- [ ] Transport configured correctly (stdio or SSE)
- [ ] Credentials not hardcoded (environment variables)
- [ ] Rate limiting on external API calls
- [ ] Timeout handling for long-running operations
- [ ] Graceful shutdown handling

**Integration:**
- [ ] External API calls have error handling
- [ ] API keys/tokens managed via environment variables
- [ ] Response sizes are reasonable (not returning entire databases)
- [ ] Pagination for large result sets

---

## CHECKLIST_MOBILE

### React Native / Expo Mobile App Review

**Navigation:**
- [ ] Navigation structure matches app flow (stack, tabs, drawer)
- [ ] Deep linking configured for key screens
- [ ] Back navigation works correctly
- [ ] Screen transitions are smooth

**Platform Handling:**
- [ ] Platform-specific code isolated (`Platform.OS` checks, `.ios.tsx`/`.android.tsx`)
- [ ] Safe area handling (notch, home indicator)
- [ ] Keyboard avoidance on forms
- [ ] Status bar configuration

**Permissions:**
- [ ] Camera, microphone, location permissions requested at right time
- [ ] Permission denial handled gracefully
- [ ] Permissions listed in app.json/Info.plist/AndroidManifest.xml

**Data & Networking:**
- [ ] API calls handle offline state
- [ ] Loading states shown during network requests
- [ ] Secure storage for tokens (expo-secure-store, not AsyncStorage)
- [ ] Image caching for remote images

**Performance:**
- [ ] FlatList used for large lists (not ScrollView)
- [ ] Memoization for expensive computations
- [ ] No unnecessary re-renders
- [ ] Images optimized for mobile

**App Store Compliance:**
- [ ] App icons and splash screen configured
- [ ] Privacy policy URL in app config
- [ ] Required app.json fields filled (name, slug, version, bundleIdentifier)

---

## CHECKLIST_EXTENSION

### Browser Extension (Manifest V3) Review

**Manifest:**
- [ ] manifest_version is 3 (not 2)
- [ ] Permissions are minimal (no broad host_permissions without justification)
- [ ] Content security policy defined
- [ ] Icons at required sizes (16, 48, 128)
- [ ] Default locale set if using i18n

**Background Service Worker:**
- [ ] Uses service worker (not background page)
- [ ] Handles chrome.runtime.onInstalled
- [ ] Alarms used instead of setInterval (service worker can be killed)
- [ ] State persisted to chrome.storage (not in-memory variables)

**Content Scripts:**
- [ ] Isolated from page scripts (no shared globals)
- [ ] Proper message passing to background
- [ ] CSS doesn't leak to host page (scoped styles)
- [ ] Handles dynamic pages (MutationObserver if needed)

**Popup/Options Pages:**
- [ ] Responsive within popup dimensions
- [ ] State persists across popup open/close
- [ ] Links open in new tab (not in popup)

**Security:**
- [ ] No eval() or innerHTML with user content
- [ ] CSP headers in manifest
- [ ] Credential storage in chrome.storage.local (not cookies)
- [ ] Cross-origin requests limited to declared hosts

**Cross-Browser:**
- [ ] chrome.* API calls wrapped for Firefox/Safari compatibility (if needed)
- [ ] Manifest fields compatible with target browsers

---

## CHECKLIST_REMOTE_AGENT

### Remote Agent / Background Service Review

**Connection Management:**
- [ ] Reconnection logic with exponential backoff
- [ ] Heartbeat/keepalive mechanism
- [ ] Connection state tracking (connected, disconnecting, reconnecting)
- [ ] Graceful disconnect handling

**Command Processing:**
- [ ] Command validation before execution
- [ ] Timeout on command execution
- [ ] Result reporting back to controller
- [ ] Error isolation (one failed command doesn't crash agent)

**Security:**
- [ ] Authentication on connection (API key, certificate, or token)
- [ ] Command authorization (agent can't execute arbitrary code)
- [ ] TLS for transport encryption
- [ ] Credential rotation support

**Reliability:**
- [ ] Service auto-restarts on crash
- [ ] Logging for debugging (structured logs)
- [ ] Health check endpoint or status reporting
- [ ] Graceful shutdown (finish current work before stopping)

**Observability:**
- [ ] Metrics exported (commands processed, errors, latency)
- [ ] Log levels configurable
- [ ] Trace correlation for distributed requests

---

## CHECKLIST_AUTH

### Authentication & Authorization Review

**Authentication Flow:**
- [ ] Login flow works end-to-end (SSO redirect, token exchange, session creation)
- [ ] Token refresh flow handles expired tokens silently
- [ ] Logout invalidates both client and server sessions
- [ ] Session persistence across browser refresh
- [ ] Post-login redirect honors original URL (not hardcoded dashboard)

**Authorization:**
- [ ] Every API endpoint has explicit auth requirement ([Authorize] or equivalent)
- [ ] Role checks match requirements (Admin, ExamReviewer, Candidate, etc.)
- [ ] No [AllowAnonymous] on endpoints that handle sensitive data
- [ ] Frontend route guards match backend role requirements
- [ ] Resource ownership verified (users can only access their own data)

**Token Security:**
- [ ] JWT secret/key is strong and not hardcoded
- [ ] Token expiration is reasonable (access: 15-60min, refresh: days-weeks)
- [ ] Refresh tokens are single-use or bound to session
- [ ] Tokens stored securely (httpOnly cookies or secure storage, not localStorage for refresh)
- [ ] Token claims contain minimal necessary data

**CORS & Headers:**
- [ ] CORS origins restricted to known domains
- [ ] Credentials flag set correctly
- [ ] Security headers present (X-Frame-Options, CSP, HSTS, etc.)
- [ ] No wildcard CORS (*) on authenticated endpoints

**SSO / MSAL Specific (if applicable):**
- [ ] Client ID and tenant ID from environment variables (not hardcoded)
- [ ] Redirect URI matches Azure AD app registration
- [ ] Scopes are minimal and correct
- [ ] Multi-account handling (if needed)

</checklists>

<success_criteria>
- Repository inventoried with all project types detected
- Only detected components receive review agents (no wasted agents)
- Layer review agents write findings directly to docs/review/layers/
- Cross-cutting analysis (traceability + contracts + dead code) completed
- Build verification completed with pass/fail documented
- 4 consolidated reports generated
- Health score calculated and graded
- Clear next steps presented
</success_criteria>

