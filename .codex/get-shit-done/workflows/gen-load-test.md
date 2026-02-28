<purpose>
Generate a comprehensive load test suite from your OpenAPI spec or API endpoint catalog. Creates k6 or Artillery test scripts with performance baselines, ramp-up scenarios, and CI pipeline integration.

Fills the Phase L-Q performance testing gap in Technijian SDLC v6.0 by providing automated load tests that validate API response times, throughput, and error rates before deployment.
</purpose>

<core_principle>
Every API endpoint gets a performance baseline. Load tests are generated from the OpenAPI spec (contract-first), not from guessing endpoints. Each test defines thresholds (p95 latency, error rate, throughput) that fail the CI pipeline if exceeded.
</core_principle>

<required_reading>
Read STATE.md and ROADMAP.md before any operation to load project context.
Read any existing OpenAPI spec at docs/spec/openapi.yaml for endpoint discovery.
Read any existing API-SP Map at docs/spec/api-sp-map.md for understanding data flow complexity.
</required_reading>

<process>

<step name="initialize" priority="first">
Determine project context:

1. Check if `.planning/` exists (GSD project) or standalone generation
2. Check for existing OpenAPI spec at `docs/spec/openapi.yaml`
3. Check for existing API controllers in `src/Server/*/Controllers/`
4. Check for existing test infrastructure (tests/ directory, CI config)
5. Detect API base URL from configuration

Parse arguments:
- `$ARGUMENTS` may contain flags: `--tool <k6|artillery>`, `--ci <github|azure|gitlab>`, `--api-url <base-url>`
</step>

<step name="ask_tool">
Present the load test tool choice:

```
AskUserQuestion(
  header="Test tool",
  question="Which load testing tool should be used?",
  options=[
    {
      label: "k6 (Recommended)",
      description: "JavaScript-based load testing by Grafana Labs. Lightweight, scriptable, excellent CLI output. Runs locally or in k6 Cloud. Best for API-focused testing."
    },
    {
      label: "Artillery",
      description: "Node.js-based load testing. YAML-driven scenarios with JavaScript hooks. Good reporting dashboard. Supports WebSocket and SSE natively."
    },
    {
      label: "Both",
      description: "Generate test scripts for both tools. Useful for comparison or team preference. Same scenarios, different runtimes."
    }
  ]
)
```

Store choice as `TOOL`: `k6`, `artillery`, or `both`.
</step>

<step name="ask_ci">
Present CI integration choice:

```
AskUserQuestion(
  header="CI platform",
  question="Which CI/CD platform should the load tests integrate with?",
  options=[
    {
      label: "GitHub Actions (Recommended)",
      description: "GitHub Actions workflow that runs load tests on PR merge to main or on schedule. Stores results as artifacts."
    },
    {
      label: "Azure DevOps",
      description: "Azure Pipelines YAML with load test stage. Integrates with Azure Load Testing service for cloud runs."
    },
    {
      label: "None (local only)",
      description: "Scripts for local execution only. No CI pipeline generated. Run manually with npm scripts."
    }
  ]
)
```

Store as `CI_PLATFORM`.
</step>

<step name="discover_endpoints">
Auto-discover API endpoints from project sources:

**If OpenAPI spec exists:**
- Parse all endpoints with method, path, request/response schemas
- Categorize by: read (GET), write (POST/PUT/PATCH), delete (DELETE)
- Identify auth-required vs public endpoints
- Detect SSE/streaming endpoints (special handling)
- Estimate complexity from response schema size and SP mapping

**If no OpenAPI spec:**
- Scan controllers in `src/Server/*/Controllers/` for `[HttpGet]`, `[HttpPost]`, etc.
- Extract route patterns from `[Route]` attributes
- Warn that baselines may be less accurate without full spec

**Categorize endpoints by load profile:**
- **High-frequency reads**: List/search endpoints (e.g., GET /api/conversations)
- **Auth flows**: Login, token refresh (burst pattern)
- **Write operations**: Create/update (sustained load)
- **Heavy queries**: Reports, exports, aggregations (low concurrency)
- **Real-time**: SSE/streaming endpoints (long-lived connections)

Present summary for confirmation:
```
Discovered {N} endpoints across {M} controllers:
- {X} read endpoints (high-frequency)
- {Y} write endpoints (sustained)
- {Z} auth endpoints (burst)
- {W} heavy/report endpoints (low concurrency)
```
</step>

<step name="generate_project_structure">
Generate the directory structure:

