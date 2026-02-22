---
name: gsd:gen-webhook
description: Generate webhook infrastructure (outbound/inbound) with retries and dead letter queue
argument-hint: "[--direction <outbound|inbound|both>] [--events <entity.action,...>]"
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
Generate webhook infrastructure for sending and receiving webhooks with reliable delivery.

The user chooses direction:
- **Outbound**: Your app sends webhooks to external systems when events occur. Includes subscription management, HMAC signing, retries, and dead letter queue.
- **Inbound**: Your app receives webhooks from external systems. Includes signature verification, replay protection, and provider-specific handlers.
- **Both**: Full bidirectional webhook system.

Auto-discovers webhook events from your existing controllers and data mutations. Follows SPOnly and API-First patterns.
</objective>

<execution_context>
@C:/Users/rjain/.codex/get-shit-done/workflows/gen-webhook.md
</execution_context>

<context>
Target: $ARGUMENTS (optional flags)

@.planning/STATE.md
@docs/spec/openapi.yaml
</context>

<process>
Execute the gen-webhook workflow from @C:/Users/rjain/.codex/get-shit-done/workflows/gen-webhook.md end-to-end.
Auto-discover events from codebase, ask direction, generate subscription API, delivery pipeline, signature verification, and background worker.
</process>

