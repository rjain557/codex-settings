---
name: gsd-gen-mobile
description: Generate cross-platform mobile app (iOS/Android) with React Native + Expo Use when the user asks for 'gsd:gen-mobile', 'gsd-gen-mobile', or equivalent trigger phrases.
---

# Purpose
Generate a cross-platform mobile application for iOS and Android using React Native with Expo. Supports Azure AD SSO, push notifications, biometric auth, and offline-first data sync.

The user chooses the app type:
- **Full app**: Complete mobile app with tab navigation, auth, push notifications, offline support
- **Companion app**: Lightweight companion to the web app (notifications, quick actions, status)
- **Admin app**: Internal staff app (dashboard, user management, approvals)

Default: generates for both iOS and Android. Pass a platform name to target one.

# When to use
Use when the user requests the original gsd:gen-mobile flow (for example: $gsd-gen-mobile).
Also use on natural-language requests that match this behavior: Generate cross-platform mobile app (iOS/Android) with React Native + Expo

# Inputs
The user's text after invoking $gsd-gen-mobile is the arguments. Parse it into required fields; if any required field is missing, ask targeted follow-up questions.
Expected argument shape from source: [ios|android] [--name <app-name>] [--bundle-id <com.company.app>].
Context from source:
```text
Target: <parsed-arguments> (optional: ios, android, or blank for both)

@.planning/STATE.md
@docs/spec/openapi.yaml
```

# Workflow
Load and follow these referenced artifacts first:
- @C:/Users/rjain/.codex/get-shit-done/workflows/gen-mobile.md
Then execute this process:
```text
Execute the gen-mobile workflow from @C:/Users/rjain/.codex/get-shit-done/workflows/gen-mobile.md end-to-end.
Ask the app type and navigation pattern questions before generating. Generate Expo project with file-based routing, typed API client, and platform-specific configuration.
```

# Outputs / artifacts
Produce the artifacts specified by the workflow and summarize created/updated files.

# Guardrails (what not to do / how to ask for missing info)
- Do not invent missing project files, phase numbers, or state; inspect the repo first.
- Do not skip validation or checkpoint gates described in referenced workflows.
- If required context is missing, ask focused questions (one small batch) and proceed after answers.

# Source (path to original Codex command file)
- C:\Users\rjain\.codex\commands\gsd\gen-mobile.md

