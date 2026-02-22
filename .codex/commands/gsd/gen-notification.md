---
name: gsd:gen-notification
description: Generate multi-channel notification system (in-app, email, push, SMS)
argument-hint: "[--channels <in-app|email|push|sms>] [--provider <sendgrid|smtp|ses>]"
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
Generate a multi-channel notification system with in-app notifications, email delivery, mobile push notifications, and SMS alerts.

The user chooses channels:
- **In-app**: Bell icon notifications with real-time SSE delivery and read/unread tracking
- **Email**: Transactional emails via SendGrid, SES, or SMTP with HTML templates
- **Push**: Mobile push via FCM/APNS (requires mobile app)
- **SMS**: Text messages via Twilio or AWS SNS

Includes notification preferences (per user, per type, per channel), delivery tracking, and tenant-scoped management. Follows SPOnly and API-First patterns.
</objective>

<execution_context>
@C:/Users/rjain/.codex/get-shit-done/workflows/gen-notification.md
</execution_context>

<context>
Target: $ARGUMENTS (optional flags)

@.planning/STATE.md
@docs/spec/openapi.yaml
</context>

<process>
Execute the gen-notification workflow from @C:/Users/rjain/.codex/get-shit-done/workflows/gen-notification.md end-to-end.
Ask channel and provider selections. Generate full-stack notification system: database tables/SPs, service layer, controller, email templates, and frontend notification bell component.
</process>

