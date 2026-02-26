---
name: gsd:gen-extension
description: Generate cross-browser extension (Chrome/Edge/Safari) with Manifest V3
argument-hint: "[chrome|edge|safari] [--name <extension-name>] [--api-url <url>]"
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
Generate a cross-browser extension that runs on Chrome, Edge, and Safari. Uses Manifest V3 with a shared TypeScript codebase and browser-specific build targets.

The user chooses the extension type:
- **Popup**: Toolbar icon with popup panel (like 1Password)
- **Side panel**: Full-height sidebar alongside pages (like Claude sidebar)
- **Content script only**: Injects into pages with no visible UI (like Dark Reader)
- **Full extension**: All components (popup, side panel, content scripts, options)

Default: generates for all three browsers. Pass a browser name to target one.
</objective>

<execution_context>
@C:/Users/rjain/.codex/get-shit-done/workflows/gen-extension.md
</execution_context>

<context>
Target: $ARGUMENTS (optional: chrome, edge, safari, or blank for all)

@.planning/STATE.md
@docs/spec/openapi.yaml
</context>

<process>
Execute the gen-extension workflow from @C:/Users/rjain/.codex/get-shit-done/workflows/gen-extension.md end-to-end.
Ask the extension type and UI framework questions before generating. Generate shared core + browser-specific manifests and build targets.
</process>

