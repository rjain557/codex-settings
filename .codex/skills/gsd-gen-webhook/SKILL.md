---
name: gsd-gen-webhook
description: Generate webhook infrastructure (outbound/inbound) with retries and dead letter queue Use when the user asks for 'gsd:gen-webhook', 'gsd-gen-webhook', or equivalent trigger phrases.
---

# Purpose
Generate webhook infrastructure for sending and receiving webhooks with reliable delivery.

The user chooses direction:
- **Outbound**: Your app sends webhooks to external systems when events occur. Includes subscription management, HMAC signing, retries, and dead letter queue.
- **Inbound**: Your app receives webhooks from external systems. Includes signature verification, replay protection, and provider-specific handlers.
- **Both**: Full bidirectional webhook system.

Auto-discovers webhook events from your existing controllers and data mutations. Follows SPOnly and API-First patterns.

# When to use
Use when the user requests the original gsd:gen-webhook flow (for example: $gsd-gen-webhook).
Also use on natural-language requests that match this behavior: Generate webhook infrastructure (outbound/inbound) with retries and dead letter queue

# Inputs
The user's text after invoking $gsd-gen-webhook is the arguments. Parse it into required fields; if any required field is missing, ask targeted follow-up questions.
Expected argument shape from source: [--direction <outbound|inbound|both>] [--events <entity.action,...>].
Context from source:
```text
Target: <parsed-arguments> (optional flags)

@.planning/STATE.md
@docs/spec/openapi.yaml
```

# Workflow
Load and follow these referenced artifacts first:
- @C:/Users/rjain/.claude/get-shit-done/workflows/gen-webhook.md
Then execute this process:
```text
Execute the gen-webhook workflow from @C:/Users/rjain/.claude/get-shit-done/workflows/gen-webhook.md end-to-end.
Auto-discover events from codebase, ask direction, generate subscription API, delivery pipeline, signature verification, and background worker.
```

# Outputs / artifacts
Produce the artifacts specified by the workflow and summarize created/updated files.

# Guardrails (what not to do / how to ask for missing info)
- Do not invent missing project files, phase numbers, or state; inspect the repo first.
- Do not skip validation or checkpoint gates described in referenced workflows.
- If required context is missing, ask focused questions (one small batch) and proceed after answers.

# Source (path to original Claude command file)
- C:\Users\rjain\.claude\commands\gsd\gen-webhook.md
