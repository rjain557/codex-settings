<purpose>
Generate a complete CI/CD pipeline for your project. Supports GitHub Actions and Azure DevOps Pipelines. Creates build, test, deploy stages with environment promotion (dev â†’ staging â†’ production). Tailored to the Technijian stack: ASP.NET Core 8 API + React/Vite SPA + SQL Server migrations.

Fills the critical infrastructure gap -- most Technijian projects have no CI/CD automation and rely on manual deployments.
</purpose>

<core_principle>
Every commit gets built and tested. Every merge to main gets deployed to staging. Production deploys require manual approval. Database migrations run before app deployment. Rollback is always possible.
</core_principle>

<required_reading>
Read STATE.md and ROADMAP.md before any operation to load project context.
Read project structure to detect components (API, SPA, database, agents, extensions).
Check for existing CI config (.github/workflows/, azure-pipelines.yml).
</required_reading>

<process>

<step name="initialize" priority="first">
Determine project context:

1. Check if `.planning/` exists (GSD project) or standalone
2. Detect project components:
   - ASP.NET Core API (`src/Server/` or `*.csproj`)
   - React SPA (`src/Client/` or `package.json` with React)
   - SQL Server database (`db/sql/` or `db/migrations/`)
   - MCP servers (`src/mcp-servers/`)
   - Browser extensions (`src/extensions/`)
   - Mobile apps (`src/mobile/`)
   - Remote agents (`src/agents/`)
3. Check for existing CI config
4. Check for Dockerfile (affects deployment strategy)
5. Detect test infrastructure (xUnit, Jest, Vitest, Playwright)

Parse arguments:
- `$ARGUMENTS` may contain: `--platform <github|azure>`, `--deploy-target <azure-app-service|docker|aws|vercel>`
</step>

<step name="ask_platform">
```
AskUserQuestion(
  header="CI platform",
  question="Which CI/CD platform should the pipeline use?",
  options=[
    {
      label: "GitHub Actions (Recommended)",
      description: "YAML workflows in .github/workflows/. Free for public repos, 2000 min/month for private. Best GitHub integration."
    },
    {
      label: "Azure DevOps Pipelines",
      description: "YAML pipelines in azure-pipelines.yml. Native Azure integration. Better for enterprises with Azure subscriptions."
    },
    {
      label: "Both",
      description: "Generate pipelines for both platforms. Useful for migration or redundancy."
    }
  ]
)
```

Store as `CI_PLATFORM`.
</step>

<step name="ask_deploy_target">
```
AskUserQuestion(
  header="Deploy target",
  question="Where should the application be deployed?",
  options=[
    {
      label: "Azure App Service (Recommended)",
      description: "Managed hosting for .NET and Node.js. Supports deployment slots for zero-downtime. Best for Technijian .NET stack."
    },
    {
      label: "Docker / Container",
      description: "Build and push Docker images. Deploy to Azure Container Apps, AWS ECS, or any container host."
    },
    {
      label: "Self-hosted / VM",
      description: "Deploy to IIS or Linux VMs via SSH/WinRM. Traditional deployment for on-premises or VPS."
    },
    {
      label: "Build only (no deploy)",
      description: "Only build and test. No deployment automation. Useful as a starting point."
    }
  ]
)
```

Store as `DEPLOY_TARGET`.
</step>

<step name="generate_project_structure">
```
.github/workflows/                     # If GitHub Actions
  ci.yml                               # Main CI pipeline (build + test on every PR)
  cd-staging.yml                       # Deploy to staging on merge to main
  cd-production.yml                    # Deploy to production (manual trigger + approval)
  db-migrate.yml                       # Database migration pipeline
  load-test.yml                        # Scheduled load tests (if gen-load-test exists)
  dependency-audit.yml                 # Weekly dependency vulnerability scan
  codeql.yml                           # CodeQL security analysis

# OR

azure-pipelines.yml                    # If Azure DevOps (single multi-stage file)
azure-pipelines/
  templates/
    build-api.yml                      # API build template
    build-spa.yml                      # SPA build template
    test.yml                           # Test template
    deploy.yml                        # Deploy template
    db-migrate.yml                    # DB migration template

# Common to both:
.env.example                           # Environment variables template
scripts/
  ci/
    setup-db.ps1                       # CI database setup (LocalDB or Docker SQL Server)
    run-migrations.ps1                 # Run database migrations in CI
    health-check.ps1                   # Post-deploy health check
    smoke-test.ps1                     # Post-deploy smoke test
```
</step>

<step name="generate_ci_pipeline">
Generate the main CI pipeline (runs on every PR):

