<purpose>
Generate observability infrastructure: health check endpoints, structured logging configuration, Application Insights or Grafana dashboards, and alerting rules. Connects to existing OpenTelemetry setup and fills the monitoring gap between "we have traces" and "we get alerted when something breaks."

Provides the dashboards, alerts, and runbooks that turn raw telemetry into actionable operational awareness.
</purpose>

<core_principle>
You can't fix what you can't see. Every service gets health checks, every error gets an alert, every SLA gets a dashboard. Monitoring follows the USE method (Utilization, Saturation, Errors) for infrastructure and RED method (Rate, Errors, Duration) for services.
</core_principle>

<required_reading>
Read STATE.md and ROADMAP.md before any operation to load project context.
Read existing OpenTelemetry configuration in Program.cs or startup.
Read existing health check endpoints.
Check for existing monitoring infrastructure (Application Insights, Grafana, Prometheus).
</required_reading>

<process>

<step name="initialize" priority="first">
Determine project context:

1. Check if `.planning/` exists (GSD project) or standalone
2. Check for existing OpenTelemetry configuration
3. Check for existing health check endpoints (`/health`, `/ready`, `/live`)
4. Check for existing Application Insights SDK
5. Check for existing Serilog or logging configuration
6. Detect all services/components that need monitoring
7. Check for existing Prometheus metrics endpoints

Parse arguments:
- `$ARGUMENTS` may contain: `--platform <appinsights|grafana|datadog>`, `--alerts <email|slack|teams|pagerduty>`
</step>

<step name="ask_platform">
```
AskUserQuestion(
  header="Platform",
  question="Which monitoring platform should be configured?",
  options=[
    {
      label: "Application Insights (Recommended)",
      description: "Azure-native APM. Automatic request tracking, dependency mapping, exception logging. Best for Azure-hosted .NET apps. Free tier available."
    },
    {
      label: "Grafana + Prometheus",
      description: "Open-source monitoring stack. Custom dashboards, flexible alerting. Self-hosted or Grafana Cloud. Best for multi-cloud or on-prem."
    },
    {
      label: "Both",
      description: "Application Insights for APM + Grafana for custom dashboards. OpenTelemetry exports to both. Maximum visibility."
    }
  ]
)
```

Store as `MONITORING_PLATFORM`.
</step>

<step name="ask_alerting">
```
AskUserQuestion(
  header="Alerts",
  question="Where should alerts be sent?",
  multiSelect=true,
  options=[
    {
      label: "Email (Recommended)",
      description: "Email alerts to ops team. Best for non-urgent warnings and daily summaries."
    },
    {
      label: "Microsoft Teams",
      description: "Teams channel webhook for real-time alerts. Good for team visibility."
    },
    {
      label: "Slack",
      description: "Slack channel webhook for real-time alerts. Standard DevOps alerting channel."
    },
    {
      label: "PagerDuty",
      description: "PagerDuty integration for on-call rotation. Best for critical production alerts with escalation."
    }
  ]
)
```

Store as `ALERT_CHANNELS[]`.
</step>

<step name="generate_project_structure">
```
src/Server/{ProjectName}/
  HealthChecks/
    DatabaseHealthCheck.cs             # SQL Server connectivity + query test
    ExternalApiHealthCheck.cs          # Upstream API health (if applicable)
    DiskSpaceHealthCheck.cs            # Disk space check
    MemoryHealthCheck.cs               # Memory usage check
    CustomHealthCheck.cs               # Application-specific checks

  Monitoring/
    Metrics/
      AppMetrics.cs                    # Custom application metrics (counters, gauges, histograms)
      MetricsMiddleware.cs             # HTTP request metrics middleware
    Logging/
      LogEnricher.cs                   # Serilog enricher (TenantId, UserId, TraceId)
      SensitiveDataMasker.cs           # PII/PHI masking in logs
      LoggingConfiguration.cs          # Structured logging setup
    Alerts/
      IAlertService.cs                 # Alert sending interface
      TeamsAlertService.cs             # Teams webhook
      SlackAlertService.cs             # Slack webhook
      EmailAlertService.cs             # Email alerts
    Tracing/
      ActivityEnricher.cs              # OpenTelemetry span enrichment

monitoring/
  dashboards/
    appinsights/
      api-overview.json                # API performance overview (KQL queries)
      error-analysis.json              # Error rate and exception analysis
      dependency-map.json              # Service dependency health
      user-analytics.json              # Active users, sessions, tenant activity
    grafana/
      api-overview.json                # Grafana dashboard JSON
      database-performance.json        # SQL Server metrics
      infrastructure.json             # CPU, memory, disk, network
      business-metrics.json            # Custom business KPIs

  alerts/
    rules/
      critical.json                    # Critical alerts (service down, error spike, data breach)
      warning.json                     # Warning alerts (high latency, disk space, memory)
      info.json                        # Informational (deployment complete, scheduled job result)
    templates/
      teams-card.json                  # Teams adaptive card template
      slack-block.json                 # Slack block kit template

  runbooks/
    high-error-rate.md                 # Runbook: error rate > 5%
    high-latency.md                    # Runbook: p95 > 2s
    database-connection-failure.md     # Runbook: DB connection issues
    memory-pressure.md                 # Runbook: memory > 85%
    disk-space-low.md                  # Runbook: disk < 10%
    service-unhealthy.md               # Runbook: health check failing
    certificate-expiring.md            # Runbook: TLS cert expiring

  scripts/
    setup-appinsights.ps1              # Configure Application Insights
    setup-grafana.ps1                  # Configure Grafana dashboards
    test-alerts.ps1                    # Send test alerts to verify channels

tests/
  Monitoring/
    HealthCheckTests.cs
    MetricsTests.cs
    AlertServiceTests.cs
```
</step>

