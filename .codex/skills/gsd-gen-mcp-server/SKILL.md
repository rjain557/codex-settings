---
name: gsd-gen-mcp-server
description: Generate MCP server from OpenAPI spec or stored procedures with stdio/SSE transports Use when the user asks for 'gsd:gen-mcp-server', 'gsd-gen-mcp-server', or equivalent trigger phrases.
---

# Purpose
Generate a Model Context Protocol (MCP) server that exposes your application's API endpoints and/or stored procedures as MCP tools, resources, and prompts.

The user chooses the data source:
- **API-First**: Server calls your Web API (recommended, no DB credentials needed)
- **DB-Direct**: Server calls stored procedures via Dapper (SP-Only pattern)
- **Hybrid**: Mix of API and direct SP calls

Default transport: stdio (for Claude Desktop/Code). Optionally adds SSE or Streamable HTTP.

# When to use
Use when the user requests the original gsd:gen-mcp-server flow (for example: $gsd-gen-mcp-server).
Also use on natural-language requests that match this behavior: Generate MCP server from OpenAPI spec or stored procedures with stdio/SSE transports

# Inputs
The user's text after invoking $gsd-gen-mcp-server is the arguments. Parse it into required fields; if any required field is missing, ask targeted follow-up questions.
Expected argument shape from source: [--name <server-name>] [--api-url <url>] [--db-direct].
Context from source:
```text
Target: <parsed-arguments> (optional flags)

@.planning/STATE.md
@docs/spec/openapi.yaml
@docs/spec/api-sp-map.md
```

# Workflow
Load and follow these referenced artifacts first:
- @C:/Users/rjain/.claude/get-shit-done/workflows/gen-mcp-server.md
Then execute this process:
```text
Execute the gen-mcp-server workflow from @C:/Users/rjain/.claude/get-shit-done/workflows/gen-mcp-server.md end-to-end.
Ask the data source and transport questions before generating. Auto-discover tools from OpenAPI spec and stored procedures.
```

# Outputs / artifacts
Produce the artifacts specified by the workflow and summarize created/updated files.

# Guardrails (what not to do / how to ask for missing info)
- Do not invent missing project files, phase numbers, or state; inspect the repo first.
- Do not skip validation or checkpoint gates described in referenced workflows.
- If required context is missing, ask focused questions (one small batch) and proceed after answers.

# Source (path to original Claude command file)
- C:\Users\rjain\.claude\commands\gsd\gen-mcp-server.md
