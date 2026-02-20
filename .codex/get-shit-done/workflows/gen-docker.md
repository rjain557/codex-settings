<purpose>
Generate Docker infrastructure for your project. Creates multi-stage Dockerfiles, docker-compose for local development, and container orchestration configuration. Tailored to the Technijian stack: ASP.NET Core 8 API + React/Vite SPA + SQL Server.

Provides consistent development environments, production-ready container images, and local development setup that matches production topology.
</purpose>

<core_principle>
Development mirrors production. The same Dockerfile builds locally and in CI. docker-compose provides the full stack (API + SPA + DB + dependencies) with one command. Images are small, secure, and follow container best practices (non-root user, health checks, minimal layers).
</core_principle>

<required_reading>
Read STATE.md and ROADMAP.md before any operation to load project context.
Scan project structure to detect all components that need containerization.
Check for existing Docker files or container config.
</required_reading>

<process>

<step name="initialize" priority="first">
Determine project context:

1. Check if `.planning/` exists (GSD project) or standalone
2. Detect components to containerize:
   - ASP.NET Core API (`src/Server/` â€” detect .csproj, target framework)
   - React SPA (`src/Client/` â€” detect package.json, build tool: Vite/CRA/Next)
   - SQL Server database (detect connection strings, db/sql/ scripts)
   - MCP servers, agents, extensions (additional containers)
3. Check for existing Docker files
4. Check for existing nginx/reverse proxy config
5. Detect port configurations from launchSettings.json or config

Parse arguments:
- `$ARGUMENTS` may contain: `--components <api|spa|db|all>`, `--registry <acr|dockerhub|ghcr>`
</step>

<step name="ask_orchestration">
```
AskUserQuestion(
  header="Orchestration",
  question="What container orchestration should be configured?",
  options=[
    {
      label: "docker-compose (Recommended)",
      description: "Simple multi-container setup. Best for local dev and small deployments. One command to start everything."
    },
    {
      label: "docker-compose + Kubernetes",
      description: "docker-compose for local dev, plus Kubernetes manifests for production. Helm charts for configurable deploys."
    },
    {
      label: "Docker only (no orchestration)",
      description: "Dockerfiles only, no compose or K8s. User handles container networking and orchestration."
    }
  ]
)
```

Store as `ORCHESTRATION`.
</step>

<step name="generate_project_structure">
```
docker/
  api/
    Dockerfile                         # Multi-stage .NET 8 build
    .dockerignore                      # Exclude bin/, obj/, .git
  spa/
    Dockerfile                         # Multi-stage Node + nginx build
    nginx.conf                         # nginx config for SPA routing
    .dockerignore                      # Exclude node_modules/, dist/
  db/
    Dockerfile                         # SQL Server with init scripts
    init/
      01-create-database.sql           # Auto-run on first start
      02-run-migrations.sql            # Apply latest migrations
      03-seed-data.sql                 # Seed data for dev
    healthcheck.sh                     # DB health check script

docker-compose.yml                     # Full stack for local dev
docker-compose.override.yml            # Dev-specific overrides (volumes, ports, debug)
docker-compose.prod.yml                # Production overrides (no volumes, resource limits)
.dockerignore                          # Root-level ignore

k8s/                                   # Only if Kubernetes selected
  namespace.yml
  api/
    deployment.yml
    service.yml
    ingress.yml
    hpa.yml                            # Horizontal Pod Autoscaler
  spa/
    deployment.yml
    service.yml
    ingress.yml
  db/
    statefulset.yml
    service.yml
    pvc.yml                            # Persistent Volume Claim
  config/
    configmap.yml
    secrets.yml                        # Template (values from CI)
  helm/                                # Helm chart (if K8s)
    Chart.yaml
    values.yaml
    values.staging.yaml
    values.production.yaml
    templates/
```
</step>

<step name="generate_api_dockerfile">
Generate multi-stage Dockerfile for ASP.NET Core API:

```dockerfile
# Stage 1: Build
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy csproj and restore (cached layer)
COPY ["src/Server/{ProjectName}/{ProjectName}.csproj", "src/Server/{ProjectName}/"]
RUN dotnet restore "src/Server/{ProjectName}/{ProjectName}.csproj"

# Copy everything and build
COPY . .
WORKDIR "/src/src/Server/{ProjectName}"
RUN dotnet publish -c Release -o /app/publish /p:UseAppHost=false

# Stage 2: Runtime
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app

# Security: run as non-root
RUN groupadd -r appuser && useradd -r -g appuser appuser
USER appuser

COPY --from=build /app/publish .

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080
ENV ASPNETCORE_ENVIRONMENT=Production

ENTRYPOINT ["dotnet", "{ProjectName}.dll"]
```

Key features:
- Multi-stage build (SDK for build, runtime-only for deploy)
- NuGet restore cached separately (fast rebuilds)
- Non-root user for security
- Health check endpoint
- Small image size (~220MB vs ~1.5GB with SDK)
</step>

<step name="generate_spa_dockerfile">
Generate multi-stage Dockerfile for React SPA:

