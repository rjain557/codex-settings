<purpose>
Generate a cross-platform mobile application for iOS and Android using React Native with Expo. Integrates with your application's API, supports push notifications, biometric auth, and offline-first data sync.

Follows the same API-First architecture as the web app (communicates via API, never holds DB credentials). Shares TypeScript types with the web frontend where possible.
</purpose>

<core_principle>
One codebase, two platforms. React Native with Expo provides native iOS and Android apps from a single TypeScript codebase. Platform-specific code is isolated to hooks and native modules. The app communicates through the API layer only (API-First rule).
</core_principle>

<required_reading>
Read STATE.md and ROADMAP.md before any operation to load project context.
Read any existing OpenAPI spec at docs/spec/openapi.yaml for API integration.
Read existing web frontend patterns at src/Client/technijian-spa/ for consistency.
</required_reading>

<process>

<step name="initialize" priority="first">
Determine project context:

1. Check if `.planning/` exists (GSD project) or standalone generation
2. Check for existing OpenAPI spec at `docs/spec/openapi.yaml`
3. Check for existing web frontend at `src/Client/technijian-spa/` (reuse types, API client patterns)
4. Check for existing auth configuration (Azure AD, JWT)
5. Check for shared types that can be reused

Parse arguments:
- `$ARGUMENTS` may contain target platform: `ios`, `android`, or empty for both
- Parse any flags: `--name <app-name>`, `--api-url <base-url>`, `--bundle-id <com.company.app>`
</step>

<step name="ask_app_type">
Present the app type choice:

```
AskUserQuestion(
  header="App type",
  question="What type of mobile app should be generated?",
  options=[
    {
      label: "Full app (Recommended)",
      description: "Complete mobile app with tab navigation, auth screens, settings, push notifications, and offline support. Best for customer-facing apps."
    },
    {
      label: "Companion app",
      description: "Lightweight companion to your web app. Notifications, quick actions, and status monitoring. Like Slack mobile or GitHub mobile."
    },
    {
      label: "Admin app",
      description: "Internal admin/management app. Dashboard, user management, approval workflows. Optimized for staff use."
    }
  ]
)
```

Store choice as `APP_TYPE`: `full`, `companion`, or `admin`.
</step>

<step name="ask_navigation">
Present navigation pattern choice:

```
AskUserQuestion(
  header="Navigation",
  question="What navigation pattern should the app use?",
  options=[
    {
      label: "Bottom tabs (Recommended)",
      description: "Bottom tab bar with 3-5 main sections. Stack navigation within each tab. Like most modern apps (Instagram, Twitter)."
    },
    {
      label: "Drawer + tabs",
      description: "Hamburger menu drawer for secondary nav, bottom tabs for primary. Good for apps with many sections."
    },
    {
      label: "Stack only",
      description: "Simple stack-based navigation with back button. Good for linear workflows and companion apps."
    }
  ]
)
```

Store as `NAV_PATTERN`.
</step>

<step name="generate_project_structure">
Generate the directory structure:

