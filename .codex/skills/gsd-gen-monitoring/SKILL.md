---
name: gsd-gen-monitoring
description: Generate monitoring infrastructure (health checks, dashboards, alerts, runbooks) Use when the user asks for 'gsd:gen-monitoring', 'gsd-gen-monitoring', or equivalent trigger phrases.
---

# Purpose
Generate observability infrastructure that turns raw telemetry into actionable operational awareness.

The user chooses:
- **Monitoring platform**: Application Insights (Azure-native), Grafana + Prometheus (open-source), or both
- **Alert channels**: Email, Microsoft Teams, Slack, PagerDuty

Generates health check endpoints, custom application metrics, monitoring dashboards, alerting rules, and operational runbooks. Connects to existing OpenTelemetry setup.

# When to use
Use when the user requests the original gsd:gen-monitoring flow (for example: $gsd-gen-monitoring).
Also use on natural-language requests that match this behavior: Generate monitoring infrastructure (health checks, dashboards, alerts, runbooks)

# Inputs
The user's text after invoking $gsd-gen-monitoring is the arguments. Parse it into required fields; if any required field is missing, ask targeted follow-up questions.
Expected argument shape from source: [--platform <appinsights|grafana|datadog>] [--alerts <email|slack|teams|pagerduty>].
Context from source:
```text
Target: <parsed-arguments> (optional flags)

@.planning/STATE.md
```

# Workflow
Load and follow these referenced artifacts first:
- @C:/Users/rjain/.claude/get-shit-done/workflows/gen-monitoring.md
Then execute this process:
```text
Execute the gen-monitoring workflow from @C:/Users/rjain/.claude/get-shit-done/workflows/gen-monitoring.md end-to-end.
Detect existing OpenTelemetry config, ask platform and alert channels, generate health checks, metrics, dashboards, alert rules, and runbooks.
```

# Outputs / artifacts
Produce the artifacts specified by the workflow and summarize created/updated files.

# Guardrails (what not to do / how to ask for missing info)
- Do not invent missing project files, phase numbers, or state; inspect the repo first.
- Do not skip validation or checkpoint gates described in referenced workflows.
- If required context is missing, ask focused questions (one small batch) and proceed after answers.

# Source (path to original Claude command file)
- C:\Users\rjain\.claude\commands\gsd\gen-monitoring.md
