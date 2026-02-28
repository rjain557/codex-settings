---
name: gsd-gen-agent
description: Generate cross-platform remote agent (Mac/Linux/Windows) with optional system tray UI Use when the user asks for 'gsd:gen-agent', 'gsd-gen-agent', or equivalent trigger phrases.
---

# Purpose
Generate a cross-platform remote agent that runs as a background service on Mac, Linux, and Windows. The agent communicates via API only (API-First), supports MCP client integration, health reporting, and auto-update.

The user chooses the UI mode:
- **Headless**: No UI, CLI-managed (best for servers)
- **System tray with menu**: Right-click context menu (like Docker Desktop)
- **System tray with popup**: Tray icon with popup window (like Claude Desktop)

Default: generates for all three platforms. Pass a platform name to target one.

# When to use
Use when the user requests the original gsd:gen-agent flow (for example: $gsd-gen-agent).
Also use on natural-language requests that match this behavior: Generate cross-platform remote agent (Mac/Linux/Windows) with optional system tray UI

# Inputs
The user's text after invoking $gsd-gen-agent is the arguments. Parse it into required fields; if any required field is missing, ask targeted follow-up questions.
Expected argument shape from source: [mac|linux|windows] [--name <agent-name>] [--api-url <url>].
Context from source:
```text
Target: <parsed-arguments> (optional: mac, linux, windows, or blank for all)

@.planning/STATE.md
@docs/spec/openapi.yaml
```

# Workflow
Load and follow these referenced artifacts first:
- @C:/Users/rjain/.claude/get-shit-done/workflows/gen-agent.md
Then execute this process:
```text
Execute the gen-agent workflow from @C:/Users/rjain/.claude/get-shit-done/workflows/gen-agent.md end-to-end.
Ask the UI mode question before generating. Generate shared core + platform-specific wrappers.
```

# Outputs / artifacts
Produce the artifacts specified by the workflow and summarize created/updated files.

# Guardrails (what not to do / how to ask for missing info)
- Do not invent missing project files, phase numbers, or state; inspect the repo first.
- Do not skip validation or checkpoint gates described in referenced workflows.
- If required context is missing, ask focused questions (one small batch) and proceed after answers.

# Source (path to original Claude command file)
- C:\Users\rjain\.claude\commands\gsd\gen-agent.md
