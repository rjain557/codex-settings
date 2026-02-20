---
name: gsd:gen-integration-test
description: Generate xUnit integration tests from OpenAPI spec with WebApplicationFactory
argument-hint: "[--controller <name>] [--entity <name>] [--all]"
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
Generate integration tests for your API endpoints using xUnit and WebApplicationFactory. Tests verify the full pipeline: HTTP â†’ Controller â†’ Service â†’ Repository â†’ Stored Procedure â†’ Response.

The user chooses scope:
- **All endpoints**: Comprehensive coverage across every controller
- **CRUD only**: Standard CRUD tests per entity
- **Specific controller**: Tests for one controller
- **Auth & security**: Authentication, authorization, and tenant isolation tests

Includes happy path, validation errors, auth enforcement, and cross-tenant isolation tests.
</objective>

<execution_context>
@C:/Users/rjain/.codex/get-shit-done/workflows/gen-integration-test.md
</execution_context>

<context>
Target: $ARGUMENTS (optional flags)

@.planning/STATE.md
@docs/spec/openapi.yaml
</context>

<process>
Execute the gen-integration-test workflow from @C:/Users/rjain/.codex/get-shit-done/workflows/gen-integration-test.md end-to-end.
Discover endpoints from OpenAPI spec or controllers. Generate WebApplicationFactory, test auth handler, test data builders, and per-controller test classes.
</process>