```
tests/load/
  config/
    default.json                       # Default test configuration
    environments/
      local.json                       # Local environment (localhost)
      staging.json                     # Staging environment
      production.json                  # Production (read-only tests)
    thresholds.json                    # Performance thresholds per endpoint

  k6/                                  # Only if k6 selected
    scenarios/
      smoke.js                         # Smoke test (1 VU, verify endpoints work)
      baseline.js                      # Baseline test (10 VUs, 1 min, establish metrics)
      load.js                          # Load test (50-100 VUs, 5 min, sustained load)
      stress.js                        # Stress test (ramp to 200+ VUs, find breaking point)
      spike.js                         # Spike test (sudden burst, recovery)
      soak.js                          # Soak test (moderate load, 30+ min, memory leaks)
    lib/
      api-client.js                    # k6 HTTP client with auth
      auth.js                          # Token acquisition for load test users
      data-generators.js               # Random test data generation
      checks.js                        # Reusable response checks
      thresholds.js                    # Threshold definitions
    endpoints/
      {entity}.js                      # Per-entity endpoint tests (users.js, conversations.js)
    package.json                       # k6 dependencies (for bundling)
    webpack.config.js                  # Bundle k6 scripts with dependencies

  artillery/                           # Only if Artillery selected
    scenarios/
      smoke.yml                        # Smoke test scenario
      baseline.yml                     # Baseline scenario
      load.yml                         # Load test scenario
      stress.yml                       # Stress test scenario
      spike.yml                        # Spike test scenario
      soak.yml                         # Soak test scenario
    lib/
      auth.js                          # Auth helper functions
      data-generators.js               # Test data generators
      custom-checks.js                 # Custom Artillery checks
    endpoints/
      {entity}.yml                     # Per-entity flows
    artillery.yml                      # Main Artillery config

  ci/
    github-actions.yml                 # GitHub Actions workflow (if selected)
    azure-pipelines.yml                # Azure Pipelines (if selected)

  reports/
    .gitkeep                           # Report output directory

  scripts/
    run-smoke.sh                       # Quick smoke test runner
    run-baseline.sh                    # Baseline test runner
    run-load.sh                        # Full load test runner
    generate-report.sh                 # Generate HTML report from results

  README.md                            # Load testing documentation
  package.json                         # npm scripts for running tests
```
</step>

<step name="generate_scenarios">
Generate test scenarios with realistic load profiles:

**Smoke test** (sanity check):
- 1 virtual user, 1 iteration per endpoint
- Verify: all endpoints return expected status codes
- Duration: < 1 minute
- Use: pre-deployment gate

**Baseline test** (establish metrics):
- 10 VUs, 1 minute sustained
- Record: p50, p95, p99 latency per endpoint
- Record: requests/sec, error rate
- Use: first run to establish thresholds

**Load test** (normal traffic):
- Ramp: 0 â†’ 50 VUs over 1 min, hold 5 min, ramp down 1 min
- Thresholds: p95 < 500ms, error rate < 1%
- Mix: 70% reads, 20% writes, 10% auth
- Use: regular CI pipeline

**Stress test** (find limits):
- Ramp: 0 â†’ 100 â†’ 200 â†’ 300 VUs in stages
- Find: breaking point (error rate > 5% or p95 > 2s)
- Use: capacity planning

**Spike test** (sudden burst):
- Base: 20 VUs, spike to 200 VUs for 30s, back to 20
- Verify: recovery time, no cascading failures
- Use: resilience testing

**Soak test** (endurance):
- 30 VUs sustained for 30 minutes
- Monitor: memory growth, connection leaks, response time degradation
- Use: pre-release validation
</step>

<step name="generate_auth_helper">
Generate authentication for load test users:

**JWT-based auth:**
```javascript
// Acquire token before test run
export function getAuthToken(env) {
  const loginRes = http.post(`${env.API_URL}/api/auth/login`, JSON.stringify({
    email: env.TEST_USER_EMAIL,
    password: env.TEST_USER_PASSWORD
  }), { headers: { 'Content-Type': 'application/json' } });

  return loginRes.json('token');
}

// Inject auth header into all requests
export function authHeaders(token) {
  return { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' };
}
```

**Azure AD auth:**
- Client credentials flow for service-to-service load testing
- Token caching to avoid auth bottleneck
- Separate test tenant/users for load tests (never use production credentials)
</step>

<step name="generate_thresholds">
Generate performance thresholds per endpoint category:

