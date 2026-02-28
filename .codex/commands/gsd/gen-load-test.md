---
name: gsd:gen-load-test
description: Generate load test suite (k6/Artillery) from OpenAPI spec with CI integration
argument-hint: "[--tool <k6|artillery>] [--ci <github|azure>] [--api-url <url>]"
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
Generate a comprehensive load test suite from your OpenAPI spec or API controllers. Creates test scripts for 6 scenarios (smoke, baseline, load, stress, spike, soak) with performance thresholds and CI pipeline integration.

The user chooses the tool:
- **k6**: JavaScript-based, lightweight, excellent for API testing (recommended)
- **Artillery**: YAML-driven, Node.js-based, good for WebSocket/SSE
- **Both**: Generate scripts for both tools

Fills the Phase L-Q performance testing gap in Technijian SDLC v6.0.
</objective>

<execution_context>
@C:/Users/rjain/.codex/get-shit-done/workflows/gen-load-test.md
</execution_context>

<context>
Target: $ARGUMENTS (optional flags)

@.planning/STATE.md
@docs/spec/openapi.yaml
</context>

<process>
Execute the gen-load-test workflow from @C:/Users/rjain/.codex/get-shit-done/workflows/gen-load-test.md end-to-end.
Auto-discover endpoints from OpenAPI spec. Ask tool and CI platform questions before generating. Generate scenarios with realistic load profiles and performance thresholds.
</process>

