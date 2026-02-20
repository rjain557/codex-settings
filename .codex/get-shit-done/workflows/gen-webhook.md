<purpose>
Generate webhook infrastructure for sending and receiving webhooks. Creates webhook registration, delivery pipeline with retries and dead letter queue, signature verification, and tenant-scoped webhook management.

Supports both outbound (your app notifies external systems) and inbound (external systems notify your app) webhook patterns. Follows API-First and SPOnly patterns.
</purpose>

<core_principle>
Reliable delivery with at-least-once semantics. Webhooks are queued, delivered with exponential backoff retries, and moved to a dead letter queue on persistent failure. Every webhook is signed (HMAC-SHA256) for verification. All webhook data is tenant-scoped.
</core_principle>

<required_reading>
Read STATE.md and ROADMAP.md before any operation to load project context.
Read existing API structure for endpoint patterns.
Read database schema for event source tables.
</required_reading>

<process>

<step name="initialize" priority="first">
Determine project context:

1. Check if `.planning/` exists (GSD project) or standalone
2. Check for existing event/notification infrastructure
3. Check for existing background job system (Hangfire, hosted services)
4. Detect entities that would trigger webhook events
5. Check for existing integration endpoints (N8N, Zapier, etc.)

Parse arguments:
- `$ARGUMENTS` may contain: `--direction <outbound|inbound|both>`, `--events <entity.action,...>`
</step>

<step name="ask_direction">
```
AskUserQuestion(
  header="Direction",
  question="What webhook direction should be generated?",
  options=[
    {
      label: "Outbound (Recommended)",
      description: "Your app sends webhooks to external systems when events occur (e.g., new user created, message sent). Subscribers register endpoints."
    },
    {
      label: "Inbound",
      description: "Your app receives webhooks from external systems (e.g., payment provider, CI/CD, calendar sync). Includes signature verification."
    },
    {
      label: "Both",
      description: "Full bidirectional webhook system. Your app both sends and receives webhooks. Most flexible."
    }
  ]
)
```

Store as `DIRECTION`.
</step>

<step name="discover_events">
Auto-discover potential webhook events from the codebase:

Scan controllers and services for data mutations:
- `Create{Entity}` â†’ `{entity}.created`
- `Update{Entity}` â†’ `{entity}.updated`
- `Delete{Entity}` â†’ `{entity}.deleted`
- Custom actions â†’ `{entity}.{action}`

Present discovered events:
```
## Discovered Webhook Events

| Event | Trigger | Payload |
|-------|---------|---------|
| user.created | POST /api/users | UserResponseDto |
| user.updated | PUT /api/users/{id} | UserResponseDto |
| conversation.created | POST /api/conversations | ConversationResponseDto |
| message.sent | POST /api/messages | MessageResponseDto |
| council.completed | POST /api/council/deliberate | DeliberationResultDto |
```
</step>

<step name="generate_project_structure">
```
src/Server/{ProjectName}/
  Services/Webhooks/
    Outbound/
      IWebhookService.cs               # Outbound webhook service interface
      WebhookService.cs                 # Event â†’ webhook dispatch
      WebhookDeliveryService.cs         # HTTP delivery with retries
      WebhookSigner.cs                  # HMAC-SHA256 signature generation
      WebhookRetryPolicy.cs             # Exponential backoff configuration
    Inbound/
      IWebhookReceiver.cs              # Inbound webhook receiver interface
      WebhookReceiver.cs               # Signature verification + routing
      WebhookVerifier.cs               # HMAC-SHA256 signature verification
      Handlers/
        I{Provider}WebhookHandler.cs   # Per-provider handler interface
        {Provider}WebhookHandler.cs    # Provider-specific handler
    Models/
      WebhookSubscription.cs           # Subscriber registration
      WebhookEvent.cs                  # Event definition
      WebhookDelivery.cs               # Delivery attempt record
      WebhookPayload.cs                # Standardized payload envelope

  Repositories/
    IWebhookRepository.cs              # Webhook data access
    WebhookRepository.cs               # Dapper + SP implementation

  Controllers/
    WebhooksController.cs              # Webhook management API
    WebhookReceiverController.cs       # Inbound webhook endpoint

  Models/Dtos/
    WebhookDtos.cs                     # Request/response DTOs

  BackgroundServices/
    WebhookDeliveryWorker.cs           # Background delivery processor
    WebhookCleanupWorker.cs            # Clean old delivery logs

db/sql/
  tables/
    WebhookSubscriptions.sql           # Subscriber registrations
    WebhookEvents.sql                  # Event type definitions
    WebhookDeliveryLog.sql             # Delivery attempts (success/fail)
    WebhookDeadLetterQueue.sql         # Failed deliveries for manual retry
  procedures/
    usp_WebhookSubscription_Create.sql
    usp_WebhookSubscription_List.sql
    usp_WebhookSubscription_Delete.sql
    usp_WebhookSubscription_GetByEvent.sql
    usp_WebhookDelivery_Log.sql
    usp_WebhookDelivery_GetPending.sql
    usp_WebhookDLQ_Insert.sql
    usp_WebhookDLQ_List.sql
    usp_WebhookDLQ_Retry.sql

tests/
  Webhooks/
    WebhookServiceTests.cs
    WebhookDeliveryTests.cs
    WebhookSignerTests.cs
    WebhookReceiverTests.cs
```
</step>

