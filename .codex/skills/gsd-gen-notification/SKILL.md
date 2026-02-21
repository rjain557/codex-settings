---
name: gsd-gen-notification
description: Generate multi-channel notification system (in-app, email, push, SMS) Use when the user asks for 'gsd:gen-notification', 'gsd-gen-notification', or equivalent trigger phrases.
---

# Purpose
Generate a multi-channel notification system with in-app notifications, email delivery, mobile push notifications, and SMS alerts.

The user chooses channels:
- **In-app**: Bell icon notifications with real-time SSE delivery and read/unread tracking
- **Email**: Transactional emails via SendGrid, SES, or SMTP with HTML templates
- **Push**: Mobile push via FCM/APNS (requires mobile app)
- **SMS**: Text messages via Twilio or AWS SNS

Includes notification preferences (per user, per type, per channel), delivery tracking, and tenant-scoped management. Follows SPOnly and API-First patterns.

# When to use
Use when the user requests the original gsd:gen-notification flow (for example: $gsd-gen-notification).
Also use on natural-language requests that match this behavior: Generate multi-channel notification system (in-app, email, push, SMS)

# Inputs
The user's text after invoking $gsd-gen-notification is the arguments. Parse it into required fields; if any required field is missing, ask targeted follow-up questions.
Expected argument shape from source: [--channels <in-app|email|push|sms>] [--provider <sendgrid|smtp|ses>].
Context from source:
```text
Target: <parsed-arguments> (optional flags)

@.planning/STATE.md
@docs/spec/openapi.yaml
```

# Workflow
Load and follow these referenced artifacts first:
- @C:/Users/rjain/.claude/get-shit-done/workflows/gen-notification.md
Then execute this process:
```text
Execute the gen-notification workflow from @C:/Users/rjain/.claude/get-shit-done/workflows/gen-notification.md end-to-end.
Ask channel and provider selections. Generate full-stack notification system: database tables/SPs, service layer, controller, email templates, and frontend notification bell component.
```

# Outputs / artifacts
Produce the artifacts specified by the workflow and summarize created/updated files.

# Guardrails (what not to do / how to ask for missing info)
- Do not invent missing project files, phase numbers, or state; inspect the repo first.
- Do not skip validation or checkpoint gates described in referenced workflows.
- If required context is missing, ask focused questions (one small batch) and proceed after answers.

# Source (path to original Claude command file)
- C:\Users\rjain\.claude\commands\gsd\gen-notification.md
