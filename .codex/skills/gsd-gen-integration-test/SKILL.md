---
name: gsd-gen-integration-test
description: Generate xUnit integration tests from OpenAPI spec with WebApplicationFactory Use when the user asks for 'gsd:gen-integration-test', 'gsd-gen-integration-test', or equivalent trigger phrases.
---

# Purpose
Generate integration tests for your API endpoints using xUnit and WebApplicationFactory. Tests verify the full pipeline: HTTP â†’ Controller â†’ Service â†’ Repository â†’ Stored Procedure â†’ Response.

The user chooses scope:
- **All endpoints**: Comprehensive coverage across every controller
- **CRUD only**: Standard CRUD tests per entity
- **Specific controller**: Tests for one controller
- **Auth & security**: Authentication, authorization, and tenant isolation tests

Includes happy path, validation errors, auth enforcement, and cross-tenant isolation tests.

# When to use
Use when the user requests the original gsd:gen-integration-test flow (for example: $gsd-gen-integration-test).
Also use on natural-language requests that match this behavior: Generate xUnit integration tests from OpenAPI spec with WebApplicationFactory

# Inputs
The user's text after invoking $gsd-gen-integration-test is the arguments. Parse it into required fields; if any required field is missing, ask targeted follow-up questions.
Expected argument shape from source: [--controller <name>] [--entity <name>] [--all].
Context from source:
```text
Target: <parsed-arguments> (optional flags)

@.planning/STATE.md
@docs/spec/openapi.yaml
```

# Workflow
Load and follow these referenced artifacts first:
- @C:/Users/rjain/.claude/get-shit-done/workflows/gen-integration-test.md
Then execute this process:
```text
Execute the gen-integration-test workflow from @C:/Users/rjain/.claude/get-shit-done/workflows/gen-integration-test.md end-to-end.
Discover endpoints from OpenAPI spec or controllers. Generate WebApplicationFactory, test auth handler, test data builders, and per-controller test classes.
```

# Outputs / artifacts
Produce the artifacts specified by the workflow and summarize created/updated files.

# Guardrails (what not to do / how to ask for missing info)
- Do not invent missing project files, phase numbers, or state; inspect the repo first.
- Do not skip validation or checkpoint gates described in referenced workflows.
- If required context is missing, ask focused questions (one small batch) and proceed after answers.

# Source (path to original Claude command file)
- C:\Users\rjain\.claude\commands\gsd\gen-integration-test.md