<step name="generate_outbound_system">
Generate outbound webhook system:

**Subscription API:**
```
POST   /api/webhooks/subscriptions          # Register new subscription
GET    /api/webhooks/subscriptions          # List subscriptions
DELETE /api/webhooks/subscriptions/{id}     # Remove subscription
GET    /api/webhooks/events                 # List available event types
POST   /api/webhooks/subscriptions/{id}/test # Send test event
GET    /api/webhooks/deliveries             # View delivery log
POST   /api/webhooks/dlq/{id}/retry        # Retry failed delivery
```

**Payload envelope:**
```json
{
  "id": "evt_abc123",
  "type": "user.created",
  "timestamp": "2026-02-11T00:00:00Z",
  "tenantId": "tenant-001",
  "data": { /* entity DTO */ },
  "signature": "sha256=abc123..."
}
```

**Delivery pipeline:**
1. Event occurs â†’ create WebhookDelivery record
2. Background worker picks up pending deliveries
3. POST payload to subscriber URL with signature header
4. On success (2xx) â†’ mark delivered
5. On failure â†’ retry with exponential backoff (1min, 5min, 30min, 2hr, 12hr)
6. After max retries â†’ move to dead letter queue
7. DLQ entries can be manually retried via API

**Signature:**
```csharp
var signature = HMACSHA256(webhookSecret, JsonSerialize(payload));
request.Headers.Add("X-Webhook-Signature", $"sha256={signature}");
request.Headers.Add("X-Webhook-Timestamp", timestamp);
```
</step>

<step name="generate_inbound_system">
If inbound is selected:

**Receiver endpoint:**
```
POST /api/webhooks/receive/{provider}    # Receive webhook from provider
```

**Verification:**
- Verify HMAC signature from request header
- Verify timestamp is within 5 minutes (prevent replay attacks)
- Parse payload and route to provider-specific handler
- Return 200 immediately, process async

**Provider handlers:**
- Each external provider gets its own handler class
- Handles provider-specific payload format
- Maps to internal domain events
</step>

<step name="commit_and_report">
Commit all generated files and report summary.
</step>

</process>

<success_criteria>
- [ ] Webhook subscription management API
- [ ] Event auto-discovery from codebase
- [ ] HMAC-SHA256 signature generation and verification
- [ ] Delivery pipeline with exponential backoff retries
- [ ] Dead letter queue for failed deliveries
- [ ] Background worker for async delivery
- [ ] Database tables and SPs (SPOnly, TenantId isolated)
- [ ] Inbound webhook receiver with signature verification (if selected)
- [ ] Test suite for delivery, signing, and verification
</success_criteria>

<failure_handling>
- **No background job infrastructure**: Generate IHostedService-based worker
- **No entities found**: Generate example events; user fills in real ones
- **No existing event system**: Create standalone webhook events (not dependent on notification system)
</failure_handling>