**Stages:**
1. **Build API**: `dotnet restore` â†’ `dotnet build` â†’ `dotnet publish`
2. **Build SPA**: `npm ci` â†’ `npm run build` â†’ `npm run lint`
3. **Unit Tests**: `dotnet test` (xUnit) + `npm test` (Vitest/Jest)
4. **Integration Tests**: Spin up SQL Server (Docker or LocalDB) â†’ run migrations â†’ run integration tests
5. **Security Scan**: CodeQL analysis, dependency audit (`dotnet list package --vulnerable`, `npm audit`)
6. **Artifact Upload**: Publish build artifacts for deployment

**Key features:**
- Parallel jobs where possible (API build || SPA build)
- Caching: NuGet packages, npm modules, build outputs
- Matrix testing (if multiple .NET versions or Node versions)
- PR comment with test results summary
- Branch protection rules recommendation
</step>

<step name="generate_cd_pipeline">
Generate deployment pipelines:

**Staging (automatic on merge to main):**
1. Download build artifacts from CI
2. Run database migrations (forward only, with backup)
3. Deploy API to staging slot
4. Deploy SPA to staging CDN/slot
5. Run smoke tests against staging
6. Swap staging â†’ production slot (if blue/green)

**Production (manual trigger with approval):**
1. Require approval from designated reviewers
2. Create database backup
3. Run database migrations
4. Deploy API with zero-downtime (deployment slots or rolling update)
5. Deploy SPA
6. Run smoke tests
7. Monitor error rates for 5 minutes
8. Auto-rollback if error rate > threshold

**Rollback:**
- One-click rollback to previous version
- Database rollback script reference
- Deployment slot swap (instant for Azure App Service)
</step>

<step name="generate_db_migration_pipeline">
Generate database migration CI step:

- Run migrations from `db/migrations/` in version order
- Validate migrations pass syntax check before execution
- Create backup before migration
- Run in transaction (rollback on failure)
- Verify SP-Only compliance (no EF migrations)
- Connection string from CI secrets (never in code)
</step>

<step name="generate_environment_config">
Generate environment configuration:

**Secrets to configure:**
```
# Database
DB_CONNECTION_STRING_DEV
DB_CONNECTION_STRING_STAGING
DB_CONNECTION_STRING_PROD

# Azure AD
AZURE_AD_TENANT_ID
AZURE_AD_CLIENT_ID
AZURE_AD_CLIENT_SECRET

# API
API_URL_STAGING
API_URL_PROD

# Deploy
AZURE_CREDENTIALS (service principal JSON)
AZURE_APP_SERVICE_NAME_STAGING
AZURE_APP_SERVICE_NAME_PROD
```

Generate `.env.example` with all required variables (no values).
</step>

<step name="commit_and_report">
Commit all generated files:

```bash
git add .github/ scripts/ci/ .env.example
git commit -m "feat: scaffold CI/CD pipeline ({platform}, {deploy_target})"
```

Report:
```
## CI/CD Pipeline Generated

**Platform**: {GitHub Actions | Azure DevOps}
**Deploy Target**: {Azure App Service | Docker | VM | None}
**Components**: {API, SPA, Database, ...}

### Pipelines
| Pipeline | Trigger | Purpose |
|----------|---------|---------|
| ci.yml | Every PR | Build + Test + Security scan |
| cd-staging.yml | Merge to main | Auto-deploy to staging |
| cd-production.yml | Manual | Deploy to production (with approval) |
| db-migrate.yml | Manual | Run database migrations |

### Next Steps
1. Configure secrets in GitHub/Azure (see .env.example)
2. Create Azure service principal: az ad sp create-for-rbac
3. Enable branch protection on main
4. Run first CI build to verify
5. Configure staging environment URL
6. Set up deployment slots in Azure App Service
```
</step>

</process>

<success_criteria>
- [ ] CI pipeline generated (build + test on every PR)
- [ ] CD pipeline generated (staging auto-deploy, production manual)
- [ ] Database migration step included
- [ ] Security scanning included (CodeQL, dependency audit)
- [ ] Environment configuration documented
- [ ] Caching configured for fast builds
- [ ] Rollback procedure documented
- [ ] Smoke test scripts generated
</success_criteria>

<failure_handling>
- **No test infrastructure found**: Generate CI without test stage; warn user to add tests
- **No database migrations**: Skip DB migration step; reference gen-db-migration skill
- **Unknown deploy target**: Generate build-only pipeline; user adds deploy steps later
- **Multiple components detected**: Generate parallel build jobs for each component
</failure_handling>