```dockerfile
# Stage 1: Build
FROM node:20-alpine AS build
WORKDIR /app

# Copy package files and install (cached layer)
COPY src/Client/{spa-name}/package*.json ./
RUN npm ci --prefer-offline

# Copy source and build
COPY src/Client/{spa-name}/ .
RUN npm run build

# Stage 2: Serve with nginx
FROM nginx:alpine AS runtime

# Security: remove default config
RUN rm /etc/nginx/conf.d/default.conf

# Copy custom nginx config
COPY docker/spa/nginx.conf /etc/nginx/conf.d/

# Copy built SPA
COPY --from=build /app/dist /usr/share/nginx/html

# Health check
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD wget -qO- http://localhost:80/health || exit 1

EXPOSE 80
```

**nginx.conf** for SPA routing:
```nginx
server {
    listen 80;
    root /usr/share/nginx/html;
    index index.html;

    # SPA routing: all routes â†’ index.html
    location / {
        try_files $uri $uri/ /index.html;
    }

    # API proxy (if same-origin needed)
    location /api/ {
        proxy_pass http://api:8080/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # SSE proxy (long-lived connections)
    location /api/stream/ {
        proxy_pass http://api:8080/api/stream/;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_buffering off;
        proxy_cache off;
        proxy_read_timeout 86400s;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 'ok';
        add_header Content-Type text/plain;
    }

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
}
```
</step>

<step name="generate_db_container">
Generate SQL Server dev container:

```dockerfile
FROM mcr.microsoft.com/mssql/server:2022-latest

# Accept EULA
ENV ACCEPT_EULA=Y
ENV MSSQL_SA_PASSWORD=DevPassword123!
ENV MSSQL_PID=Developer

# Copy init scripts
COPY docker/db/init/ /docker-entrypoint-initdb.d/

# Copy health check
COPY docker/db/healthcheck.sh /healthcheck.sh
RUN chmod +x /healthcheck.sh

HEALTHCHECK --interval=15s --timeout=5s --start-period=30s --retries=5 \
  CMD /healthcheck.sh

EXPOSE 1433
```

Init scripts run in order on first container start:
- `01-create-database.sql`: Create database if not exists
- `02-run-migrations.sql`: Apply all migrations
- `03-seed-data.sql`: Insert seed data (idempotent)
</step>

<step name="generate_docker_compose">
Generate docker-compose.yml:

```yaml
services:
  api:
    build:
      context: .
      dockerfile: docker/api/Dockerfile
    ports:
      - "5000:8080"
    environment:
      - ASPNETCORE_ENVIRONMENT=Development
      - ConnectionStrings__DefaultConnection=Server=db;Database={DbName};User Id=sa;Password=DevPassword123!;TrustServerCertificate=True
      - AzureAd__TenantId=${AZURE_AD_TENANT_ID}
      - AzureAd__ClientId=${AZURE_AD_CLIENT_ID}
    depends_on:
      db:
        condition: service_healthy
    networks:
      - app-network

  spa:
    build:
      context: .
      dockerfile: docker/spa/Dockerfile
    ports:
      - "3000:80"
    depends_on:
      - api
    networks:
      - app-network

  db:
    build:
      context: .
      dockerfile: docker/db/Dockerfile
    ports:
      - "1433:1433"
    volumes:
      - db-data:/var/opt/mssql
    networks:
      - app-network

volumes:
  db-data:

networks:
  app-network:
    driver: bridge
```

**Override for development** (docker-compose.override.yml):
- Volume mounts for hot reload
- Debug ports exposed
- Verbose logging
- No resource limits

**Override for production** (docker-compose.prod.yml):
- No volume mounts
- Resource limits (CPU, memory)
- Restart policies
- Log rotation
</step>

<step name="commit_and_report">
Commit all generated files:

```bash
git add docker/ docker-compose*.yml .dockerignore k8s/
git commit -m "feat: scaffold Docker infrastructure ({components})"
```

Report:
```
## Docker Infrastructure Generated

**Components**: {API, SPA, Database}
**Orchestration**: {docker-compose | docker-compose + K8s | Docker only}

### Containers
| Container | Base Image | Port | Health Check |
|-----------|-----------|------|-------------|
| api | .NET 8 aspnet | 8080 | /health |
| spa | nginx:alpine | 80 | /health |
| db | SQL Server 2022 | 1433 | sqlcmd |

### Commands
- Start all: docker-compose up -d
- Stop all: docker-compose down
- Rebuild: docker-compose up -d --build
- Logs: docker-compose logs -f api
- DB shell: docker-compose exec db /opt/mssql-tools/bin/sqlcmd -S localhost -U sa

### Next Steps
1. Copy .env.example to .env and fill in values
2. Start: docker-compose up -d
3. Wait for DB health check to pass (~30s)
4. Access SPA: http://localhost:3000
5. Access API: http://localhost:5000
6. Access DB: localhost:1433 (sa / DevPassword123!)
```
</step>

</process>

<success_criteria>
- [ ] Multi-stage Dockerfiles for API and SPA (small, secure images)
- [ ] SQL Server dev container with auto-initialization
- [ ] docker-compose for one-command local development
- [ ] nginx config for SPA routing and API proxy
- [ ] Health checks on all containers
- [ ] Non-root users in containers
- [ ] Dev/prod compose overrides
- [ ] .dockerignore files for fast builds
</success_criteria>

<failure_handling>
- **No .csproj found**: Ask user for project structure; generate generic .NET 8 Dockerfile
- **No SPA found**: Skip SPA container; generate API + DB only
- **SQL Server not needed**: Skip DB container; configure external DB connection
- **Windows containers requested**: Warn about limited support; default to Linux containers
</failure_handling>

