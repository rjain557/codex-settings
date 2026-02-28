---
name: gsd:gen-mobile
description: Generate cross-platform mobile app (iOS/Android) with React Native + Expo
argument-hint: "[ios|android] [--name <app-name>] [--bundle-id <com.company.app>]"
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
Generate a cross-platform mobile application for iOS and Android using React Native with Expo. Supports Azure AD SSO, push notifications, biometric auth, and offline-first data sync.

The user chooses the app type:
- **Full app**: Complete mobile app with tab navigation, auth, push notifications, offline support
- **Companion app**: Lightweight companion to the web app (notifications, quick actions, status)
- **Admin app**: Internal staff app (dashboard, user management, approvals)

Default: generates for both iOS and Android. Pass a platform name to target one.
</objective>

<execution_context>
@C:/Users/rjain/.claude/get-shit-done/workflows/gen-mobile.md
</execution_context>

<context>
Target: $ARGUMENTS (optional: ios, android, or blank for both)

@.planning/STATE.md
@docs/spec/openapi.yaml
</context>

<process>
Execute the gen-mobile workflow from @C:/Users/rjain/.claude/get-shit-done/workflows/gen-mobile.md end-to-end.
Ask the app type and navigation pattern questions before generating. Generate Expo project with file-based routing, typed API client, and platform-specific configuration.
</process>
