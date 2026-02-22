<purpose>
Generate a Model Context Protocol (MCP) server that exposes tools, resources, and prompts from your application's API or database. Follows the MCP specification for seamless integration with Claude Desktop, Claude Code, and other MCP-compatible clients.

The server follows API-First architecture (communicates via your existing API, never holds DB credentials directly unless explicitly configured as a DB-direct server). Supports stdio and SSE transports.
</purpose>

<core_principle>
One codebase, multiple transports. The core MCP server logic lives in shared/, with transport adapters for stdio (Claude Desktop) and SSE/HTTP (remote clients). Tools map to your API endpoints or stored procedures. Resources expose data. Prompts provide templates.
</core_principle>

<required_reading>
Read STATE.md and ROADMAP.md before any operation to load project context.
Read any existing OpenAPI spec at docs/spec/openapi.yaml for API integration.
Read any existing API-SP Map at docs/spec/api-sp-map.md for stored procedure mapping.
</required_reading>

<process>

<step name="initialize" priority="first">
Determine project context:

1. Check if `.planning/` exists (GSD project) or standalone generation
2. Check for existing OpenAPI spec at `docs/spec/openapi.yaml`
3. Check for existing API-SP Map at `docs/spec/api-sp-map.md`
4. Check for existing stored procedures in `db/sql/procedures/`
5. Detect project language (C#/.NET preferred for Technijian stack, Node.js/TypeScript alternative)

Parse arguments:
- `$ARGUMENTS` may contain: `--name <server-name>`, `--api-url <base-url>`, `--db-direct`
- `--db-direct` flag: generate a server that connects to SQL Server directly via stored procedures (instead of going through the API layer)
</step>

<step name="ask_data_source">
Present the data source choice to the user:

```
AskUserQuestion(
  header="Data source",
  question="How should the MCP server access your application data?",
  options=[
    {
      label: "API-First (Recommended)",
      description: "Server calls your existing Web API endpoints. No DB credentials needed. Uses typed HTTP client generated from OpenAPI spec."
    },
    {
      label: "DB-Direct (SP-Only)",
      description: "Server connects to SQL Server directly and calls stored procedures via Dapper. Follows SP-Only pattern. Best for internal/admin tools."
    },
    {
      label: "Hybrid",
      description: "Some tools call the API, others call stored procedures directly. Useful when some operations aren't exposed via API yet."
    }
  ]
)
```

Store choice as `DATA_MODE`: `api-first`, `db-direct`, or `hybrid`.
</step>

<step name="ask_transport">
Present transport choice:

```
AskUserQuestion(
  header="Transport",
  question="Which MCP transport(s) should the server support?",
  multiSelect=true,
  options=[
    {
      label: "stdio (Recommended)",
      description: "Standard I/O transport for local clients like Claude Desktop and Claude Code. Server runs as a subprocess."
    },
    {
      label: "SSE (Server-Sent Events)",
      description: "HTTP-based transport for remote clients. Server runs as a web service. Supports multiple concurrent clients."
    },
    {
      label: "Streamable HTTP",
      description: "Newer HTTP transport (MCP 2025-03-26 spec). Single endpoint, supports streaming. Future-proof but less client support."
    }
  ]
)
```

Store as `TRANSPORTS[]`.
</step>

<step name="discover_tools">
Auto-discover potential MCP tools from project sources:

**If OpenAPI spec exists:**
- Parse all endpoints and group by entity
- Each endpoint becomes a candidate tool
- Map: `GET /api/users/{id}` â†’ tool `get_user`, `POST /api/users` â†’ tool `create_user`

**If API-SP Map exists:**
- Parse SP mappings to understand data flow
- Each SP becomes a candidate tool for db-direct mode

**If stored procedures exist:**
- Scan `db/sql/procedures/` for `usp_*` files
- Each SP becomes a candidate tool

Present discovered tools for user confirmation:
```
AskUserQuestion(
  header="Tools",
  question="Which tool groups should the MCP server expose?",
  multiSelect=true,
  options=[
    { label: "Users", description: "CRUD operations for users (5 tools)" },
    { label: "Conversations", description: "Chat and conversation management (8 tools)" },
    { label: "Council", description: "LLM Council deliberation (6 tools)" },
    { label: "All", description: "Expose all discovered endpoints as tools" }
  ]
)
```
</step>

<step name="generate_project_structure">
Generate the directory structure:

```
src/mcp-servers/{server-name}/
  shared/                              # Core MCP logic
    server.ts (or .cs)                 # MCP server setup and configuration
    tools/                             # Tool definitions
      {entity}.tools.ts                # Tools grouped by entity
      index.ts                         # Tool registry
    resources/                         # Resource definitions
      {entity}.resources.ts            # Resources grouped by entity
      index.ts                         # Resource registry
    prompts/                           # Prompt templates
      {entity}.prompts.ts              # Prompts grouped by entity
      index.ts                         # Prompt registry
    data-access/                       # Data access layer
      api-client.ts                    # Typed HTTP client (if api-first/hybrid)
      db-client.ts                     # Dapper/SQL client (if db-direct/hybrid)
      connection.ts                    # Connection management
    types.ts                           # Shared type definitions
    config.ts                          # Configuration loader
    logger.ts                          # Structured logging

  transports/
    stdio/                             # stdio transport adapter
      index.ts                         # Entry point for stdio mode
    sse/                               # SSE transport adapter (if selected)
      index.ts                         # Express/Kestrel SSE server
      middleware.ts                    # Auth, CORS, rate limiting
    streamable-http/                   # Streamable HTTP (if selected)
      index.ts                         # HTTP transport entry point

  config/
    default.json                       # Default configuration
    schema.json                        # JSON Schema for config validation
    claude-desktop.json                # Example Claude Desktop config snippet

  tests/
    tools.test.ts                      # Tool execution tests
    resources.test.ts                  # Resource access tests
    integration.test.ts                # End-to-end MCP protocol tests

  package.json (or .csproj)            # Project manifest
  tsconfig.json                        # TypeScript config (if TS)
  README.md                            # Server documentation with setup instructions
```
</step>

<step name="generate_server_core">
Generate the MCP server core:

**Server setup** must implement:
1. **Tool registration**: Each tool with name, description, input schema (JSON Schema), handler
2. **Resource registration**: Each resource with URI template, name, description, handler
3. **Prompt registration**: Each prompt with name, description, arguments, template
4. **Protocol compliance**: Proper MCP message handling (initialize, tools/list, tools/call, etc.)
5. **Error handling**: MCP-compliant error responses with error codes
6. **Logging**: Structured logging that doesn't interfere with stdio transport

**Tool generation** pattern:
```typescript
// Each tool maps to an API endpoint or stored procedure
{
  name: "get_user",
  description: "Get a user by their ID",
  inputSchema: {
    type: "object",
    properties: {
      userId: { type: "string", description: "The user's unique identifier" }
    },
    required: ["userId"]
  },
  handler: async (args) => {
    // API-First: call API endpoint
    const user = await apiClient.get(`/api/users/${args.userId}`);
    // DB-Direct: call stored procedure
    // const user = await db.execute("usp_User_GetById", { Id: args.userId });
    return { content: [{ type: "text", text: JSON.stringify(user, null, 2) }] };
  }
}
```

**Resource generation** pattern:
```typescript
{
  uri: "tcai://users/{userId}",
  name: "User Profile",
  description: "User profile data",
  mimeType: "application/json",
  handler: async (uri) => {
    const userId = extractParam(uri, "userId");
    const user = await apiClient.get(`/api/users/${userId}`);
    return { contents: [{ uri, mimeType: "application/json", text: JSON.stringify(user) }] };
  }
}
```
</step>

<step name="generate_data_access">
Generate data access layer based on DATA_MODE:

**API-First mode:**
- Generate typed HTTP client from OpenAPI spec
- Handle auth (JWT token, API key)
- Retry logic with exponential backoff
- Request/response logging

**DB-Direct mode:**
- Generate Dapper-based SP caller
- Connection string from config (not hardcoded)
- TenantId injection on all queries (multi-tenancy)
- Connection pooling and disposal

**Hybrid mode:**
- Generate both clients
- Each tool specifies which data source it uses
- Configuration to switch tools between API and DB
</step>

<step name="generate_transports">
Generate transport adapters:

**stdio:**
- Entry point that creates server and connects via stdin/stdout
- No HTTP server needed
- Logging goes to stderr (not stdout, which is the MCP channel)

**SSE:**
- Express.js (Node) or Kestrel (C#) HTTP server
- SSE endpoint for serverâ†’client messages
- POST endpoint for clientâ†’server messages
- Optional auth middleware (API key, JWT)
- CORS configuration

**Streamable HTTP:**
- Single HTTP endpoint handling both directions
- Streaming response support
- Session management
</step>

<step name="generate_config_examples">
Generate configuration examples:

**Claude Desktop config snippet** (`claude_desktop_config.json`):
```json
{
  "mcpServers": {
    "{server-name}": {
      "command": "node",
      "args": ["path/to/{server-name}/transports/stdio/index.js"],
      "env": {
        "API_URL": "https://api.example.com",
        "API_KEY": "your-api-key"
      }
    }
  }
}
```

**Claude Code config snippet** (`.mcp.json`):
```json
{
  "{server-name}": {
    "command": "node",
    "args": ["path/to/{server-name}/transports/stdio/index.js"],
    "env": {
      "API_URL": "https://api.example.com"
    }
  }
}
```
</step>

<step name="generate_tests">
Generate test suite:

1. **Tool tests**: Each tool with mocked data source, verify input validation and response format
2. **Resource tests**: Each resource with mocked data, verify URI parsing and content format
3. **Protocol tests**: MCP message flow (initialize â†’ tools/list â†’ tools/call â†’ response)
4. **Transport tests**: stdio message framing, SSE connection lifecycle
5. **Integration tests**: End-to-end with real MCP client library
</step>

<step name="commit_and_report">
Commit all generated files:

```bash
git add src/mcp-servers/{server-name}/
git commit -m "feat: scaffold {server-name} MCP server ({data_mode}, {transports})"
```

Report:
```
## MCP Server Generated: {server-name}

**Data Mode**: {api-first | db-direct | hybrid}
**Transports**: {stdio, SSE, streamable-http}
**Tools**: {count} tools across {entity_count} entities
**Resources**: {count} resources
**Prompts**: {count} prompts

### Generated Structure
{tree output}

### Next Steps
1. Configure data source in config/default.json
2. Run tests: npm test (or dotnet test)
3. Build: npm run build (or dotnet publish)
4. Add to Claude Desktop: copy config/claude-desktop.json snippet
5. Add to Claude Code: update .mcp.json
6. Test with: npx @anthropic/mcp-inspector {server-name}
```
</step>

</process>

<success_criteria>
- [ ] MCP server core generated (tools, resources, prompts)
- [ ] Data access layer generated (API client and/or DB client)
- [ ] Transport adapters generated for selected transports
- [ ] Tool definitions generated from OpenAPI spec or stored procedures
- [ ] Configuration files and examples generated
- [ ] Claude Desktop and Claude Code config snippets provided
- [ ] Test suite generated
- [ ] README with setup instructions
</success_criteria>

<failure_handling>
- **No OpenAPI spec found**: Generate tools from stored procedures if available; otherwise generate a template server with example tools
- **No stored procedures found**: Generate API-first tools only; warn if db-direct was requested
- **Unknown entity structure**: Generate placeholder tools with TODO markers for the user to fill in
- **MCP SDK version mismatch**: Default to latest stable MCP SDK; note version in package.json
</failure_handling>

