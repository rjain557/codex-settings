---
name: gsd-gen-api-client
description: Generate typed API client SDKs from OpenAPI spec (TypeScript, C#, Swift, Kotlin) Use when the user asks for 'gsd:gen-api-client', 'gsd-gen-api-client', or equivalent trigger phrases.
---

# Purpose
Generate strongly-typed API client SDKs from your OpenAPI spec for multiple platforms. One spec, many clients.

The user chooses target platforms:
- **TypeScript**: For web app, browser extension, MCP server, Node.js agents. Optionally generates React Query hooks.
- **C# / .NET**: For .NET agents, desktop apps, server-to-server. DI-ready HttpClient service.
- **Swift**: For native iOS apps (if not using React Native).
- **Kotlin**: For native Android apps (if not using React Native).

All clients share the same contract with auth interceptors, tenant header injection, and retry logic.

# When to use
Use when the user requests the original gsd:gen-api-client flow (for example: $gsd-gen-api-client).
Also use on natural-language requests that match this behavior: Generate typed API client SDKs from OpenAPI spec (TypeScript, C#, Swift, Kotlin)

# Inputs
The user's text after invoking $gsd-gen-api-client is the arguments. Parse it into required fields; if any required field is missing, ask targeted follow-up questions.
Expected argument shape from source: [typescript|csharp|swift|kotlin] [--output <dir>] [--name <client-name>].
Context from source:
```text
Target: <parsed-arguments> (optional: typescript, csharp, swift, kotlin, or blank for all)

@.planning/STATE.md
@docs/spec/openapi.yaml
```

# Workflow
Load and follow these referenced artifacts first:
- @C:/Users/rjain/.claude/get-shit-done/workflows/gen-api-client.md
Then execute this process:
```text
Execute the gen-api-client workflow from @C:/Users/rjain/.claude/get-shit-done/workflows/gen-api-client.md end-to-end.
Parse OpenAPI spec, ask target platforms and features, generate typed clients with auth and tenant interceptors.
```

# Outputs / artifacts
Produce the artifacts specified by the workflow and summarize created/updated files.

# Guardrails (what not to do / how to ask for missing info)
- Do not invent missing project files, phase numbers, or state; inspect the repo first.
- Do not skip validation or checkpoint gates described in referenced workflows.
- If required context is missing, ask focused questions (one small batch) and proceed after answers.

# Source (path to original Claude command file)
- C:\Users\rjain\.claude\commands\gsd\gen-api-client.md
