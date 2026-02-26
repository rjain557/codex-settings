<purpose>
Generate a multi-channel notification system that supports in-app notifications, email (SendGrid/SMTP), push notifications (mobile), and SMS. Includes notification preferences, templates, delivery tracking, and tenant-scoped notification management.

Follows API-First and SPOnly patterns. Notification state is stored in the database via stored procedures. Email/SMS delivery uses external providers via API calls.
</purpose>

<core_principle>
One notification, multiple channels. A single notification event (e.g., "new message") can trigger in-app, email, push, and SMS delivery based on user preferences. Each channel has its own delivery pipeline, but they share the same notification model and tenant isolation.
</core_principle>

<required_reading>
Read STATE.md and ROADMAP.md before any operation to load project context.
Read existing database schema for user/tenant tables.
Read OpenAPI spec for existing API patterns.
</required_reading>

<process>

<step name="initialize" priority="first">
Determine project context:

1. Check if `.planning/` exists (GSD project) or standalone
2. Check for existing notification infrastructure
3. Check for existing email configuration
4. Check for mobile app (for push notification support)
5. Detect user/tenant table structure for preferences storage

Parse arguments:
- `$ARGUMENTS` may contain: `--channels <in-app|email|push|sms>`, `--provider <sendgrid|smtp|ses>`
</step>

<step name="ask_channels">
```
AskUserQuestion(
  header="Channels",
  question="Which notification channels should be supported?",
  multiSelect=true,
  options=[
    {
      label: "In-app (Recommended)",
      description: "Bell icon notifications within the web/mobile app. Real-time via SSE/WebSocket. Stored in database with read/unread status."
    },
    {
      label: "Email",
      description: "Transactional emails via SendGrid, SES, or SMTP. HTML templates with Razor/Handlebars. Delivery tracking."
    },
    {
      label: "Push (mobile)",
      description: "Mobile push notifications via Firebase Cloud Messaging (FCM) and Apple Push Notification Service (APNS). Requires mobile app."
    },
    {
      label: "SMS",
      description: "Text messages via Twilio or AWS SNS. For urgent alerts and 2FA. Pay-per-message cost."
    }
  ]
)
```

Store as `CHANNELS[]`.
</step>

<step name="ask_email_provider">
If email is in CHANNELS[]:

```
AskUserQuestion(
  header="Email provider",
  question="Which email delivery provider should be used?",
  options=[
    {
      label: "SendGrid (Recommended)",
      description: "Scalable email API by Twilio. 100 free emails/day. Good deliverability. Dynamic templates support."
    },
    {
      label: "SMTP (Generic)",
      description: "Standard SMTP relay. Works with any email server (Office 365, Gmail, custom). No vendor lock-in."
    },
    {
      label: "Amazon SES",
      description: "AWS Simple Email Service. Cheapest at scale ($0.10/1000 emails). Good for high-volume."
    }
  ]
)
```

Store as `EMAIL_PROVIDER`.
</step>

<step name="generate_project_structure">
```
src/Server/{ProjectName}/
  Services/Notifications/
    INotificationService.cs            # Main notification service interface
    NotificationService.cs             # Orchestrates multi-channel delivery
    Channels/
      INotificationChannel.cs          # Channel interface
      InAppChannel.cs                  # In-app notification (DB + SSE)
      EmailChannel.cs                  # Email delivery
      PushChannel.cs                   # Mobile push delivery
      SmsChannel.cs                    # SMS delivery
    Templates/
      ITemplateRenderer.cs             # Template rendering interface
      RazorTemplateRenderer.cs         # Razor-based email templates
      TemplateRegistry.cs              # Template name â†’ file mapping
    Providers/
      IEmailProvider.cs                # Email provider interface
      SendGridProvider.cs              # SendGrid implementation
      SmtpProvider.cs                  # SMTP implementation
      IPushProvider.cs                 # Push provider interface
      FcmProvider.cs                   # Firebase Cloud Messaging
      ApnsProvider.cs                  # Apple Push Notification
      ISmsProvider.cs                  # SMS provider interface
      TwilioProvider.cs                # Twilio SMS
    Models/
      Notification.cs                  # Core notification model
      NotificationPreferences.cs       # User channel preferences
      NotificationTemplate.cs          # Template definition
      DeliveryResult.cs                # Delivery status tracking

  Repositories/
    INotificationRepository.cs         # Notification data access
    NotificationRepository.cs          # Dapper + SP implementation

  Controllers/
    NotificationsController.cs         # REST API for notifications

  Models/Dtos/
    NotificationDtos.cs                # Request/response DTOs

db/sql/
  tables/
    Notifications.sql                  # Notification records
    NotificationPreferences.sql        # User channel preferences
    NotificationDeliveryLog.sql        # Delivery tracking
  procedures/
    usp_Notification_Create.sql
    usp_Notification_List.sql
    usp_Notification_MarkRead.sql
    usp_Notification_MarkAllRead.sql
    usp_Notification_GetUnreadCount.sql
    usp_Notification_Delete.sql
    usp_NotificationPreference_Get.sql
    usp_NotificationPreference_Update.sql
    usp_NotificationDelivery_Log.sql

templates/
  email/
    welcome.html                       # Welcome email
    password-reset.html                # Password reset
    notification.html                  # Generic notification
    _layout.html                       # Base email layout

src/Client/{spa-name}/
  src/components/notifications/
    NotificationBell.tsx               # Bell icon with badge
    NotificationPanel.tsx              # Dropdown notification list
    NotificationItem.tsx               # Single notification row
    NotificationPreferences.tsx        # Preferences settings

tests/
  Notifications/
    NotificationServiceTests.cs
    EmailChannelTests.cs
    InAppChannelTests.cs
    NotificationControllerTests.cs
```
</step>

