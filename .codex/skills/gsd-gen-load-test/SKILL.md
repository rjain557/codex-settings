---
name: gsd-gen-load-test
description: Generate load test suite (k6/Artillery) from OpenAPI spec with CI integration Use when the user asks for 'gsd:gen-load-test', 'gsd-gen-load-test', or equivalent trigger phrases.
---

# Purpose
Generate a comprehensive load test suite from your OpenAPI spec or API controllers. Creates test scripts for 6 scenarios (smoke, baseline, load, stress, spike, soak) with performance thresholds and CI pipeline integration.

The user chooses the tool:
- **k6**: JavaScript-based, lightweight, excellent for API testing (recommended)
- **Artillery**: YAML-driven, Node.js-based, good for WebSocket/SSE
- **Both**: Generate scripts for both tools

Fills the Phase L-Q performance testing gap in Technijian SDLC v6.0.

# When to use
Use when the user requests the original gsd:gen-load-test flow (for example: $gsd-gen-load-test).
Also use on natural-language requests that match this behavior: Generate load test suite (k6/Artillery) from OpenAPI spec with CI integration

# Inputs
The user's text after invoking $gsd-gen-load-test is the arguments. Parse it into required fields; if any required field is missing, ask targeted follow-up questions.
Expected argument shape from source: [--tool <k6|artillery>] [--ci <github|azure>] [--api-url <url>].
Context from source:
```text
Target: <parsed-arguments> (optional flags)

@.planning/STATE.md
@docs/spec/openapi.yaml
```

# Workflow
Load and follow these referenced artifacts first:
- @C:/Users/rjain/.claude/get-shit-done/workflows/gen-load-test.md
Then execute this process:
```text
Execute the gen-load-test workflow from @C:/Users/rjain/.claude/get-shit-done/workflows/gen-load-test.md end-to-end.
Auto-discover endpoints from OpenAPI spec. Ask tool and CI platform questions before generating. Generate scenarios with realistic load profiles and performance thresholds.
```

# Outputs / artifacts
Produce the artifacts specified by the workflow and summarize created/updated files.

# Guardrails (what not to do / how to ask for missing info)
- Do not invent missing project files, phase numbers, or state; inspect the repo first.
- Do not skip validation or checkpoint gates described in referenced workflows.
- If required context is missing, ask focused questions (one small batch) and proceed after answers.

# Source (path to original Claude command file)
- C:\Users\rjain\.claude\commands\gsd\gen-load-test.md
