---
name: gsd:gen-api-client
description: Generate typed API client SDKs from OpenAPI spec (TypeScript, C#, Swift, Kotlin)
argument-hint: "[typescript|csharp|swift|kotlin] [--output <dir>] [--name <client-name>]"
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
Generate strongly-typed API client SDKs from your OpenAPI spec for multiple platforms. One spec, many clients.

The user chooses target platforms:
- **TypeScript**: For web app, browser extension, MCP server, Node.js agents. Optionally generates React Query hooks.
- **C# / .NET**: For .NET agents, desktop apps, server-to-server. DI-ready HttpClient service.
- **Swift**: For native iOS apps (if not using React Native).
- **Kotlin**: For native Android apps (if not using React Native).

All clients share the same contract with auth interceptors, tenant header injection, and retry logic.
</objective>

<execution_context>
@C:/Users/rjain/.claude/get-shit-done/workflows/gen-api-client.md
</execution_context>

<context>
Target: $ARGUMENTS (optional: typescript, csharp, swift, kotlin, or blank for all)

@.planning/STATE.md
@docs/spec/openapi.yaml
</context>

<process>
Execute the gen-api-client workflow from @C:/Users/rjain/.claude/get-shit-done/workflows/gen-api-client.md end-to-end.
Parse OpenAPI spec, ask target platforms and features, generate typed clients with auth and tenant interceptors.
</process>
