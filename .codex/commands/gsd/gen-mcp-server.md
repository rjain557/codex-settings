---
name: gsd:gen-mcp-server
description: Generate MCP server from OpenAPI spec or stored procedures with stdio/SSE transports
argument-hint: "[--name <server-name>] [--api-url <url>] [--db-direct]"
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
Generate a Model Context Protocol (MCP) server that exposes your application's API endpoints and/or stored procedures as MCP tools, resources, and prompts.

The user chooses the data source:
- **API-First**: Server calls your Web API (recommended, no DB credentials needed)
- **DB-Direct**: Server calls stored procedures via Dapper (SP-Only pattern)
- **Hybrid**: Mix of API and direct SP calls

Default transport: stdio (for Claude Desktop/Code). Optionally adds SSE or Streamable HTTP.
</objective>

<execution_context>
@C:/Users/rjain/.claude/get-shit-done/workflows/gen-mcp-server.md
</execution_context>

<context>
Target: $ARGUMENTS (optional flags)

@.planning/STATE.md
@docs/spec/openapi.yaml
@docs/spec/api-sp-map.md
</context>

<process>
Execute the gen-mcp-server workflow from @C:/Users/rjain/.claude/get-shit-done/workflows/gen-mcp-server.md end-to-end.
Ask the data source and transport questions before generating. Auto-discover tools from OpenAPI spec and stored procedures.
</process>