```
src/mobile/{app-name}/
  app/                                 # Expo Router file-based routing
    (tabs)/                            # Tab layout group
      _layout.tsx                      # Tab navigator configuration
      index.tsx                        # Home tab
      chat.tsx                         # Chat tab (if applicable)
      settings.tsx                     # Settings tab
    (auth)/                            # Auth flow group
      _layout.tsx                      # Auth stack layout
      login.tsx                        # Login screen
      sso-callback.tsx                 # Azure AD SSO callback
    (modals)/                          # Modal screens
      _layout.tsx                      # Modal stack layout
    _layout.tsx                        # Root layout (providers, theme)
    +not-found.tsx                     # 404 screen

  src/
    components/                        # Reusable UI components
      ui/                             # Base UI components
        Button.tsx
        Card.tsx
        Input.tsx
        Avatar.tsx
        Badge.tsx
        Skeleton.tsx                   # Loading skeleton
        ErrorView.tsx                  # Error state component
        EmptyView.tsx                  # Empty state component
      layout/                         # Layout components
        Screen.tsx                    # Safe area screen wrapper
        Header.tsx                    # Custom header
        TabBar.tsx                    # Custom tab bar
      domain/                         # Domain-specific components
        ChatBubble.tsx                # (if chat feature)
        NotificationCard.tsx

    hooks/                             # Custom React hooks
      useAuth.ts                      # Auth state and methods
      useApi.ts                       # API client hook
      usePushNotifications.ts         # Push notification setup
      useBiometrics.ts                # Biometric auth hook
      useOfflineSync.ts               # Offline data sync
      useTheme.ts                     # Theme management

    services/                          # Service layer
      api-client.ts                   # Typed API client (from OpenAPI)
      auth-service.ts                 # Auth flow (Azure AD / JWT)
      storage-service.ts              # Secure storage (Expo SecureStore)
      notification-service.ts         # Push notification handling
      sync-service.ts                 # Offline-first data sync

    stores/                            # State management
      auth-store.ts                   # Auth state (Zustand)
      app-store.ts                    # App-level state
      cache-store.ts                  # Offline cache

    types/                             # TypeScript types
      api.ts                          # API response types (shared with web if possible)
      navigation.ts                   # Navigation param types
      models.ts                       # Domain models

    utils/                             # Utility functions
      format.ts                       # Date, number formatting
      validation.ts                   # Input validation
      platform.ts                     # Platform-specific helpers

    constants/                         # App constants
      theme.ts                        # Colors, spacing, typography
      config.ts                       # App configuration
      api.ts                          # API endpoints

  assets/                              # Static assets
    images/                           # App images
    fonts/                            # Custom fonts (if any)
    adaptive-icon.png                 # Android adaptive icon
    icon.png                          # App icon (1024x1024)
    splash.png                        # Splash screen image
    favicon.png                       # Web favicon (if Expo web)

  config/
    eas.json                          # EAS Build configuration
    app.config.ts                     # Dynamic Expo config

  scripts/
    generate-icons.sh                 # Generate icon sizes from source
    setup-signing.sh                  # iOS/Android code signing setup

  tests/
    components/                       # Component tests
    hooks/                            # Hook tests
    services/                         # Service tests
    e2e/                              # Detox/Maestro E2E tests
      flows/
        auth.test.ts                  # Auth flow E2E
        navigation.test.ts           # Navigation E2E

  app.json                            # Expo configuration
  package.json                        # Dependencies
  tsconfig.json                       # TypeScript config
  babel.config.js                     # Babel config
  metro.config.js                     # Metro bundler config
  .env.example                        # Environment variables template
  README.md                           # App documentation
```
</step>

<step name="generate_app_config">
Generate Expo and EAS configuration:

**app.json / app.config.ts:**
```typescript
export default {
  expo: {
    name: "{App Name}",
    slug: "{app-slug}",
    version: "1.0.0",
    scheme: "{app-scheme}",
    platforms: ["ios", "android"],
    icon: "./assets/icon.png",
    splash: {
      image: "./assets/splash.png",
      resizeMode: "contain",
      backgroundColor: "#ffffff"
    },
    ios: {
      bundleIdentifier: "{bundle-id}",
      supportsTablet: true,
      infoPlist: {
        NSFaceIDUsageDescription: "Use Face ID to unlock the app"
      }
    },
    android: {
      package: "{bundle-id}",
      adaptiveIcon: {
        foregroundImage: "./assets/adaptive-icon.png",
        backgroundColor: "#ffffff"
      }
    },
    plugins: [
      "expo-router",
      "expo-secure-store",
      "expo-local-authentication",
      ["expo-notifications", { icon: "./assets/notification-icon.png" }]
    ]
  }
};
```

**eas.json** (build profiles):
```json
{
  "build": {
    "development": {
      "developmentClient": true,
      "distribution": "internal"
    },
    "preview": {
      "distribution": "internal"
    },
    "production": {
      "autoIncrement": true
    }
  },
  "submit": {
    "production": {
      "ios": { "appleId": "TODO", "ascAppId": "TODO" },
      "android": { "serviceAccountKeyPath": "./google-services.json" }
    }
  }
}
```
</step>

<step name="generate_auth">
Generate authentication flow:

**Azure AD SSO** (if project uses Azure AD):
- Expo AuthSession for OAuth2/OIDC flow
- Token storage in Expo SecureStore (encrypted)
- Automatic token refresh
- Biometric unlock for stored session

