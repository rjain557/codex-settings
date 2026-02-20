<purpose>
Generate integration tests for your API endpoints using xUnit and WebApplicationFactory. Creates test classes that verify the full request pipeline: HTTP request â†’ Controller â†’ Service â†’ Repository â†’ Stored Procedure â†’ Response.

Auto-discovers endpoints from OpenAPI spec or controllers and generates tests covering success cases, validation errors, auth failures, and multi-tenancy isolation.
</purpose>

<core_principle>
Every API endpoint gets an integration test. Tests use WebApplicationFactory to spin up the real ASP.NET Core pipeline (middleware, auth, DI, exception handling) with a test database. No mocking the service layer -- integration tests verify the full stack.
</core_principle>

<required_reading>
Read STATE.md and ROADMAP.md before any operation to load project context.
Read OpenAPI spec at docs/spec/openapi.yaml for endpoint catalog.
Read existing test infrastructure in tests/ directory.
Read controller implementations to understand request/response patterns.
</required_reading>

<process>

<step name="initialize" priority="first">
Determine project context:

1. Check if `.planning/` exists (GSD project) or standalone
2. Read OpenAPI spec at `docs/spec/openapi.yaml`
3. Scan controllers in `src/Server/*/Controllers/`
4. Check existing test infrastructure:
   - Test projects in `tests/`
   - WebApplicationFactory setup
   - Test database configuration
   - Test data builders/fixtures
5. Detect auth mechanism for test user setup

Parse arguments:
- `$ARGUMENTS` may contain: `--controller <name>`, `--entity <name>`, `--all`
- If no target specified, generate for all endpoints
</step>

<step name="ask_scope">
```
AskUserQuestion(
  header="Test scope",
  question="What scope of integration tests should be generated?",
  options=[
    {
      label: "All endpoints (Recommended)",
      description: "Generate integration tests for every API endpoint. Comprehensive coverage. May generate 50-200+ test methods."
    },
    {
      label: "CRUD operations only",
      description: "Generate tests for standard CRUD endpoints (List, Get, Create, Update, Delete) per entity. Core coverage."
    },
    {
      label: "Specific controller",
      description: "Generate tests for one controller only. You'll specify which one. Good for incremental test addition."
    },
    {
      label: "Auth & security only",
      description: "Generate tests focused on authentication, authorization, tenant isolation, and input validation. Security coverage."
    }
  ]
)
```

Store as `TEST_SCOPE`.
</step>

<step name="ask_database">
```
AskUserQuestion(
  header="Test DB",
  question="What database should integration tests use?",
  options=[
    {
      label: "SQL Server LocalDB (Recommended)",
      description: "Uses LocalDB for fast, isolated test database. Auto-created and destroyed per test run. No Docker needed."
    },
    {
      label: "Docker SQL Server",
      description: "Spin up SQL Server container for tests. More realistic but slower startup. Uses Testcontainers library."
    },
    {
      label: "In-memory (no DB)",
      description: "Mock the repository layer with in-memory data. Faster but doesn't test stored procedures or SQL. Not a true integration test."
    }
  ]
)
```

Store as `TEST_DB`.
</step>

<step name="generate_project_structure">
```
tests/
  Integration/
    {ProjectName}.Integration.Tests.csproj  # Test project
    Infrastructure/
      CustomWebApplicationFactory.cs        # WebApplicationFactory with test config
      TestDatabaseManager.cs                # Test DB setup/teardown
      TestAuthHandler.cs                    # Fake auth handler for test users
      TestTenantMiddleware.cs               # Test tenant ID injection
      TestDataBuilder.cs                    # Fluent test data builder
      ServiceCollectionExtensions.cs        # DI overrides for testing
    Fixtures/
      TestUsers.cs                          # Predefined test users (admin, regular, other-tenant)
      TestTenants.cs                        # Predefined test tenants
      SeedData.cs                           # Test seed data
    Controllers/
      UsersControllerTests.cs              # User endpoint tests
      ConversationsControllerTests.cs      # Conversation endpoint tests
      {Entity}ControllerTests.cs           # Per-entity test class
    Security/
      AuthorizationTests.cs                # [Authorize] enforcement tests
      TenantIsolationTests.cs              # Cross-tenant access prevention
      InputValidationTests.cs              # DTO validation tests
    Helpers/
      HttpClientExtensions.cs              # Typed response helpers
      AssertExtensions.cs                  # Custom assertions
```
</step>

<step name="generate_test_infrastructure">
Generate test infrastructure:

**CustomWebApplicationFactory:**
```csharp
public class CustomWebApplicationFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureServices(services =>
        {
            // Replace real DB with test DB
            services.RemoveAll<IDbConnectionFactory>();
            services.AddSingleton<IDbConnectionFactory>(
                new TestDbConnectionFactory(TestDatabaseManager.ConnectionString));

            // Replace real auth with test auth
            services.AddAuthentication("Test")
                .AddScheme<AuthenticationSchemeOptions, TestAuthHandler>("Test", null);
        });
    }
}
```

**TestAuthHandler:**
```csharp
public class TestAuthHandler : AuthenticationHandler<AuthenticationSchemeOptions>
{
    public static string TestUserId = "test-user-001";
    public static string TestTenantId = "test-tenant-001";

    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        var claims = new[]
        {
            new Claim("sub", TestUserId),
            new Claim("oid", TestUserId),
            new Claim("tid", TestTenantId),
        };
        var identity = new ClaimsIdentity(claims, "Test");
        var principal = new ClaimsPrincipal(identity);
        var ticket = new AuthenticationTicket(principal, "Test");
        return Task.FromResult(AuthenticateResult.Success(ticket));
    }
}
```