<step name="generate_health_checks">
Generate comprehensive health check endpoints:

**ASP.NET Core Health Checks:**
```csharp
// Program.cs additions
builder.Services.AddHealthChecks()
    .AddCheck<DatabaseHealthCheck>("database", tags: new[] { "ready" })
    .AddCheck<ExternalApiHealthCheck>("upstream-api", tags: new[] { "ready" })
    .AddCheck<DiskSpaceHealthCheck>("disk-space", tags: new[] { "live" })
    .AddCheck<MemoryHealthCheck>("memory", tags: new[] { "live" });

// Endpoints
app.MapHealthChecks("/health", new HealthCheckOptions {
    ResponseWriter = UIResponseWriter.WriteHealthCheckUIResponse
});
app.MapHealthChecks("/health/ready", new HealthCheckOptions {
    Predicate = check => check.Tags.Contains("ready")
});
app.MapHealthChecks("/health/live", new HealthCheckOptions {
    Predicate = check => check.Tags.Contains("live")
});
```

**Three health endpoints:**
- `/health` â€” Full health (all checks)
- `/health/ready` â€” Readiness probe (DB, external APIs) â€” Kubernetes readinessProbe
- `/health/live` â€” Liveness probe (memory, disk) â€” Kubernetes livenessProbe

**Database health check:**
```csharp
public class DatabaseHealthCheck : IHealthCheck
{
    public async Task<HealthCheckResult> CheckHealthAsync(HealthCheckContext context, CancellationToken ct)
    {
        try
        {
            using var conn = _connectionFactory.CreateConnection();
            await conn.OpenAsync(ct);
            var result = await conn.ExecuteScalarAsync<int>("SELECT 1");
            return result == 1
                ? HealthCheckResult.Healthy("Database connection OK")
                : HealthCheckResult.Unhealthy("Database query failed");
        }
        catch (Exception ex)
        {
            return HealthCheckResult.Unhealthy("Database unreachable", ex);
        }
    }
}
```
</step>

<step name="generate_custom_metrics">
Generate custom application metrics:

```csharp
public static class AppMetrics
{
    private static readonly Meter Meter = new("TechnijianApp", "1.0");

    // Counters
    public static readonly Counter<long> ApiRequests = Meter.CreateCounter<long>("api.requests.total");
    public static readonly Counter<long> ApiErrors = Meter.CreateCounter<long>("api.errors.total");
    public static readonly Counter<long> AuthFailures = Meter.CreateCounter<long>("auth.failures.total");

    // Histograms
    public static readonly Histogram<double> RequestDuration = Meter.CreateHistogram<double>("api.request.duration.ms");
    public static readonly Histogram<double> DbQueryDuration = Meter.CreateHistogram<double>("db.query.duration.ms");

    // Gauges
    public static readonly ObservableGauge<int> ActiveConnections = Meter.CreateObservableGauge<int>(
        "api.connections.active", () => /* read from connection pool */);

    // Business metrics
    public static readonly Counter<long> MessagesProcessed = Meter.CreateCounter<long>("business.messages.processed");
    public static readonly Counter<long> CouncilDeliberations = Meter.CreateCounter<long>("business.council.deliberations");
}
```

**Metrics middleware** records per-request:
- Duration (histogram)
- Status code (counter per status)
- Endpoint (tagged by controller/action)
- TenantId (for per-tenant analysis)
</step>

