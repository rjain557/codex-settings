<purpose>
Generate typed API client SDKs from your OpenAPI spec for multiple platforms. Creates strongly-typed HTTP clients for TypeScript, C#, Swift, and Kotlin that can be consumed by your web app, mobile app, browser extension, remote agent, and MCP server.

Ensures all clients share the same contract (types, endpoints, error handling) and stay in sync with the API spec. One spec, many clients.
</purpose>

<core_principle>
Single source of truth. The OpenAPI spec defines the contract. All client SDKs are generated from it. When the spec changes, regenerate the clients. No hand-written API calls that can drift from the contract.
</core_principle>

<required_reading>
Read STATE.md and ROADMAP.md before any operation to load project context.
Read the OpenAPI spec at docs/spec/openapi.yaml for complete endpoint catalog.
Check for existing API clients in the codebase.
</required_reading>

<process>

<step name="initialize" priority="first">
Determine project context:

1. Check if `.planning/` exists (GSD project) or standalone
2. Read OpenAPI spec at `docs/spec/openapi.yaml`
3. Detect existing API clients:
   - Web: `src/Client/*/api/` or `src/Client/*/services/`
   - Mobile: `src/mobile/*/services/api-client.*`
   - Extension: `src/extensions/*/shared/background/api-client.*`
   - Agent: `src/agents/*/shared/api-client.*`
   - MCP: `src/mcp-servers/*/shared/data-access/api-client.*`
4. Detect auth mechanism (Azure AD, JWT, API key)

Parse arguments:
- `$ARGUMENTS` may contain target: `typescript`, `csharp`, `swift`, `kotlin`, or empty for all
- Parse flags: `--output <dir>`, `--name <client-name>`
</step>

<step name="ask_targets">
```
AskUserQuestion(
  header="Platforms",
  question="Which client SDK(s) should be generated?",
  multiSelect=true,
  options=[
    {
      label: "TypeScript (Recommended)",
      description: "For web app, browser extension, MCP server, and Node.js agents. Uses fetch/axios with full type safety. Generates React Query hooks optionally."
    },
    {
      label: "C# / .NET",
      description: "For .NET agents, desktop apps, and server-to-server calls. Uses HttpClient with typed request/response. Generates DI-ready service."
    },
    {
      label: "Swift",
      description: "For native iOS apps. Uses URLSession with Codable models. Generates async/await API. Useful if not using React Native."
    },
    {
      label: "Kotlin",
      description: "For native Android apps. Uses Retrofit/Ktor with data classes. Generates coroutine-based API. Useful if not using React Native."
    }
  ]
)
```

Store as `TARGETS[]`.
</step>

<step name="ask_features">
```
AskUserQuestion(
  header="Features",
  question="What features should the API client include?",
  multiSelect=true,
  options=[
    {
      label: "React Query hooks (Recommended)",
      description: "Generate useQuery/useMutation hooks for each endpoint. Includes query keys, cache invalidation, and optimistic updates. TypeScript only."
    },
    {
      label: "Offline queue",
      description: "Queue mutations when offline, replay on reconnect. For mobile and extension clients that need offline support."
    },
    {
      label: "Request/response logging",
      description: "Structured logging of all API calls with timing, status, and sanitized headers. Useful for debugging."
    },
    {
      label: "Mock client",
      description: "Generate a mock implementation with fake data for testing. Same interface as real client. Useful for unit tests and Storybook."
    }
  ]
)
```

Store as `FEATURES[]`.
</step>

<step name="parse_openapi">
Parse the OpenAPI spec and extract:

1. **Endpoints**: Method, path, operation ID, description
2. **Request types**: Body schemas, query parameters, path parameters
3. **Response types**: Success responses, error responses
4. **Auth**: Security schemes (Bearer, OAuth2, API key)
5. **Models**: All schema definitions (used in request/response)
6. **Tags**: Group endpoints by controller/entity
7. **Streaming**: SSE endpoints (special handling)

Map each endpoint to a typed method:
```
GET    /api/users          â†’ getUsers(filters?: UserFilters): Promise<UserResponseDto[]>
GET    /api/users/{id}     â†’ getUser(id: string): Promise<UserResponseDto>
POST   /api/users          â†’ createUser(dto: CreateUserDto): Promise<UserResponseDto>
PUT    /api/users/{id}     â†’ updateUser(id: string, dto: UpdateUserDto): Promise<UserResponseDto>
DELETE /api/users/{id}     â†’ deleteUser(id: string): Promise<void>
```
</step>

<step name="generate_typescript_client">
If TypeScript is in TARGETS[]:

```
src/shared/api-client/
  index.ts                             # Main export
  client.ts                            # Base HTTP client (fetch/axios wrapper)
  config.ts                            # Client configuration (base URL, auth, timeouts)
  auth.ts                              # Auth token management (Azure AD / JWT)
  types/
    models.ts                          # All DTO types (from OpenAPI schemas)
    requests.ts                        # Request parameter types
    responses.ts                       # Response wrapper types
    errors.ts                          # Error types
  endpoints/
    users.ts                           # User endpoint methods
    conversations.ts                   # Conversation endpoint methods
    {entity}.ts                        # Per-entity endpoint file
  hooks/                               # Only if React Query hooks selected
    useUsers.ts                        # React Query hooks for users
    useConversations.ts                # React Query hooks for conversations
    query-keys.ts                      # Centralized query key definitions
    index.ts                           # Hook exports
  mock/                                # Only if mock client selected
    mock-client.ts                     # Mock implementation
    fixtures/                          # Mock data fixtures
  interceptors/
    auth-interceptor.ts                # Auto-attach auth token
    retry-interceptor.ts               # Retry on 5xx with backoff
    tenant-interceptor.ts              # Auto-attach X-Tenant-ID header
    logging-interceptor.ts             # Request/response logging
  package.json                         # Publishable as npm package
  tsconfig.json
```

