---
name: gsd:gen-agent
description: Generate cross-platform remote agent (Mac/Linux/Windows) with optional system tray UI
argument-hint: "[mac|linux|windows] [--name <agent-name>] [--api-url <url>]"
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
Generate a cross-platform remote agent that runs as a background service on Mac, Linux, and Windows. The agent communicates via API only (API-First), supports MCP client integration, health reporting, and auto-update.

The user chooses the UI mode:
- **Headless**: No UI, CLI-managed (best for servers)
- **System tray with menu**: Right-click context menu (like Docker Desktop)
- **System tray with popup**: Tray icon with popup window (like Claude Desktop)

Default: generates for all three platforms. Pass a platform name to target one.
</objective>

<execution_context>
@C:/Users/rjain/.claude/get-shit-done/workflows/gen-agent.md
</execution_context>

<context>
Target: $ARGUMENTS (optional: mac, linux, windows, or blank for all)

@.planning/STATE.md
@docs/spec/openapi.yaml
</context>

<process>
Execute the gen-agent workflow from @C:/Users/rjain/.claude/get-shit-done/workflows/gen-agent.md end-to-end.
Ask the UI mode question before generating. Generate shared core + platform-specific wrappers.
</process>