**TestDataBuilder** (fluent builder pattern):
```csharp
public class TestDataBuilder
{
    public static UserBuilder User() => new UserBuilder();
    public static ConversationBuilder Conversation() => new ConversationBuilder();
}

public class UserBuilder
{
    private CreateUserDto _dto = new() { Name = "Test User", Email = "test@example.com" };
    public UserBuilder WithName(string name) { _dto.Name = name; return this; }
    public UserBuilder WithEmail(string email) { _dto.Email = email; return this; }
    public CreateUserDto Build() => _dto;
}
```
</step>

<step name="generate_endpoint_tests">
For each endpoint, generate test methods:

**CRUD test pattern:**
```csharp
public class UsersControllerTests : IClassFixture<CustomWebApplicationFactory>
{
    private readonly HttpClient _client;

    public UsersControllerTests(CustomWebApplicationFactory factory)
    {
        _client = factory.CreateClient();
        _client.DefaultRequestHeaders.Add("X-Tenant-ID", TestAuthHandler.TestTenantId);
    }

    [Fact]
    public async Task GetUsers_ReturnsOk_WithUserList()
    {
        // Act
        var response = await _client.GetAsync("/api/users");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
        var users = await response.Content.ReadFromJsonAsync<List<UserResponseDto>>();
        users.Should().NotBeNull();
    }

    [Fact]
    public async Task CreateUser_WithValidDto_ReturnsCreated()
    {
        // Arrange
        var dto = TestDataBuilder.User().WithName("New User").Build();

        // Act
        var response = await _client.PostAsJsonAsync("/api/users", dto);

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.Created);
        var created = await response.Content.ReadFromJsonAsync<UserResponseDto>();
        created!.Name.Should().Be("New User");
    }

    [Fact]
    public async Task CreateUser_WithInvalidDto_ReturnsBadRequest()
    {
        // Arrange
        var dto = new CreateUserDto(); // Missing required fields

        // Act
        var response = await _client.PostAsJsonAsync("/api/users", dto);

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task GetUser_WithoutAuth_ReturnsUnauthorized()
    {
        // Arrange
        var client = _factory.CreateClient();
        // No auth header

        // Act
        var response = await client.GetAsync("/api/users");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task GetUser_WithOtherTenantId_ReturnsEmpty()
    {
        // Arrange - use different tenant
        _client.DefaultRequestHeaders.Remove("X-Tenant-ID");
        _client.DefaultRequestHeaders.Add("X-Tenant-ID", "other-tenant-999");

        // Act
        var response = await _client.GetAsync("/api/users");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
        var users = await response.Content.ReadFromJsonAsync<List<UserResponseDto>>();
        users.Should().BeEmpty(); // No cross-tenant data leaks
    }
}
```

**Test categories per endpoint:**
1. **Happy path**: Valid request â†’ expected response
2. **Validation**: Invalid DTO â†’ 400 Bad Request
3. **Not found**: Non-existent ID â†’ 404
4. **Auth**: No token â†’ 401 Unauthorized
5. **Tenant isolation**: Other tenant â†’ empty/forbidden
6. **Concurrency**: Simultaneous creates â†’ no duplicates
</step>

<step name="generate_security_tests">
Generate cross-cutting security tests:

**AuthorizationTests:**
- Every endpoint returns 401 without auth token
- Role-based endpoints return 403 for wrong role
- Expired tokens are rejected

**TenantIsolationTests:**
- Create data in Tenant A, query from Tenant B â†’ empty
- Update data from wrong tenant â†’ not found
- Delete data from wrong tenant â†’ not found
- List endpoints only return own tenant data

**InputValidationTests:**
- SQL injection attempts â†’ rejected (SPOnly helps but verify)
- XSS payloads in string fields â†’ sanitized
- Oversized payloads â†’ 413 or validation error
- Malformed JSON â†’ 400
</step>

<step name="commit_and_report">
Commit all generated files:

```bash
git add tests/Integration/
git commit -m "feat: generate integration tests ({test_count} tests, {controller_count} controllers)"
```

Report:
```
## Integration Tests Generated

**Scope**: {All endpoints | CRUD only | Specific controller | Security only}
**Test DB**: {LocalDB | Docker SQL Server | In-memory}
**Controllers**: {count} controllers covered
**Test Methods**: {count} test methods generated

### Coverage
| Controller | Tests | Happy Path | Validation | Auth | Tenant |
|------------|-------|------------|------------|------|--------|
| Users | 12 | 4 | 3 | 2 | 3 |
| Conversations | 15 | 5 | 4 | 2 | 4 |

### Next Steps
1. Run tests: dotnet test tests/Integration/
2. Review generated tests for accuracy
3. Add custom assertions for domain-specific validation
4. Integrate into CI pipeline
5. Add missing edge cases specific to your business logic
```
</step>

</process>

<success_criteria>
- [ ] WebApplicationFactory configured with test DB and auth
- [ ] Test data builders for each entity
- [ ] Happy path tests for all endpoints
- [ ] Validation error tests for all DTOs
- [ ] Auth enforcement tests (401/403)
- [ ] Tenant isolation tests (cross-tenant prevention)
- [ ] Input validation / security tests
- [ ] Tests pass when run against test database
</success_criteria>

<failure_handling>
- **No OpenAPI spec**: Scan controllers directly for endpoint discovery
- **No test project exists**: Create new xUnit test project with all dependencies
- **No stored procedures in test DB**: Generate test DB setup script that creates SPs
- **Complex auth setup**: Default to fake auth handler; document real auth test setup
</failure_handling>