**Key patterns:**

Base client with interceptor chain:
```typescript
export class ApiClient {
  constructor(config: ApiClientConfig) {
    this.baseUrl = config.baseUrl;
    this.interceptors = [
      new AuthInterceptor(config.auth),
      new TenantInterceptor(config.tenantId),
      new RetryInterceptor({ maxRetries: 3 }),
    ];
  }

  // Type-safe endpoint groups
  readonly users = new UsersEndpoints(this);
  readonly conversations = new ConversationsEndpoints(this);
}
```

React Query hooks (if selected):
```typescript
export function useUsers(filters?: UserFilters) {
  return useQuery({
    queryKey: queryKeys.users.list(filters),
    queryFn: () => apiClient.users.getUsers(filters),
  });
}

export function useCreateUser() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (dto: CreateUserDto) => apiClient.users.createUser(dto),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: queryKeys.users.all }),
  });
}
```
</step>

<step name="generate_csharp_client">
If C# is in TARGETS[]:

```
src/shared/ApiClient/
  {ProjectName}.ApiClient.csproj       # Class library project
  ApiClient.cs                         # Main client class
  ApiClientConfig.cs                   # Configuration
  Auth/
    ITokenProvider.cs                  # Token provider interface
    AzureAdTokenProvider.cs            # Azure AD implementation
    JwtTokenProvider.cs                # JWT implementation
  Models/
    {Entity}Dtos.cs                    # DTO classes (from OpenAPI schemas)
  Endpoints/
    {Entity}Endpoints.cs               # Per-entity endpoint methods
  Handlers/
    AuthHandler.cs                     # DelegatingHandler for auth
    TenantHandler.cs                   # DelegatingHandler for X-Tenant-ID
    RetryHandler.cs                    # Polly retry handler
  Extensions/
    ServiceCollectionExtensions.cs     # DI registration
```

DI registration:
```csharp
services.AddApiClient(options => {
    options.BaseUrl = configuration["Api:BaseUrl"];
    options.TenantId = tenantId;
});
```
</step>

<step name="generate_swift_client">
If Swift is in TARGETS[]:

Generate Swift package with:
- URLSession-based client with async/await
- Codable models from OpenAPI schemas
- Auth token management
- Result type error handling
</step>

<step name="generate_kotlin_client">
If Kotlin is in TARGETS[]:

Generate Kotlin module with:
- Ktor or Retrofit client with coroutines
- Data classes from OpenAPI schemas
- Auth interceptor
- Sealed class error handling
</step>

<step name="generate_tests">
Generate tests for each client:

1. **Type tests**: Verify models serialize/deserialize correctly
2. **Endpoint tests**: Mock HTTP responses, verify correct URL/method/headers
3. **Auth tests**: Token refresh, 401 handling, header injection
4. **Interceptor tests**: Retry logic, tenant header, logging
5. **Mock client tests**: Verify mock returns expected fixture data
</step>

<step name="commit_and_report">
Commit all generated files:

```bash
git add src/shared/api-client/ src/shared/ApiClient/
git commit -m "feat: generate typed API client SDKs ({targets}) from OpenAPI spec"
```

Report:
```
## API Client SDKs Generated

**Source**: docs/spec/openapi.yaml
**Endpoints**: {count} endpoints across {entity_count} entities
**Models**: {count} DTO types

### Generated Clients
| Platform | Location | Endpoints | Models |
|----------|----------|-----------|--------|
| TypeScript | src/shared/api-client/ | {n} | {n} |
| C# | src/shared/ApiClient/ | {n} | {n} |

### Features
- Auth: {Azure AD | JWT} token management
- Multi-tenancy: X-Tenant-ID auto-injection
- Retry: 3 retries with exponential backoff on 5xx
- React Query hooks: {count} hooks (if selected)
- Mock client: {Yes | No}

### Next Steps
1. Install: npm install ./src/shared/api-client (or add project reference)
2. Configure: Set API_URL and auth credentials
3. Use in web app: import { useUsers } from '@shared/api-client/hooks'
4. Use in mobile: import { ApiClient } from '@shared/api-client'
5. Regenerate after spec changes: /gsd:gen-api-client
```
</step>

</process>

<success_criteria>
- [ ] OpenAPI spec fully parsed (endpoints, models, auth)
- [ ] TypeScript client with full type safety
- [ ] All endpoints mapped to typed methods
- [ ] Auth interceptor handles token refresh
- [ ] Tenant interceptor adds X-Tenant-ID header
- [ ] React Query hooks generated (if selected)
- [ ] Mock client generated (if selected)
- [ ] Test suite for each client
- [ ] Publishable as standalone package
</success_criteria>

<failure_handling>
- **No OpenAPI spec found**: Error -- this skill requires an OpenAPI spec. Recommend creating one first.
- **Spec has validation errors**: Warn and generate from valid portions; list errors
- **Unknown auth scheme**: Default to Bearer token; warn user to configure
- **SSE/streaming endpoints**: Generate special streaming handler with EventSource/SSE client
</failure_handling>