**JWT-based** (alternative):
- Login screen with email/password
- JWT token management
- Refresh token rotation
- Secure storage for tokens

**Biometric auth:**
- expo-local-authentication for Face ID / Touch ID / fingerprint
- Biometric gate on app resume (configurable)
- Fallback to PIN/password
</step>

<step name="generate_api_layer">
Generate API integration layer:

**API client:**
- Generated from OpenAPI spec if available
- Typed request/response with shared types
- Automatic auth header injection
- Retry logic with exponential backoff
- Request queuing for offline mode
- Response caching

**Offline-first sync:**
- Local cache with AsyncStorage/MMKV
- Queue mutations when offline
- Sync queue on reconnect
- Conflict resolution strategy (last-write-wins or user-prompt)
- Network status monitoring
</step>

<step name="generate_screens">
Generate screens based on APP_TYPE:

**Full app screens:**
- Home (dashboard/feed)
- Chat/Conversations (if applicable)
- Details screen (entity detail view)
- Create/Edit form screen
- Profile/Account
- Settings (notifications, theme, about)
- Search

**Companion app screens:**
- Dashboard (status overview)
- Notifications list
- Quick action screen
- Settings

**Admin app screens:**
- Dashboard (metrics/charts)
- User management list/detail
- Approval queue
- Activity log
- Settings

All screens implement 5 UI states:
1. **Default** - Normal populated view
2. **Loading** - Skeleton placeholders
3. **Error** - Error message with retry button
4. **Empty** - No-data illustration with CTA
5. **Forbidden** - 403 access denied
</step>

<step name="generate_push_notifications">
Generate push notification support:

- expo-notifications for handling push tokens
- Register push token with backend API on login
- Notification categories (chat, alert, update)
- In-app notification banner
- Deep linking from notification tap to relevant screen
- Badge count management
</step>

<step name="generate_tests">
Generate test suite:

1. **Component tests**: React Native Testing Library for UI components
2. **Hook tests**: Custom hook testing with renderHook
3. **Service tests**: API client, auth, storage (mocked)
4. **Navigation tests**: Screen rendering, deep linking
5. **E2E tests**: Detox or Maestro flow tests (auth, navigation, CRUD)
</step>

<step name="commit_and_report">
Commit all generated files:

```bash
git add src/mobile/{app-name}/
git commit -m "feat: scaffold {app-name} mobile app ({platforms}, {app_type})"
```

Report:
```
## Mobile App Generated: {app-name}

**Type**: {full | companion | admin}
**Navigation**: {bottom-tabs | drawer-tabs | stack}
**Platforms**: {iOS + Android | specific}
**Auth**: {Azure AD SSO | JWT | None}

### Generated Structure
{tree output}

### Next Steps
1. Install dependencies: cd src/mobile/{app-name} && npm install
2. Configure API endpoint in .env (copy .env.example)
3. iOS dev: npx expo run:ios
4. Android dev: npx expo run:android
5. Expo Go preview: npx expo start
6. Run tests: npm test
7. Build for stores: eas build --platform all --profile production
8. Submit: eas submit --platform all
```
</step>

</process>

<success_criteria>
- [ ] Expo/React Native project scaffolded with proper configuration
- [ ] File-based routing (Expo Router) with selected navigation pattern
- [ ] Auth flow generated (Azure AD SSO or JWT + biometric)
- [ ] Typed API client generated from OpenAPI spec
- [ ] Offline-first data sync layer
- [ ] Push notification support
- [ ] All screens implement 5 UI states
- [ ] UI components match Fluent UI patterns where possible
- [ ] EAS Build configuration for dev/preview/production
- [ ] Test suite generated (unit + E2E)
- [ ] README with setup and store submission instructions
</success_criteria>

<failure_handling>
- **No OpenAPI spec found**: Generate API client with placeholder endpoints; warn user to update
- **No Azure AD config**: Default to JWT auth flow; provide Azure AD setup instructions
- **iOS-only or Android-only**: Adjust app.json and skip platform-specific config
- **Expo module not available**: Use bare workflow alternative; document native setup steps
- **Shared types not found**: Generate standalone types with TODO markers to sync with web frontend
</failure_handling>