<step name="generate_database_layer">
Generate notification tables and stored procedures:

**Notifications table:**
```sql
CREATE TABLE dbo.Notifications (
    Id UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId UNIQUEIDENTIFIER NOT NULL,
    UserId UNIQUEIDENTIFIER NOT NULL,
    Type NVARCHAR(100) NOT NULL,       -- 'new_message', 'mention', 'system_alert'
    Title NVARCHAR(500) NOT NULL,
    Body NVARCHAR(MAX) NULL,
    Data NVARCHAR(MAX) NULL,           -- JSON payload for deep linking
    IsRead BIT NOT NULL DEFAULT 0,
    ReadAt DATETIME2(7) NULL,
    Channels NVARCHAR(500) NOT NULL,   -- 'in-app,email,push' (delivered channels)
    CreatedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
    ExpiresAt DATETIME2(7) NULL,
    CONSTRAINT PK_Notifications PRIMARY KEY CLUSTERED (Id),
    CONSTRAINT FK_Notifications_Tenant FOREIGN KEY (TenantId) REFERENCES dbo.Tenants(Id)
);
```

**NotificationPreferences table:**
```sql
CREATE TABLE dbo.NotificationPreferences (
    Id UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId UNIQUEIDENTIFIER NOT NULL,
    UserId UNIQUEIDENTIFIER NOT NULL,
    NotificationType NVARCHAR(100) NOT NULL,
    InApp BIT NOT NULL DEFAULT 1,
    Email BIT NOT NULL DEFAULT 1,
    Push BIT NOT NULL DEFAULT 1,
    Sms BIT NOT NULL DEFAULT 0,
    CONSTRAINT PK_NotificationPreferences PRIMARY KEY CLUSTERED (Id),
    CONSTRAINT UQ_NotificationPref_User_Type UNIQUE (UserId, NotificationType, TenantId)
);
```

All SPs include TenantId isolation.
</step>

<step name="generate_notification_service">
Generate the core notification service:

```csharp
public class NotificationService : INotificationService
{
    public async Task SendAsync(NotificationRequest request)
    {
        // 1. Load user preferences
        var prefs = await _prefRepo.GetPreferences(request.UserId, request.Type, request.TenantId);

        // 2. Create notification record
        var notification = await _notifRepo.Create(request, request.TenantId);

        // 3. Deliver to each enabled channel (parallel)
        var tasks = new List<Task>();
        if (prefs.InApp) tasks.Add(_inAppChannel.DeliverAsync(notification));
        if (prefs.Email) tasks.Add(_emailChannel.DeliverAsync(notification));
        if (prefs.Push) tasks.Add(_pushChannel.DeliverAsync(notification));
        if (prefs.Sms) tasks.Add(_smsChannel.DeliverAsync(notification));
        await Task.WhenAll(tasks);

        // 4. Log delivery results
        await _deliveryRepo.LogDelivery(notification.Id, results, request.TenantId);
    }
}
```
</step>

<step name="generate_frontend_components">
Generate React notification components:

**NotificationBell**: Badge icon showing unread count, SSE-connected for real-time updates
**NotificationPanel**: Dropdown list with mark-read, mark-all-read, delete
**NotificationPreferences**: Settings page for per-type channel toggles

All components implement 5 UI states.
</step>

<step name="generate_email_templates">
Generate HTML email templates:

- Base layout with header, footer, branding
- Welcome email
- Password reset
- Generic notification
- Responsive design (mobile-friendly)
- Dark mode support
- Unsubscribe link
</step>

<step name="commit_and_report">
Commit all generated files:

```bash
git add src/Server/*/Services/Notifications/ src/Server/*/Repositories/Notification* src/Server/*/Controllers/Notifications* db/sql/ templates/ src/Client/
git commit -m "feat: scaffold multi-channel notification system ({channels})"
```

Report with summary of generated components, channels, and next steps.
</step>

</process>

<success_criteria>
- [ ] Notification service with multi-channel orchestration
- [ ] In-app notifications with real-time SSE delivery
- [ ] Email templates with provider integration
- [ ] Push notification support (if mobile app exists)
- [ ] User notification preferences (per-type, per-channel)
- [ ] Database tables and SPs (SPOnly compliant)
- [ ] TenantId isolation on all notification data
- [ ] Frontend notification bell and panel components
- [ ] Delivery tracking and logging
- [ ] Test suite for all channels
</success_criteria>

<failure_handling>
- **No mobile app**: Skip push channel; note in report
- **No email provider config**: Generate with placeholder; warn to configure
- **No SSE infrastructure**: Generate polling fallback for in-app notifications
- **Missing user/tenant tables**: Generate notification tables with generic FK references
</failure_handling>

