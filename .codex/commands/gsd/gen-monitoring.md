---
name: gsd:gen-monitoring
description: Generate monitoring infrastructure (health checks, dashboards, alerts, runbooks)
argument-hint: "[--platform <appinsights|grafana|datadog>] [--alerts <email|slack|teams|pagerduty>]"
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
Generate observability infrastructure that turns raw telemetry into actionable operational awareness.

The user chooses:
- **Monitoring platform**: Application Insights (Azure-native), Grafana + Prometheus (open-source), or both
- **Alert channels**: Email, Microsoft Teams, Slack, PagerDuty

Generates health check endpoints, custom application metrics, monitoring dashboards, alerting rules, and operational runbooks. Connects to existing OpenTelemetry setup.
</objective>

<execution_context>
@C:/Users/rjain/.codex/get-shit-done/workflows/gen-monitoring.md
</execution_context>

<context>
Target: $ARGUMENTS (optional flags)

@.planning/STATE.md
</context>

<process>
Execute the gen-monitoring workflow from @C:/Users/rjain/.codex/get-shit-done/workflows/gen-monitoring.md end-to-end.
Detect existing OpenTelemetry config, ask platform and alert channels, generate health checks, metrics, dashboards, alert rules, and runbooks.
</process>