```json
{
  "defaults": {
    "http_req_duration_p95": 500,
    "http_req_duration_p99": 1000,
    "http_req_failed_rate": 0.01
  },
  "categories": {
    "read_list": { "p95": 300, "p99": 800 },
    "read_single": { "p95": 200, "p99": 500 },
    "write_create": { "p95": 500, "p99": 1500 },
    "write_update": { "p95": 400, "p99": 1200 },
    "delete": { "p95": 300, "p99": 800 },
    "auth": { "p95": 1000, "p99": 2000 },
    "heavy_query": { "p95": 2000, "p99": 5000 },
    "streaming": { "ttfb_p95": 500 }
  },
  "endpoints": {}
}
```

Endpoints can override category defaults. Thresholds are loaded at runtime and used as k6/Artillery pass/fail criteria.
</step>

<step name="generate_ci_pipeline">
Generate CI integration:

**GitHub Actions** (`load-test.yml`):
```yaml
name: Load Tests
on:
  push:
    branches: [main]
  schedule:
    - cron: '0 6 * * 1'  # Weekly Monday 6am UTC
  workflow_dispatch:
    inputs:
      scenario:
        description: 'Test scenario'
        default: 'load'
        type: choice
        options: [smoke, baseline, load, stress]

jobs:
  load-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: grafana/k6-action@v0.3
        with:
          filename: tests/load/k6/scenarios/${{ inputs.scenario || 'smoke' }}.js
        env:
          API_URL: ${{ vars.STAGING_API_URL }}
          TEST_USER_EMAIL: ${{ secrets.LOAD_TEST_USER }}
          TEST_USER_PASSWORD: ${{ secrets.LOAD_TEST_PASSWORD }}
      - uses: actions/upload-artifact@v4
        with:
          name: load-test-results
          path: tests/load/reports/
```

**Azure DevOps** (equivalent YAML pipeline with Azure Load Testing integration).
</step>

<step name="generate_data_generators">
Generate test data generators:

- Random user profiles (name, email, tenant)
- Random conversation messages
- Random search queries
- Parameterized from CSV files for repeatable tests
- Seed data cleanup script (remove load test data after runs)

Important: Load test data must use a dedicated test tenant to avoid polluting real data.
</step>

<step name="generate_tests">
Generate meta-tests (tests for the load tests):

1. **Config validation**: Verify all endpoint URLs resolve, thresholds are reasonable
2. **Auth check**: Verify test credentials work before running full suite
3. **Dry run**: Execute smoke test with 1 VU to validate scripts parse correctly
</step>

<step name="commit_and_report">
Commit all generated files:

```bash
git add tests/load/
git commit -m "feat: scaffold load test suite ({tool}, {endpoint_count} endpoints)"
```

Report:
```
## Load Test Suite Generated

**Tool**: {k6 | Artillery | Both}
**Endpoints**: {count} endpoints across {entity_count} controllers
**Scenarios**: smoke, baseline, load, stress, spike, soak
**CI**: {GitHub Actions | Azure DevOps | None}

### Scenarios
| Scenario | VUs | Duration | Use Case |
|----------|-----|----------|----------|
| smoke | 1 | < 1 min | Pre-deploy sanity |
| baseline | 10 | 1 min | Establish metrics |
| load | 50 | 7 min | Regular CI gate |
| stress | 300 | 10 min | Capacity planning |
| spike | 200 | 3 min | Resilience |
| soak | 30 | 30 min | Endurance |

### Next Steps
1. Set test credentials in .env or CI secrets
2. Run smoke test: npm run load:smoke
3. Run baseline to establish thresholds: npm run load:baseline
4. Review thresholds in config/thresholds.json
5. Add to CI pipeline: copy ci/{platform}.yml to your CI config
6. Schedule weekly load tests via CI
```
</step>

</process>

<success_criteria>
- [ ] Endpoints auto-discovered from OpenAPI spec or controllers
- [ ] All 6 scenario types generated (smoke, baseline, load, stress, spike, soak)
- [ ] Auth helper generated for test user authentication
- [ ] Performance thresholds defined per endpoint category
- [ ] CI pipeline integration generated for selected platform
- [ ] Test data generators created
- [ ] npm scripts for easy local execution
- [ ] README with setup and interpretation guide
</success_criteria>

<failure_handling>
- **No OpenAPI spec found**: Scan controllers for endpoints; generate placeholder tests with TODO markers
- **No controllers found**: Generate template load test structure with example endpoints; user fills in
- **Unknown auth mechanism**: Generate both JWT and Azure AD helpers; user enables the correct one
- **k6 not installed locally**: Provide installation instructions; Docker alternative included in scripts
</failure_handling>