<step name="generate_dashboards">
Generate monitoring dashboards:

**API Overview Dashboard:**
- Request rate (req/sec) over time
- Error rate (%) over time
- p50, p95, p99 latency over time
- Top 10 slowest endpoints
- Top 10 error-producing endpoints
- Active users per tenant
- HTTP status code distribution

**Database Performance Dashboard:**
- SP execution time (p50, p95 per SP)
- Connection pool utilization
- Active queries count
- Deadlock count
- Top 10 slowest stored procedures

**Infrastructure Dashboard:**
- CPU utilization (%)
- Memory usage (MB / %)
- Disk space (GB remaining)
- Network I/O (bytes/sec)
- Container health (if Docker)

**Business Metrics Dashboard:**
- Messages sent per hour
- Active conversations
- Council deliberations per day
- User signups per tenant
- API usage per tenant (for billing)
</step>

<step name="generate_alert_rules">
Generate alerting rules:

**Critical (page immediately):**
| Alert | Condition | Action |
|-------|-----------|--------|
| Service Down | Health check fails 3x consecutive | PagerDuty + Teams |
| Error Spike | Error rate > 10% for 5 min | PagerDuty + Teams |
| Database Down | DB health check fails | PagerDuty + Teams |
| Data Breach Attempt | Cross-tenant access detected | PagerDuty + Email |

**Warning (notify team):**
| Alert | Condition | Action |
|-------|-----------|--------|
| High Latency | p95 > 2s for 10 min | Teams/Slack |
| Memory Pressure | Memory > 85% for 5 min | Teams/Slack |
| Disk Space Low | Disk < 15% | Teams/Slack + Email |
| High Error Rate | Error rate > 5% for 5 min | Teams/Slack |
| Auth Failures | > 50 failures in 5 min | Teams/Slack |

**Info (daily digest):**
| Alert | Condition | Action |
|-------|-----------|--------|
| Deployment Complete | After CD pipeline | Teams/Slack |
| Daily Summary | Scheduled 9am | Email |
| Certificate Expiring | TLS cert < 30 days | Email |
</step>

<step name="generate_runbooks">
Generate operational runbooks for each alert:

Each runbook includes:
1. **What triggered**: Description of the alert condition
2. **Impact**: What users/services are affected
3. **Diagnosis steps**: Specific commands and queries to run
4. **Resolution steps**: How to fix the issue
5. **Escalation**: When and who to escalate to
6. **Prevention**: What to do to prevent recurrence
</step>

<step name="generate_logging_config">
Generate structured logging configuration:

**Serilog setup:**
- Console sink (development)
- File sink with daily rotation (production)
- Application Insights sink (if selected)
- Seq sink (optional, for log aggregation)
- PII masking enricher (strips sensitive data)
- TenantId/UserId/TraceId enrichment
- Request/response logging middleware

**Log levels by namespace:**
```json
{
  "Serilog": {
    "MinimumLevel": {
      "Default": "Information",
      "Override": {
        "Microsoft.AspNetCore": "Warning",
        "Microsoft.EntityFrameworkCore": "Warning",
        "System.Net.Http": "Warning",
        "Technijian": "Information"
      }
    }
  }
}
```
</step>

<step name="commit_and_report">
Commit all generated files:

```bash
git add src/Server/*/HealthChecks/ src/Server/*/Monitoring/ monitoring/ tests/Monitoring/
git commit -m "feat: scaffold monitoring infrastructure ({platform}, {alert_channels})"
```

Report with dashboard screenshots (if applicable), alert rules summary, and setup instructions.
</step>

</process>

<success_criteria>
- [ ] Health check endpoints (/health, /health/ready, /health/live)
- [ ] Custom application metrics (counters, histograms, gauges)
- [ ] Monitoring dashboards (API, DB, infrastructure, business)
- [ ] Alert rules (critical, warning, info)
- [ ] Alert channel integration (Teams, Slack, PagerDuty, email)
- [ ] Operational runbooks for each alert type
- [ ] Structured logging with PII masking
- [ ] OpenTelemetry metric export configured
- [ ] Test suite for health checks and alert services
</success_criteria>

<failure_handling>
- **No OpenTelemetry setup**: Generate full OpenTelemetry configuration from scratch
- **No Application Insights**: Generate with connection string placeholder; provide setup script
- **No Grafana access**: Generate dashboard JSON files; user imports manually
- **No alert channel configured**: Generate with placeholder webhooks; user fills in URLs
</failure_handling>

